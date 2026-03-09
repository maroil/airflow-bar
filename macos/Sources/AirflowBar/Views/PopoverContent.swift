import SwiftUI
import AirflowBarCore

struct PopoverContent: View {
    let viewModel: DAGStatusViewModel
    let configStore: ConfigStore
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            // Environment tab bar (hidden if only 1 environment)
            if configStore.config.enabledEnvironments.count > 1 {
                environmentTabBar
                Divider().opacity(0.5)
            }

            if let error = viewModel.error {
                errorBanner(error)
            }

            if !viewModel.dagStatuses.isEmpty {
                summaryStrip
            }

            FilterBar(
                searchText: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ),
                stateFilter: Binding(
                    get: { viewModel.stateFilter },
                    set: { viewModel.stateFilter = $0 }
                ),
                failedCount: viewModel.failedCount,
                runningCount: viewModel.runningCount,
                successCount: viewModel.successCount
            )

            DAGListView(
                statuses: viewModel.filteredStatuses,
                baseURL: selectedBaseURL,
                isLoading: viewModel.isLoading && viewModel.dagStatuses.isEmpty,
                showEnvironmentLabels: viewModel.selectedEnvironmentId == nil && configStore.config.enabledEnvironments.count > 1
            )

            Divider().opacity(0.5)
            footer
        }
        .frame(width: 380, height: 500)
    }

    private var selectedBaseURL: String? {
        if let selectedId = viewModel.selectedEnvironmentId {
            return configStore.config.environments.first(where: { $0.id == selectedId })?.baseURL
        }
        return configStore.config.activeEnvironment?.baseURL
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.linearGradient(
                        colors: [.blue.opacity(0.7), .cyan.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 30, height: 30)
                Image(systemName: "wind")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("AirflowBar")
                    .font(.system(size: 13, weight: .semibold))
                if let lastRefreshed = viewModel.lastRefreshed {
                    Text(lastRefreshed, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    + Text(" ago")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let health = viewModel.currentHealthInfo {
                healthBadge(health)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Environment Tab Bar

    private var environmentTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // "All" tab
                environmentTab(name: "All", id: nil, health: nil)

                ForEach(configStore.config.enabledEnvironments) { env in
                    environmentTab(
                        name: env.name,
                        id: env.id,
                        health: viewModel.healthInfo[env.id]
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private func environmentTab(name: String, id: UUID?, health: HealthInfo?) -> some View {
        let isSelected = viewModel.selectedEnvironmentId == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedEnvironmentId = id
            }
        } label: {
            HStack(spacing: 4) {
                if let health {
                    Circle()
                        .fill(health.isHealthy ? Color(.systemGreen) : Color(.systemRed))
                        .frame(width: 6, height: 6)
                }
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(name) environment")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func healthBadge(_ health: HealthInfo) -> some View {
        HStack(spacing: 5) {
            Image(systemName: health.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10))
            Text(health.isHealthy ? "Healthy" : "Unhealthy")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(health.isHealthy ? Color(.systemGreen) : Color(.systemRed))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((health.isHealthy ? Color(.systemGreen) : Color(.systemRed)).opacity(0.1))
        .clipShape(Capsule())
        .accessibilityLabel(health.isHealthy ? "Airflow is healthy" : "Airflow is unhealthy")
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            summaryPill(count: viewModel.failedCount, label: "Failed", color: Color(.systemRed), icon: "xmark.circle.fill")
            summaryPill(count: viewModel.runningCount, label: "Running", color: Color(.systemBlue), icon: "arrow.triangle.2.circlepath")
            summaryPill(count: viewModel.successCount, label: "Success", color: Color(.systemGreen), icon: "checkmark.circle.fill")
            Spacer()
            Text("\(viewModel.totalCount) DAGs")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.failedCount) failed, \(viewModel.runningCount) running, \(viewModel.successCount) success, \(viewModel.totalCount) total DAGs")
    }

    private func summaryPill(count: Int, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(count > 0 ? color : DAGColor.zeroCount())
        .accessibilityLabel("\(count) \(label)")
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                if let backoff = viewModel.backoffMessage {
                    Text(backoff)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                onRefresh()
            } label: {
                Text("Retry")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.05))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if selectedBaseURL != nil {
                quickLinksBar
                Divider().opacity(0.5)
            }

            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text("Refreshing...")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else if let lastRefreshed = viewModel.lastRefreshed {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(lastRefreshed, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    + Text(" ago")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 2) {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Refresh")

                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Settings")
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var quickLinksBar: some View {
        HStack(spacing: 4) {
            Button {
                if let base = selectedBaseURL, let url = AirflowWebURL.home(baseURL: base) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "globe")
                        .font(.system(size: 9))
                    Text("Open Airflow")
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 7, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.borderless)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }
}
