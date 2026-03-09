import Foundation

public enum APIError: Error, Sendable, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(statusCode: Int, message: String?)
    case decodingFailed(Error)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .unauthorized:
            "Unauthorized — check your credentials"
        case .serverError(let code, let message):
            "Server error (\(code))\(message.map { ": \($0)" } ?? "")"
        case .decodingFailed(let error):
            "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        }
    }
}
