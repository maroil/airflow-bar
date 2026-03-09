import Foundation

public enum Endpoint: Sendable {
    case dags(limit: Int = 100, offset: Int = 0)
    case dagRuns(dagId: String, limit: Int = 5, orderBy: String? = nil)
    case health
    case version

    public func url(baseURL: String, version: APIVersion = .v1) -> URL? {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let prefix = version.pathPrefix

        switch self {
        case .dags(let limit, let offset):
            var components = URLComponents(string: "\(base)\(prefix)/dags")
            components?.queryItems = [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
            ]
            return components?.url

        case .dagRuns(let dagId, let limit, let orderBy):
            let encoded = dagId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? dagId
            var components = URLComponents(string: "\(base)\(prefix)/dags/\(encoded)/dagRuns")
            let effectiveOrderBy = orderBy ?? (version == .v2 ? "-logical_date" : "-execution_date")
            components?.queryItems = [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "order_by", value: effectiveOrderBy),
            ]
            return components?.url

        case .health:
            return URL(string: "\(base)\(prefix)/health")

        case .version:
            return URL(string: "\(base)\(prefix)/version")
        }
    }
}
