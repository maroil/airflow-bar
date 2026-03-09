import SwiftUI
import AirflowBarCore

struct DAGRowView: View {
    let status: DAGStatus
    let baseURL: String?
    var environmentName: String? = nil
    @State private var isHovered = false
    @State private var isLinkHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            statusIndicator

            // DAG info
            VStack(alignment: .leading, spacing: 3) {
                Text(status.dag.dagId)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    if status.dag.isPaused {
                        statusLabel("Paused", color: DAGColor.forState(nil))
                    } else if let run = status.latestRun {
                        statusLabel(
                            run.state?.displayName ?? "Unknown",
                            color: DAGColor.forState(run.state)
                        )
                        if let startDate = run.startDate {
                            Text(startDate, style: .relative)
                                .font(.system(size: 9))
                                .foregroundStyle(.quaternary)
                        }
                    } else {
                        statusLabel("No runs", color: DAGColor.forState(nil))
                    }

                    // Environment pill
                    if let envName = environmentName {
                        Text(envName)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 4)

            // Run history sparkline
            if !status.recentRuns.isEmpty {
                runSparkline
            }

            // Open in browser link (visible on hover)
            if dagURL != nil {
                Button(action: openDAGInBrowser) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(isLinkHovered ? .primary : .tertiary)
                }
                .buttonStyle(.borderless)
                .help("Open in Airflow")
                .opacity(isHovered ? 1 : 0)
                .onHover { hovering in
                    isLinkHovered = hovering
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var dagURL: URL? {
        guard let base = baseURL else { return nil }
        return AirflowWebURL.dagGrid(baseURL: base, dagId: status.dag.dagId)
    }

    private func openDAGInBrowser() {
        guard let url = dagURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(indicatorColor.opacity(0.15))
                .frame(width: 22, height: 22)
            Image(systemName: indicatorIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(indicatorColor)
        }
    }

    private var indicatorColor: Color {
        if status.dag.isPaused { return DAGColor.forState(nil) }
        return DAGColor.forState(status.latestRun?.state)
    }

    private var indicatorIcon: String {
        if status.dag.isPaused { return "pause" }
        switch status.latestRun?.state {
        case .success: return "checkmark"
        case .failed: return "xmark"
        case .running: return "arrow.trianglehead.2.counterclockwise"
        case .queued: return "clock"
        case nil: return "minus"
        }
    }

    // MARK: - Status Label

    private func statusLabel(_ text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.8))
        }
    }

    // MARK: - Run Sparkline

    private var runSparkline: some View {
        HStack(spacing: 2) {
            ForEach(status.recentRuns.prefix(5).reversed()) { run in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DAGColor.forState(run.state))
                    .frame(width: 5, height: heightForState(run.state))
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .stroke(DAGColor.forState(run.state).opacity(0.3), lineWidth: 0.5)
                    )
                    .help(sparklineTooltip(for: run))
            }
        }
        .frame(height: 16, alignment: .bottom)
        .accessibilityLabel(sparklineAccessibility)
        .accessibilityHint("Recent DAG run history")
    }

    private func heightForState(_ state: DAGRunState?) -> CGFloat {
        switch state {
        case .success: 12
        case .failed: 16
        case .running: 10
        case .queued: 6
        case nil: 4
        }
    }

    private func sparklineTooltip(for run: DAGRun) -> String {
        let state = run.state?.displayName ?? "Unknown"
        if let date = run.startDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "\(state) — \(formatter.string(from: date))"
        }
        return state
    }

    // MARK: - Helpers

    private var accessibilityText: String {
        let state = status.dag.isPaused ? "Paused" : (status.latestRun?.state?.displayName ?? "No runs")
        var text = "\(status.dag.dagId), \(state)"
        if let envName = environmentName {
            text += ", \(envName)"
        }
        return text
    }

    private var sparklineAccessibility: String {
        let states = status.recentRuns.prefix(5).compactMap { $0.state?.displayName }
        return "Recent runs: \(states.joined(separator: ", "))"
    }
}
