import Foundation

public struct DAGStatus: Sendable, Identifiable {
    public var id: String {
        if let environmentId {
            return "\(environmentId):\(dag.dagId)"
        }
        return dag.dagId
    }

    public let dag: DAG
    public let latestRun: DAGRun?
    public let recentRuns: [DAGRun]
    public let environmentId: UUID?
    public let environmentName: String?

    public init(
        dag: DAG,
        latestRun: DAGRun? = nil,
        recentRuns: [DAGRun] = [],
        environmentId: UUID? = nil,
        environmentName: String? = nil
    ) {
        self.dag = dag
        self.latestRun = latestRun
        self.recentRuns = recentRuns
        self.environmentId = environmentId
        self.environmentName = environmentName
    }

    /// Effective state for sorting/display: paused DAGs get nil state
    public var effectiveState: DAGRunState? {
        if dag.isPaused { return nil }
        return latestRun?.state
    }

    /// Sort priority: failed → running → queued → success → paused/unknown
    public var sortPriority: Int {
        effectiveState?.sortPriority ?? 4
    }
}
