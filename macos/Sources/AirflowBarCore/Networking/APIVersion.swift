import Foundation

public enum APIVersion: String, Codable, Sendable {
    case v1
    case v2

    public var pathPrefix: String {
        switch self {
        case .v1: "/api/v1"
        case .v2: "/api/v2"
        }
    }
}
