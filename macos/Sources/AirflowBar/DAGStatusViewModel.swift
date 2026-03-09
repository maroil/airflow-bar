import Foundation
import AirflowBarCore
import os

@MainActor
@Observable
final class DAGStatusViewModel {
    // State
    var dagStatuses: [DAGStatus] = []
    var healthInfo: [UUID: HealthInfo] = [:]
    var isLoading = false
    var error: String?
    var lastRefreshed: Date?

    // Multi-environment
    var selectedEnvironmentId: UUID?
    var environmentErrors: [UUID: String] = [:]

    // Filtering
    var searchText = ""
    var stateFilter: DAGRunState?
    var showPaused = false

    // Badge callback
    var onBadgeUpdate: ((Int, Int, Bool) -> Void)?

    // Notification tracking
    private var previousStates: [String: DAGRunState] = [:]

    // Exponential backoff
    private var consecutiveErrors = 0
    private static let maxBackoffSeconds: TimeInterval = 1800 // 30 min

    // Regex filter cache
    private var cachedDagFilterPattern: String?
    private var cachedDagFilterRegex: NSRegularExpression?

    private let configStore: ConfigStore
    private var pollingTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.airflowbar", category: "viewmodel")

    var filteredStatuses: [DAGStatus] {
        let statuses: [DAGStatus]
        if let selectedId = selectedEnvironmentId {
            statuses = dagStatuses.filter { $0.environmentId == selectedId }
        } else {
            statuses = dagStatuses
        }

        return statuses.filter { status in
            // Filter paused
            if !showPaused && status.dag.isPaused {
                return false
            }

            // Filter by state
            if let filter = stateFilter {
                guard status.latestRun?.state == filter else { return false }
            }

            // Filter by DAG regex pattern from config
            if let pattern = configStore.config.dagFilter, !pattern.isEmpty {
                let regex = compiledDagFilterRegex(for: pattern)
                if let regex {
                    let range = NSRange(status.dag.dagId.startIndex..., in: status.dag.dagId)
                    if regex.firstMatch(in: status.dag.dagId, range: range) == nil {
                        return false
                    }
                }
            }

            // Filter by search text
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesDagId = status.dag.dagId.lowercased().contains(query)
                let matchesTags = status.dag.tags.contains { $0.name.lowercased().contains(query) }
                let matchesOwners = status.dag.owners.contains { $0.lowercased().contains(query) }
                if !matchesDagId && !matchesTags && !matchesOwners {
                    return false
                }
            }

            return true
        }
    }

    // Badge computed properties
    var failedCount: Int {
        dagStatuses.filter { $0.latestRun?.state == .failed }.count
    }

    var runningCount: Int {
        dagStatuses.filter { $0.latestRun?.state == .running }.count
    }

    var successCount: Int {
        dagStatuses.filter { $0.latestRun?.state == .success }.count
    }

    var queuedCount: Int {
        dagStatuses.filter { $0.latestRun?.state == .queued }.count
    }

    var totalCount: Int {
        dagStatuses.count
    }

    var isDisconnected: Bool {
        error != nil && dagStatuses.isEmpty
    }

    /// Current health for the selected environment (or first healthy one)
    var currentHealthInfo: HealthInfo? {
        if let selectedId = selectedEnvironmentId {
            return healthInfo[selectedId]
        }
        return healthInfo.values.first
    }

    /// Backoff status message
    var backoffMessage: String? {
        guard consecutiveErrors > 0 else { return nil }
        let interval = configStore.config.refreshInterval.rawValue
        let backoff = min(TimeInterval(interval) * pow(2.0, Double(consecutiveErrors)), Self.maxBackoffSeconds)
        let minutes = Int(backoff / 60)
        return minutes > 0 ? "Retrying in \(minutes) min" : nil
    }

    init(configStore: ConfigStore) {
        self.configStore = configStore
        self.showPaused = configStore.config.showPausedDAGs
        loadNotificationState()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                let baseInterval = TimeInterval(self.configStore.config.refreshInterval.rawValue)
                let backoff = self.consecutiveErrors > 0
                    ? min(baseInterval * pow(2.0, Double(self.consecutiveErrors)), Self.maxBackoffSeconds)
                    : baseInterval
                try? await Task.sleep(for: .seconds(backoff))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        let environments = configStore.config.enabledEnvironments
        guard !environments.isEmpty else {
            error = "No environment configured"
            onBadgeUpdate?(failedCount, runningCount, isDisconnected)
            return
        }

        isLoading = true
        defer { isLoading = false }

        var allStatuses: [DAGStatus] = []
        var allHealthInfo: [UUID: HealthInfo] = [:]
        var hasError = false

        // Fetch all environments concurrently
        await withTaskGroup(of: (UUID, [DAGStatus]?, HealthInfo?, String?).self) { group in
            for env in environments {
                group.addTask {
                    let client = AirflowAPIClient(
                        environment: env,
                        maxRunsPerDAG: self.configStore.config.maxRunsPerDAG
                    )

                    // Detect API version if not cached
                    if env.detectedAPIVersion == nil {
                        let detected = await client.detectAPIVersion()
                        await client.setAPIVersion(detected)
                        await MainActor.run {
                            self.configStore.updateDetectedVersion(detected, for: env.id)
                        }
                    }

                    do {
                        async let statusesTask = client.fetchAllDAGStatuses(
                            environmentId: env.id,
                            environmentName: env.name
                        )
                        async let healthTask: HealthInfo? = {
                            try? await client.fetchHealth()
                        }()

                        let statuses = try await statusesTask
                        let health = await healthTask
                        return (env.id, statuses, health, nil)
                    } catch {
                        return (env.id, nil, nil, error.localizedDescription)
                    }
                }
            }

            for await (envId, statuses, health, errorMsg) in group {
                if let statuses {
                    allStatuses.append(contentsOf: statuses)
                }
                if let health {
                    allHealthInfo[envId] = health
                }
                if let errorMsg {
                    environmentErrors[envId] = errorMsg
                    hasError = true
                } else {
                    environmentErrors.removeValue(forKey: envId)
                }
            }
        }

        // Sort aggregated results
        allStatuses.sort { $0.sortPriority < $1.sortPriority }

        // Detect state transitions for notifications
        checkForNotifications(newStatuses: allStatuses)

        dagStatuses = allStatuses
        healthInfo = allHealthInfo
        lastRefreshed = Date()

        if hasError && allStatuses.isEmpty {
            self.error = environmentErrors.values.first
            consecutiveErrors += 1
        } else {
            self.error = nil
            consecutiveErrors = 0
        }

        // Notify badge update
        onBadgeUpdate?(failedCount, runningCount, isDisconnected)
        logger.debug("Refresh complete: \(allStatuses.count) DAGs from \(environments.count) environments")
    }

    // MARK: - Regex Cache

    private func compiledDagFilterRegex(for pattern: String) -> NSRegularExpression? {
        if pattern == cachedDagFilterPattern {
            return cachedDagFilterRegex
        }
        cachedDagFilterPattern = pattern
        cachedDagFilterRegex = try? NSRegularExpression(pattern: pattern)
        return cachedDagFilterRegex
    }

    // MARK: - Notifications

    private func checkForNotifications(newStatuses: [DAGStatus]) {
        let config = configStore.config.notifications
        guard config.onFailure || config.onRecovery else { return }

        for status in newStatuses {
            let key = notificationKey(for: status)
            let newState = status.latestRun?.state
            let oldState = previousStates[key]

            if let newState {
                if config.onFailure && newState == .failed && oldState != .failed && oldState != nil {
                    sendNotification(
                        title: "\(notificationEnvPrefix(status))DAG Failed",
                        body: failureNotificationBody(for: status)
                    )
                }
                if config.onRecovery && newState == .success && oldState == .failed {
                    sendNotification(
                        title: "\(notificationEnvPrefix(status))DAG Recovered",
                        body: recoveryNotificationBody(for: status)
                    )
                }
                previousStates[key] = newState
            }
        }

        saveNotificationState()
    }

    // MARK: - Notification Message Formatting

    private func notificationEnvPrefix(_ status: DAGStatus) -> String {
        guard configStore.config.enabledEnvironments.count > 1,
              let envName = status.environmentName else { return "" }
        return "[\(envName)] "
    }

    private func failureNotificationBody(for status: DAGStatus) -> String {
        var lines: [String] = [status.dag.dagId]

        if let run = status.latestRun {
            if let start = run.startDate {
                lines.append("Started \(relativeTime(from: start))")
            }
            lines.append("Run: \(run.dagRunId)")
        }

        if let owner = status.dag.owners.first {
            lines.append("Owner: \(owner)")
        }

        // Show recent failure streak
        let recentFailures = status.recentRuns.prefix(5).filter { $0.state == .failed }.count
        if recentFailures > 1 {
            lines.append("\(recentFailures) failures in last \(status.recentRuns.prefix(5).count) runs")
        }

        return lines.joined(separator: "\n")
    }

    private func recoveryNotificationBody(for status: DAGStatus) -> String {
        var lines: [String] = [status.dag.dagId]

        if let run = status.latestRun {
            if let start = run.startDate, let end = run.endDate {
                let duration = end.timeIntervalSince(start)
                lines.append("Completed in \(formattedDuration(duration))")
            }
            lines.append("Run: \(run.dagRunId)")
        }

        return lines.joined(separator: "\n")
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }

    private func notificationKey(for status: DAGStatus) -> String {
        if let envId = status.environmentId {
            return "\(envId):\(status.dag.dagId)"
        }
        return status.dag.dagId
    }

    private func sendNotification(title: String, body: String) {
        // UNUserNotificationCenter requires a bundle identifier (present in .app builds).
        // For `swift run` (no bundle ID), fall back to osascript.
        if Bundle.main.bundleIdentifier != nil {
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        } else {
            // Fallback: AppleScript notification (works without bundle ID)
            let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
            let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }

    // MARK: - Notification State Persistence

    private static let notificationStateKey = "com.airflowbar.previousStates"

    private func saveNotificationState() {
        let encoded = previousStates.mapValues(\.rawValue)
        UserDefaults.standard.set(encoded, forKey: Self.notificationStateKey)
    }

    private func loadNotificationState() {
        guard let stored = UserDefaults.standard.dictionary(forKey: Self.notificationStateKey) as? [String: String] else {
            return
        }
        previousStates = stored.compactMapValues { DAGRunState(rawValue: $0) }
    }
}

import UserNotifications
