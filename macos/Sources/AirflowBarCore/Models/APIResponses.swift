import Foundation

public struct DAGCollection: Codable, Sendable {
    public let dags: [DAG]
    public let totalEntries: Int

    public init(dags: [DAG], totalEntries: Int) {
        self.dags = dags
        self.totalEntries = totalEntries
    }
}

public struct DAGRunCollection: Codable, Sendable {
    public let dagRuns: [DAGRun]
    public let totalEntries: Int

    public init(dagRuns: [DAGRun], totalEntries: Int) {
        self.dagRuns = dagRuns
        self.totalEntries = totalEntries
    }
}

public struct HealthInfo: Codable, Sendable {
    public let metadatabase: HealthStatus
    public let scheduler: SchedulerHealth

    public init(metadatabase: HealthStatus, scheduler: SchedulerHealth) {
        self.metadatabase = metadatabase
        self.scheduler = scheduler
    }

    public var isHealthy: Bool {
        metadatabase.status == "healthy" && scheduler.status == "healthy"
    }
}

public struct HealthStatus: Codable, Sendable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}

public struct SchedulerHealth: Codable, Sendable {
    public let status: String
    public let latestSchedulerHeartbeat: Date?

    public init(status: String, latestSchedulerHeartbeat: Date? = nil) {
        self.status = status
        self.latestSchedulerHeartbeat = latestSchedulerHeartbeat
    }
}
