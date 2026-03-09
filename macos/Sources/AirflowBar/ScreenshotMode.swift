import Foundation
import AirflowBarCore

/// Provides realistic mock data for screenshot / demo purposes.
/// Launch with `--screenshot` flag to activate.
enum ScreenshotMode {
    static var isEnabled: Bool {
        CommandLine.arguments.contains("--screenshot")
    }

    private static let prodEnvId = UUID()
    private static let stagingEnvId = UUID()

    @MainActor static func configure(viewModel: DAGStatusViewModel, configStore: ConfigStore) {
        // Set up two environments
        let prodEnv = AirflowEnvironment(
            id: prodEnvId,
            name: "Production",
            baseURL: "https://airflow.example.com",
            credential: .basicAuth(username: "admin", password: ""),
            isEnabled: true
        )
        let stagingEnv = AirflowEnvironment(
            id: stagingEnvId,
            name: "Staging",
            baseURL: "https://airflow-staging.example.com",
            credential: .basicAuth(username: "admin", password: ""),
            isEnabled: true
        )
        configStore.config = AppConfig(
            environments: [prodEnv, stagingEnv],
            refreshInterval: .oneMinute,
            showPausedDAGs: false,
            maxRunsPerDAG: 5,
            notifications: NotificationSettings()
        )

        // Populate view model
        viewModel.dagStatuses = buildMockStatuses()
        viewModel.healthInfo = [
            prodEnvId: HealthInfo(
                metadatabase: HealthStatus(status: "healthy"),
                scheduler: SchedulerHealth(status: "healthy", latestSchedulerHeartbeat: Date())
            ),
            stagingEnvId: HealthInfo(
                metadatabase: HealthStatus(status: "healthy"),
                scheduler: SchedulerHealth(status: "healthy", latestSchedulerHeartbeat: Date())
            ),
        ]
        viewModel.lastRefreshed = Date()
        viewModel.selectedEnvironmentId = nil
    }

    // MARK: - Mock DAG Statuses

