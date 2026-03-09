import AppKit
import AirflowBarCore

@MainActor
@Observable
final class UpdateCheckViewModel {
    var availableUpdate: AppRelease?
    var isChecking = false

    var hasUpdate: Bool {
        availableUpdate != nil
    }

    private let updateChecker: UpdateChecker
    private let configStore: ConfigStore

    private static let lastCheckDateKey = "UpdateChecker.lastCheckDate"
    private static let dismissedVersionKey = "UpdateChecker.dismissedVersion"
    private static let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    init(configStore: ConfigStore, updateChecker: UpdateChecker = UpdateChecker()) {
        self.configStore = configStore
        self.updateChecker = updateChecker
    }

    /// Check for updates if enough time has passed and auto-check is enabled.
    func checkIfNeeded() {
        guard configStore.config.checkForUpdates else { return }

        let currentVersion = Self.appVersion
        guard !currentVersion.isDev else { return }

        if let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckDateKey) as? Date,
           Date().timeIntervalSince(lastCheck) < Self.checkInterval {
            return
        }

        Task {
            await performCheck(currentVersion: currentVersion)
        }
    }

    /// Manual check triggered by user — ignores cooldown.
    func checkNow() {
        let currentVersion = Self.appVersion
        guard !currentVersion.isDev else { return }

        Task {
            await performCheck(currentVersion: currentVersion)
        }
    }

    func openReleasePage() {
        guard let update = availableUpdate, let url = update.releaseURL else { return }
        NSWorkspace.shared.open(url)
    }

    func dismissCurrentUpdate() {
        guard let update = availableUpdate else { return }
        UserDefaults.standard.set(update.tagName, forKey: Self.dismissedVersionKey)
        availableUpdate = nil
    }

    // MARK: - Private

    private func performCheck(currentVersion: SemanticVersion) async {
        isChecking = true
        defer { isChecking = false }

        let release = await updateChecker.checkForUpdate(currentVersion: currentVersion)
        UserDefaults.standard.set(Date(), forKey: Self.lastCheckDateKey)

        if let release {
            let dismissedVersion = UserDefaults.standard.string(forKey: Self.dismissedVersionKey)
            if dismissedVersion != release.tagName {
                availableUpdate = release
            }
        }
    }

    static var appVersion: SemanticVersion {
        let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return SemanticVersion(versionString) ?? SemanticVersion(major: 0, minor: 0, patch: 0)
    }
}
