import Foundation

public enum AuthCredential: Codable, Sendable {
    case basicAuth(username: String, password: String)
    case bearerToken(String)

    public var headerValue: String {
        switch self {
        case .basicAuth(let username, let password):
            let data = "\(username):\(password)".data(using: .utf8)!
            return "Basic \(data.base64EncodedString())"
        case .bearerToken(let token):
            return "Bearer \(token)"
        }
    }

    // Custom coding for JSON representation
    enum CodingKeys: String, CodingKey {
        case type, username, password, token
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "basicAuth":
            let username = try container.decode(String.self, forKey: .username)
            let password = try container.decode(String.self, forKey: .password)
            self = .basicAuth(username: username, password: password)
        case "bearerToken":
            let token = try container.decode(String.self, forKey: .token)
            self = .bearerToken(token)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown credential type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .basicAuth(let username, let password):
            try container.encode("basicAuth", forKey: .type)
            try container.encode(username, forKey: .username)
            try container.encode(password, forKey: .password)
        case .bearerToken(let token):
            try container.encode("bearerToken", forKey: .type)
            try container.encode(token, forKey: .token)
        }
    }
}
