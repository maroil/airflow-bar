import Foundation

public struct DAG: Codable, Sendable, Identifiable {
    public var id: String { dagId }

    public let dagId: String
    public let isPaused: Bool
    public let tags: [DAGTag]
    public let owners: [String]
    public let description: String?
    public let fileToken: String?
    public let fileloc: String?
    public let scheduleInterval: ScheduleInterval?
    public let timetableDescription: String?

    public init(
        dagId: String,
        isPaused: Bool = false,
        tags: [DAGTag] = [],
        owners: [String] = [],
        description: String? = nil,
        fileToken: String? = nil,
        fileloc: String? = nil,
        scheduleInterval: ScheduleInterval? = nil,
        timetableDescription: String? = nil
    ) {
        self.dagId = dagId
        self.isPaused = isPaused
        self.tags = tags
        self.owners = owners
        self.description = description
        self.fileToken = fileToken
        self.fileloc = fileloc
        self.scheduleInterval = scheduleInterval
        self.timetableDescription = timetableDescription
    }

    // Handle both v1 (schedule_interval) and v2 (timetable_description)
    enum CodingKeys: String, CodingKey {
        case dagId, isPaused, tags, owners, description, fileToken, fileloc
        case scheduleInterval, timetableDescription
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dagId = try container.decode(String.self, forKey: .dagId)
        self.isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        self.tags = try container.decodeIfPresent([DAGTag].self, forKey: .tags) ?? []
        self.owners = try container.decodeIfPresent([String].self, forKey: .owners) ?? []
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.fileToken = try container.decodeIfPresent(String.self, forKey: .fileToken)
        self.fileloc = try container.decodeIfPresent(String.self, forKey: .fileloc)
        self.scheduleInterval = try container.decodeIfPresent(ScheduleInterval.self, forKey: .scheduleInterval)
        self.timetableDescription = try container.decodeIfPresent(String.self, forKey: .timetableDescription)
    }
}

public struct DAGTag: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct ScheduleInterval: Codable, Sendable {
    public let type: String?
    public let value: String?

    public init(type: String? = nil, value: String? = nil) {
        self.type = type
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case type = "__type"
        case value
    }
}
