import Foundation

public struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ string: String) {
        let cleaned = string.hasPrefix("v") ? String(string.dropFirst()) : string
        // Strip any pre-release suffix (e.g. "0.0.0-dev")
        let versionPart = cleaned.split(separator: "-").first.map(String.init) ?? cleaned
        let parts = versionPart.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    /// Returns true if this version represents a dev build (0.0.0)
    public var isDev: Bool {
        major == 0 && minor == 0 && patch == 0
    }
}
