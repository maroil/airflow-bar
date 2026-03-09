import Foundation
import os

public actor AirflowAPIClient {
    private let baseURL: String
    private let credential: AuthCredential
    private let maxRunsPerDAG: Int
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private var apiVersion: APIVersion
    private let logger = Logger(subsystem: "com.airflowbar", category: "api")

    public init(
        environment: AirflowEnvironment,
        maxRunsPerDAG: Int = 5,
        httpClient: HTTPClient? = nil
    ) {
        self.baseURL = environment.baseURL
        self.credential = environment.credential
        self.maxRunsPerDAG = maxRunsPerDAG
        self.apiVersion = environment.detectedAPIVersion ?? .v1

        if let httpClient {
            self.httpClient = httpClient
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.httpClient = URLSession(configuration: config)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        self.decoder = decoder
    }

    // MARK: - Public API

    public func detectAPIVersion() async -> APIVersion {
        // Try v2 first
        do {
            guard let url = Endpoint.version.url(baseURL: baseURL, version: .v2) else {
                return .v1
            }
            var req = URLRequest(url: url)
            req.setValue(credential.headerValue, forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (_, response) = try await httpClient.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                logger.debug("Detected API v2")
                return .v2
            }
        } catch {
            logger.debug("v2 probe failed: \(error.localizedDescription)")
        }
        logger.debug("Falling back to API v1")
        return .v1
    }

    public func setAPIVersion(_ version: APIVersion) {
        self.apiVersion = version
    }

    public func getAPIVersion() -> APIVersion {
        apiVersion
    }

    public func fetchDAGs() async throws -> DAGCollection {
        try await request(endpoint: .dags())
    }

    /// Fetch all DAGs with pagination support (cap at 1000)
    public func fetchAllDAGs() async throws -> DAGCollection {
        let limit = 100
        let maxTotal = 1000
        var allDAGs: [DAG] = []
        var offset = 0

        let first: DAGCollection = try await request(endpoint: .dags(limit: limit, offset: 0))
        allDAGs.append(contentsOf: first.dags)
        let total = min(first.totalEntries, maxTotal)

        offset = first.dags.count
        while offset < total {
            let page: DAGCollection = try await request(endpoint: .dags(limit: limit, offset: offset))
            allDAGs.append(contentsOf: page.dags)
            if page.dags.isEmpty { break }
            offset += page.dags.count
        }

        return DAGCollection(dags: allDAGs, totalEntries: total)
    }

    public func fetchDAGRuns(dagId: String) async throws -> DAGRunCollection {
        try await request(endpoint: .dagRuns(dagId: dagId, limit: maxRunsPerDAG))
    }

    public func fetchHealth() async throws -> HealthInfo {
        try await request(endpoint: .health)
    }

    /// Fetch all DAGs with their recent runs, using concurrent fetching (max 5 at a time)
    public func fetchAllDAGStatuses(environmentId: UUID? = nil, environmentName: String? = nil) async throws -> [DAGStatus] {
        let dagCollection = try await fetchAllDAGs()

        let statuses = try await withThrowingTaskGroup(of: DAGStatus.self) { group in
            var results: [DAGStatus] = []
            var iterator = dagCollection.dags.makeIterator()
            var active = 0
            let maxConcurrent = 5

            while active < maxConcurrent, let dag = iterator.next() {
                group.addTask {
                    try await self.fetchDAGStatus(for: dag, environmentId: environmentId, environmentName: environmentName)
                }
                active += 1
            }

            for try await status in group {
                results.append(status)
                if let dag = iterator.next() {
                    group.addTask {
                        try await self.fetchDAGStatus(for: dag, environmentId: environmentId, environmentName: environmentName)
                    }
                }
            }

            return results
        }

        return statuses.sorted { $0.sortPriority < $1.sortPriority }
    }

    // MARK: - Private

    private func fetchDAGStatus(for dag: DAG, environmentId: UUID?, environmentName: String?) async throws -> DAGStatus {
        let runCollection = try await fetchDAGRuns(dagId: dag.dagId)
        return DAGStatus(
            dag: dag,
            latestRun: runCollection.dagRuns.first,
            recentRuns: runCollection.dagRuns,
            environmentId: environmentId,
            environmentName: environmentName
        )
    }

    private func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        guard let url = endpoint.url(baseURL: baseURL, version: apiVersion) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(credential.headerValue, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        logger.debug("Request: \(url.absoluteString)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(
                NSError(domain: "AirflowBar", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            )
        }

        logger.debug("Response: \(httpResponse.statusCode) for \(url.absoluteString)")

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}
