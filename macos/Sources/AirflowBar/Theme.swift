import SwiftUI
import AirflowBarCore

enum DAGColor {
    static func forState(_ state: DAGRunState?) -> Color {
        switch state {
        case .success: Color(.systemGreen)
        case .failed: Color(.systemRed)
        case .running: Color(.systemBlue)
        case .queued: Color(.systemOrange)
        case nil: Color(.systemGray)
        }
    }

    static func zeroCount() -> Color {
        Color(.tertiaryLabelColor)
    }
}
