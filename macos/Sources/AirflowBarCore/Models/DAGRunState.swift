import Foundation

public enum DAGRunState: String, Codable, Sendable, CaseIterable {
    case success
    case failed
    case running
    case queued

    public var displayName: String {
        switch self {
        case .success: "Success"
        case .failed: "Failed"
        case .running: "Running"
        case .queued: "Queued"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .running: "arrow.triangle.2.circlepath"
        case .queued: "clock.fill"
        }
    }

    public var colorName: String {
        switch self {
        case .success: "green"
        case .failed: "red"
        case .running: "blue"
        case .queued: "orange"
        }
    }

    /// Sort priority: failed first, then running, queued, success
    public var sortPriority: Int {
        switch self {
        case .failed: 0
        case .running: 1
        case .queued: 2
        case .success: 3
        }
    }
}
