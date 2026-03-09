import SwiftUI
import AirflowBarCore

struct PopoverContent: View {
    let viewModel: DAGStatusViewModel
    let configStore: ConfigStore
    let updateViewModel: UpdateCheckViewModel
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    @State private var showQuitConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header

            // Environment tab bar (hidden if only 1 environment)
            if configStore.config.enabledEnvironments.count > 1 {
                environmentTabBar
            }

            Divider().opacity(0.3)

            if let error = viewModel.error {
                errorBanner(error)
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
        VStack(spacing: 8) {
            // Counters row
            HStack(spacing: 0) {
                counterCard(
                    count: viewModel.failedCount,
                    label: "Failed",
                    icon: "xmark.circle.fill",
                    color: Color(.systemRed)
                )
                counterCard(
                    count: viewModel.runningCount,
                    label: "Running",
                    icon: "arrow.triangle.2.circlepath",
                    color: Color(.systemBlue)
                )
                counterCard(
                    count: viewModel.successCount,
                    label: "Success",
                    icon: "checkmark.circle.fill",
                    color: Color(.systemGreen)
                )
                counterCard(
                    count: viewModel.queuedCount,
                    label: "Queued",
                    icon: "clock.fill",
                    color: Color(.systemOrange)
                )
            }

            // Status row: health + total + last refresh
            HStack(spacing: 6) {
                if let health = viewModel.currentHealthInfo {
                    Circle()
                        .fill(health.isHealthy ? Color(.systemGreen) : Color(.systemRed))
                        .frame(width: 6, height: 6)
                    Text(health.isHealthy ? "Healthy" : "Unhealthy")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(health.isHealthy ? Color(.systemGreen) : Color(.systemRed))
                }

                Text("·")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: 10))

                Text("\(viewModel.totalCount) DAGs")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                if let lastRefreshed = viewModel.lastRefreshed {
                    Text(lastRefreshed, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    + Text(" ago")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.failedCount) failed, \(viewModel.runningCount) running, \(viewModel.successCount) success, \(viewModel.totalCount) total DAGs")
    }

    private func counterCard(count: Int, label: String, icon: String, color: Color) -> some View {
        let isActive = count > 0
        return VStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? AnyShapeStyle(color) : AnyShapeStyle(.tertiary))
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isActive ? AnyShapeStyle(color.opacity(0.7)) : AnyShapeStyle(.quaternary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityLabel("\(count) \(label)")
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

                if updateViewModel.hasUpdate, let update = updateViewModel.availableUpdate {
                    Button {
                        updateViewModel.openReleasePage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 9))
                            Text(update.tagName)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemBlue).opacity(0.15))
                        .foregroundStyle(Color(.systemBlue))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                    .contextMenu {
                        Button("Dismiss this update") {
                            updateViewModel.dismissCurrentUpdate()
                        }
                    }
                    .help("Update available — click to open release page")
                }

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

                    Divider()
                        .frame(height: 12)
                        .opacity(0.3)
                        .padding(.horizontal, 2)

                    Button {
                        showQuitConfirmation = true
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Quit AirflowBar")
                }
                .foregroundStyle(.secondary)
                .alert("Quit AirflowBar?", isPresented: $showQuitConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Quit", role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    }
                } message: {
                    Text("AirflowBar will stop monitoring your DAGs and close completely.")
                }
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
