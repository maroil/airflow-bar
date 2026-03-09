import Foundation

public struct AirflowEnvironment: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var baseURL: String
    public var credential: AuthCredential
    public var isEnabled: Bool
    public var detectedAPIVersion: APIVersion?

    public init(
        id: UUID = UUID(),
        name: String = "Default",
        baseURL: String = "",
        credential: AuthCredential = .basicAuth(username: "", password: ""),
        isEnabled: Bool = true,
        detectedAPIVersion: APIVersion? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.credential = credential
        self.isEnabled = isEnabled
        self.detectedAPIVersion = detectedAPIVersion
    }

    // Custom CodingKeys: exclude credential from JSON (stored in Keychain)
    enum CodingKeys: String, CodingKey {
        case id, name, baseURL, isEnabled, detectedAPIVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.baseURL = try container.decode(String.self, forKey: .baseURL)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.detectedAPIVersion = try container.decodeIfPresent(APIVersion.self, forKey: .detectedAPIVersion)
        // Credential gets a placeholder; ConfigStore hydrates from Keychain
        self.credential = .basicAuth(username: "", password: "")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(detectedAPIVersion, forKey: .detectedAPIVersion)
        // credential intentionally omitted — stored in Keychain
    }
}
