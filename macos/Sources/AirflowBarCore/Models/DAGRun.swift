import Foundation

public struct DAGRun: Codable, Sendable, Identifiable {
    public var id: String { dagRunId }

    public let dagRunId: String
    public let dagId: String
    public let state: DAGRunState?
    public let logicalDate: Date?
    public let startDate: Date?
    public let endDate: Date?
    public let externalTrigger: Bool?

    public init(
        dagRunId: String,
        dagId: String,
        state: DAGRunState? = nil,
        logicalDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        externalTrigger: Bool? = nil
    ) {
        self.dagRunId = dagRunId
        self.dagId = dagId
        self.state = state
        self.logicalDate = logicalDate
        self.startDate = startDate
        self.endDate = endDate
        self.externalTrigger = externalTrigger
    }

    // Handle both v1 (execution_date) and v2 (logical_date)
    enum CodingKeys: String, CodingKey {
        case dagRunId, dagId, state, logicalDate, executionDate, startDate, endDate, externalTrigger
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dagRunId = try container.decode(String.self, forKey: .dagRunId)
        self.dagId = try container.decode(String.self, forKey: .dagId)
        self.state = try container.decodeIfPresent(DAGRunState.self, forKey: .state)
        // Try logical_date first (v2), fall back to execution_date (v1)
        if let date = try container.decodeIfPresent(Date.self, forKey: .logicalDate) {
            self.logicalDate = date
        } else {
            self.logicalDate = try container.decodeIfPresent(Date.self, forKey: .executionDate)
        }
        self.startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        self.externalTrigger = try container.decodeIfPresent(Bool.self, forKey: .externalTrigger)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dagRunId, forKey: .dagRunId)
        try container.encode(dagId, forKey: .dagId)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(logicalDate, forKey: .logicalDate)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(externalTrigger, forKey: .externalTrigger)
    }
}
