import Testing
import Foundation
@testable import AirflowBarCore

struct MockHTTPClient: HTTPClient, Sendable {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

private func makeResponse(statusCode: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://api.github.com")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

private func makeReleaseJSON(tagName: String, prerelease: Bool = false) -> Data {
    """
    {
        "tag_name": "\(tagName)",
        "html_url": "https://github.com/maroil/airflow-bar/releases/tag/\(tagName)",
        "name": "Release \(tagName)",
        "body": "Release notes",
        "prerelease": \(prerelease)
    }
    """.data(using: .utf8)!
}

@Suite("UpdateChecker Tests")
struct UpdateCheckerTests {
    @Test("Returns release when newer version is available")
    func newerVersion() async {
        let mock = MockHTTPClient { _ in
            (makeReleaseJSON(tagName: "v2.0.0"), makeResponse())
        }
        let checker = UpdateChecker(httpClient: mock)
        let result = await checker.checkForUpdate(currentVersion: SemanticVersion("1.0.0")!)
        #expect(result != nil)
        #expect(result?.tagName == "v2.0.0")
    }

    @Test("Returns nil when same version")
    func sameVersion() async {
        let mock = MockHTTPClient { _ in
            (makeReleaseJSON(tagName: "v1.0.0"), makeResponse())
        }
        let checker = UpdateChecker(httpClient: mock)
        let result = await checker.checkForUpdate(currentVersion: SemanticVersion("1.0.0")!)
        #expect(result == nil)
    }

    @Test("Returns nil when current version is newer")
    func olderVersion() async {
        let mock = MockHTTPClient { _ in
            (makeReleaseJSON(tagName: "v1.0.0"), makeResponse())
        }
        let checker = UpdateChecker(httpClient: mock)
        let result = await checker.checkForUpdate(currentVersion: SemanticVersion("2.0.0")!)
        #expect(result == nil)
    }

    @Test("Returns nil on network error")
    func networkError() async {
        let mock = MockHTTPClient { _ in
            throw URLError(.notConnectedToInternet)
        }
        let checker = UpdateChecker(httpClient: mock)
        let result = await checker.checkForUpdate(currentVersion: SemanticVersion("1.0.0")!)
        #expect(result == nil)
    }

    @Test("Returns nil for prerelease")
    func prereleaseSkipped() async {
        let mock = MockHTTPClient { _ in
            (makeReleaseJSON(tagName: "v2.0.0", prerelease: true), makeResponse())
        }
        let checker = UpdateChecker(httpClient: mock)
        let result = await checker.checkForUpdate(currentVersion: SemanticVersion("1.0.0")!)
        #expect(result == nil)
    }

    @Test("Returns nil on rate limit (403)")
    func rateLimited() async {
        let mock = MockHTTPClient { _ in
            (Data(), makeResponse(statusCode: 403))
        }
        let checker = UpdateChecker(httpClient: mock)
        let result = await checker.checkForUpdate(currentVersion: SemanticVersion("1.0.0")!)
        #expect(result == nil)
    }

    @Test("Returns nil on rate limit (429)")
    func rateLimited429() async {
        let mock = MockHTTPClient { _ in
            (Data(), makeResponse(statusCode: 429))
        }
        let checker = UpdateChecker(httpClient: mock)
        let result = await checker.checkForUpdate(currentVersion: SemanticVersion("1.0.0")!)
        #expect(result == nil)
    }
}
