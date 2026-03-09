import Foundation
import os

public actor UpdateChecker {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.airflowbar", category: "update-checker")

    public static let releaseURL = "https://api.github.com/repos/maroil/airflow-bar/releases/latest"

    public init(httpClient: HTTPClient? = nil) {
        if let httpClient {
            self.httpClient = httpClient
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.httpClient = URLSession(configuration: config)
        }

        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    /// Checks GitHub for a newer release. Returns the release if an update is available, nil otherwise.
    public func checkForUpdate(currentVersion: SemanticVersion) async -> AppRelease? {
        guard let url = URL(string: Self.releaseURL) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AirflowBar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await httpClient.data(for: request)

            if let http = response as? HTTPURLResponse {
                guard (200..<300).contains(http.statusCode) else {
                    if http.statusCode == 403 || http.statusCode == 429 {
                        logger.info("Rate limited by GitHub API (\(http.statusCode))")
                    } else {
                        logger.warning("GitHub API returned \(http.statusCode)")
                    }
                    return nil
                }
            }

            let release = try decoder.decode(AppRelease.self, from: data)

            // Skip pre-releases
            guard !release.prerelease else {
                logger.debug("Latest release is a prerelease, skipping")
                return nil
            }

            guard let latestVersion = release.version else {
                logger.warning("Could not parse version from tag: \(release.tagName)")
                return nil
            }

            if latestVersion > currentVersion {
                logger.info("Update available: \(currentVersion) → \(latestVersion)")
                return release
            } else {
                logger.debug("Up to date (\(currentVersion))")
                return nil
            }
        } catch {
            logger.warning("Update check failed: \(error.localizedDescription)")
            return nil
        }
    }
}
