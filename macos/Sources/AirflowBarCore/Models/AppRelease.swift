import Foundation

public struct AppRelease: Decodable, Sendable {
    public let tagName: String
    public let htmlUrl: String
    public let name: String?
    public let body: String?
    public let prerelease: Bool

    public var version: SemanticVersion? {
        SemanticVersion(tagName)
    }

    public var releaseURL: URL? {
        URL(string: htmlUrl)
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case name
        case body
        case prerelease
    }
}
