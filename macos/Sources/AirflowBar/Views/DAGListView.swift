import SwiftUI
import AirflowBarCore

struct DAGListView: View {
    let statuses: [DAGStatus]
    let baseURL: String?
    var isLoading: Bool = false
    var showEnvironmentLabels: Bool = false

    var body: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading DAGs...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if statuses.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(.quaternary)
                Text("No DAGs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Nothing matches your current filters")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(statuses.enumerated()), id: \.element.id) { index, status in
                        DAGRowView(
                            status: status,
                            baseURL: baseURL,
                            environmentName: showEnvironmentLabels ? status.environmentName : nil
                        )
                        if index < statuses.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