    private static func buildMockStatuses() -> [DAGStatus] {
        var statuses: [DAGStatus] = []

        // ── Production DAGs ──

        // Failed DAGs
        statuses.append(dagStatus(
            id: "etl_customer_payments",
            tags: ["etl", "payments", "critical"],
            owners: ["data-eng"],
            state: .failed,
            runHistory: [.success, .success, .failed, .success, .failed],
            startedAgo: 180,
            env: "Production", envId: prodEnvId
        ))
        statuses.append(dagStatus(
            id: "ml_fraud_detection_pipeline",
            tags: ["ml", "fraud", "production"],
            owners: ["ml-team"],
            state: .failed,
            runHistory: [.success, .failed, .failed, .success, .success],
            startedAgo: 420,
            env: "Production", envId: prodEnvId
        ))

        // Running DAGs
        statuses.append(dagStatus(
            id: "etl_warehouse_sync",
            tags: ["etl", "warehouse"],
            owners: ["data-eng"],
            state: .running,
            runHistory: [.success, .success, .success, .running, .success],
            startedAgo: 45,
            env: "Production", envId: prodEnvId
        ))
        statuses.append(dagStatus(
            id: "analytics_daily_reports",
            tags: ["analytics", "reports"],
            owners: ["analytics"],
            state: .running,
            runHistory: [.success, .success, .running, .success, .success],
            startedAgo: 120,
            env: "Production", envId: prodEnvId
        ))
        statuses.append(dagStatus(
            id: "data_quality_checks",
            tags: ["dq", "monitoring"],
            owners: ["data-eng"],
            state: .running,
            runHistory: [.success, .running, .success, .success, .success],
            startedAgo: 30,
            env: "Production", envId: prodEnvId
        ))

        // Queued
        statuses.append(dagStatus(
            id: "etl_clickstream_events",
            tags: ["etl", "clickstream"],
            owners: ["data-eng"],
            state: .queued,
            runHistory: [.success, .success, .success, .queued, .success],
            startedAgo: 10,
            env: "Production", envId: prodEnvId
        ))

        // Success DAGs
        statuses.append(dagStatus(
            id: "etl_user_activity_log",
            tags: ["etl", "users"],
            owners: ["data-eng"],
            state: .success,
            runHistory: [.success, .success, .success, .success, .success],
            startedAgo: 900,
            env: "Production", envId: prodEnvId
        ))
        statuses.append(dagStatus(
            id: "notifications_email_digest",
            tags: ["notifications", "email"],
            owners: ["platform"],
            state: .success,
            runHistory: [.success, .success, .success, .failed, .success],
            startedAgo: 1800,
            env: "Production", envId: prodEnvId
        ))
        statuses.append(dagStatus(
            id: "ml_recommendation_train",
            tags: ["ml", "recommendations"],
            owners: ["ml-team"],
            state: .success,
            runHistory: [.success, .success, .success, .success, .success],
            startedAgo: 3600,
            env: "Production", envId: prodEnvId
        ))
        statuses.append(dagStatus(
            id: "etl_product_catalog_sync",
            tags: ["etl", "catalog"],
            owners: ["data-eng"],
            state: .success,
            runHistory: [.success, .success, .success, .success, .success],
            startedAgo: 7200,
            env: "Production", envId: prodEnvId
        ))
        statuses.append(dagStatus(
            id: "backup_database_snapshot",
            tags: ["ops", "backup"],
            owners: ["sre"],
            state: .success,
            runHistory: [.success, .success, .success, .success, .success],
            startedAgo: 14400,
            env: "Production", envId: prodEnvId
        ))

        // ── Staging DAGs ──

        statuses.append(dagStatus(
            id: "etl_customer_payments",
            tags: ["etl", "payments"],
            owners: ["data-eng"],
            state: .success,
            runHistory: [.success, .success, .success, .success, .success],
            startedAgo: 600,
            env: "Staging", envId: stagingEnvId
        ))
        statuses.append(dagStatus(
            id: "etl_warehouse_sync",
            tags: ["etl", "warehouse"],
            owners: ["data-eng"],
            state: .running,
            runHistory: [.success, .running, .success, .failed, .success],
            startedAgo: 60,
            env: "Staging", envId: stagingEnvId
        ))
        statuses.append(dagStatus(
            id: "test_new_pipeline_v2",
            tags: ["test", "experiment"],
            owners: ["data-eng"],
            state: .failed,
            runHistory: [.failed, .failed, .failed, .success, .failed],
            startedAgo: 300,
            env: "Staging", envId: stagingEnvId
        ))

        // Sort: failed → running → queued → success
        statuses.sort { $0.sortPriority < $1.sortPriority }
        return statuses
    }

    // MARK: - Helpers

    private static func dagStatus(
        id dagId: String,
        tags: [String],
        owners: [String],
        state: DAGRunState,
        runHistory: [DAGRunState],
        startedAgo seconds: TimeInterval,
        env environmentName: String,
        envId environmentId: UUID
    ) -> DAGStatus {
        let dag = DAG(
            dagId: dagId,
            isPaused: false,
            tags: tags.map { DAGTag(name: $0) },
            owners: owners
        )

        let startDate = Date().addingTimeInterval(-seconds)
        let endDate = (state == .success || state == .failed)
            ? startDate.addingTimeInterval(Double.random(in: 30...300))
            : nil

        let latestRun = DAGRun(
            dagRunId: "scheduled__\(dagId)__\(ISO8601DateFormatter().string(from: startDate))",
            dagId: dagId,
            state: state,
            logicalDate: startDate,
            startDate: startDate,
            endDate: endDate
        )

        let recentRuns: [DAGRun] = runHistory.enumerated().map { index, runState in
            let runStart = Date().addingTimeInterval(-Double((index + 1) * 3600))
            return DAGRun(
                dagRunId: "scheduled__\(dagId)__run_\(index)",
                dagId: dagId,
                state: runState,
                logicalDate: runStart,
                startDate: runStart,
                endDate: runStart.addingTimeInterval(Double.random(in: 30...300))
            )
        }

        return DAGStatus(
            dag: dag,
            latestRun: latestRun,
            recentRuns: recentRuns,
            environmentId: environmentId,
            environmentName: environmentName
        )
    }
}
