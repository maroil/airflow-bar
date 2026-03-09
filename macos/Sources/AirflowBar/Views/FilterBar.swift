import SwiftUI
import AirflowBarCore

struct FilterBar: View {
    @Binding var searchText: String
    @Binding var stateFilter: DAGRunState?
    var failedCount: Int = 0
    var runningCount: Int = 0
    var successCount: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                TextField("Filter DAGs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .accessibilityLabel("Search DAGs")
                if !searchText.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            // Chips
            HStack(spacing: 5) {
                filterChip(label: "All", state: nil, count: nil)
                filterChip(label: "Failed", state: .failed, count: failedCount)
                filterChip(label: "Running", state: .running, count: runningCount)
                filterChip(label: "Success", state: .success, count: successCount)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func filterChip(label: String, state: DAGRunState?, count: Int?) -> some View {
        let isSelected = stateFilter == state
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                stateFilter = state
            }
        } label: {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : chipColor(for: state).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isSelected ? chipColor(for: state) : Color.primary.opacity(0.04))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(label) filter")
        .accessibilityHint("Filter DAGs by \(label.lowercased()) state")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chipColor(for state: DAGRunState?) -> Color {
        switch state {
        case .failed: Color(.systemRed)
        case .running: Color(.systemBlue)
        case .success: Color(.systemGreen)
        case .queued: Color(.systemOrange)
        case nil: .accentColor
        }
    }
}
