import Testing
import Foundation
@testable import AirflowBarCore

@Suite("Model Decoding Tests")
struct ModelDecodingTests {
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date")
        }
        return decoder
    }

    @Test("Decode DAG from JSON")
    func decodeDag() throws {
        let json = """
        {
            "dag_id": "example_dag",
            "is_paused": false,
            "tags": [{"name": "etl"}, {"name": "daily"}],
            "owners": ["airflow"],
            "description": "An example DAG"
        }
        """.data(using: .utf8)!

        let dag = try makeDecoder().decode(DAG.self, from: json)
        #expect(dag.dagId == "example_dag")
        #expect(dag.isPaused == false)
        #expect(dag.tags.count == 2)
        #expect(dag.tags[0].name == "etl")
        #expect(dag.owners == ["airflow"])
        #expect(dag.description == "An example DAG")
    }

    @Test("Decode DAGRun from JSON with execution_date")
    func decodeDagRun() throws {
        let json = """
        {
            "dag_run_id": "manual__2024-01-01T00:00:00+00:00",
            "dag_id": "example_dag",
            "state": "success",
            "execution_date": "2024-01-01T00:00:00+00:00",
            "start_date": "2024-01-01T00:00:01.123456+00:00",
            "end_date": "2024-01-01T00:05:00+00:00",
            "external_trigger": false
        }
        """.data(using: .utf8)!

        let run = try makeDecoder().decode(DAGRun.self, from: json)
        #expect(run.dagRunId == "manual__2024-01-01T00:00:00+00:00")
        #expect(run.dagId == "example_dag")
        #expect(run.state == .success)
        #expect(run.logicalDate != nil)
        #expect(run.startDate != nil)
        #expect(run.externalTrigger == false)
    }

    @Test("Decode DAGRun with logical_date")
    func decodeDagRunLogicalDate() throws {
        let json = """
        {
            "dag_run_id": "run1",
            "dag_id": "dag1",
            "state": "running",
            "logical_date": "2024-06-01T12:00:00+00:00"
        }
        """.data(using: .utf8)!

        let run = try makeDecoder().decode(DAGRun.self, from: json)
        #expect(run.logicalDate != nil)
    }

    @Test("Decode DAGCollection from JSON")
    func decodeDagCollection() throws {
        let json = """
        {
            "dags": [
                {"dag_id": "dag1", "is_paused": false, "tags": [], "owners": []},
                {"dag_id": "dag2", "is_paused": true, "tags": [], "owners": []}
            ],
            "total_entries": 2
        }
        """.data(using: .utf8)!

        let collection = try makeDecoder().decode(DAGCollection.self, from: json)
        #expect(collection.dags.count == 2)
        #expect(collection.totalEntries == 2)
        #expect(collection.dags[1].isPaused == true)
    }

    @Test("Decode DAGRunCollection from JSON")
    func decodeDagRunCollection() throws {
        let json = """
        {
            "dag_runs": [
                {"dag_run_id": "run1", "dag_id": "dag1", "state": "failed"},
                {"dag_run_id": "run2", "dag_id": "dag1", "state": "running"}
            ],
            "total_entries": 2
        }
        """.data(using: .utf8)!

        let collection = try makeDecoder().decode(DAGRunCollection.self, from: json)
        #expect(collection.dagRuns.count == 2)
        #expect(collection.dagRuns[0].state == .failed)
        #expect(collection.dagRuns[1].state == .running)
    }

    @Test("Decode HealthInfo from JSON")
    func decodeHealthInfo() throws {
        let json = """
        {
            "metadatabase": {"status": "healthy"},
            "scheduler": {"status": "healthy", "latest_scheduler_heartbeat": "2024-01-01T12:00:00+00:00"}
        }
        """.data(using: .utf8)!

        let health = try makeDecoder().decode(HealthInfo.self, from: json)
        #expect(health.isHealthy == true)
        #expect(health.scheduler.latestSchedulerHeartbeat != nil)
    }

    @Test("HealthInfo unhealthy detection")
    func unhealthyDetection() throws {
        let json = """
        {
            "metadatabase": {"status": "unhealthy"},
            "scheduler": {"status": "healthy"}
        }
        """.data(using: .utf8)!

        let health = try makeDecoder().decode(HealthInfo.self, from: json)
        #expect(health.isHealthy == false)
    }

    @Test("DAGRunState properties")
    func dagRunStateProperties() {
        #expect(DAGRunState.failed.sortPriority < DAGRunState.running.sortPriority)
        #expect(DAGRunState.running.sortPriority < DAGRunState.success.sortPriority)
        #expect(DAGRunState.failed.sfSymbol == "xmark.circle.fill")
        #expect(DAGRunState.success.displayName == "Success")
    }

    @Test("AuthCredential encoding/decoding roundtrip")
    func authCredentialRoundtrip() throws {
        let basic = AuthCredential.basicAuth(username: "admin", password: "secret")
        let encoded = try JSONEncoder().encode(basic)
        let decoded = try JSONDecoder().decode(AuthCredential.self, from: encoded)
        if case .basicAuth(let u, let p) = decoded {
            #expect(u == "admin")
            #expect(p == "secret")
        } else {
            Issue.record("Expected basicAuth")
        }

        let bearer = AuthCredential.bearerToken("mytoken123")
        let encoded2 = try JSONEncoder().encode(bearer)
        let decoded2 = try JSONDecoder().decode(AuthCredential.self, from: encoded2)
        if case .bearerToken(let t) = decoded2 {
            #expect(t == "mytoken123")
        } else {
            Issue.record("Expected bearerToken")
        }
    }

    @Test("AuthCredential header values")
    func authCredentialHeaders() {
        let basic = AuthCredential.basicAuth(username: "admin", password: "pass")
        let expected = "Basic \(Data("admin:pass".utf8).base64EncodedString())"
        #expect(basic.headerValue == expected)

        let bearer = AuthCredential.bearerToken("tok123")
        #expect(bearer.headerValue == "Bearer tok123")
    }

    @Test("DAGStatus sort priority")
    func dagStatusSortPriority() {
        let failedStatus = DAGStatus(
            dag: DAG(dagId: "a"),
            latestRun: DAGRun(dagRunId: "r1", dagId: "a", state: .failed)
        )
        let runningStatus = DAGStatus(
            dag: DAG(dagId: "b"),
            latestRun: DAGRun(dagRunId: "r2", dagId: "b", state: .running)
        )
        let pausedStatus = DAGStatus(dag: DAG(dagId: "c", isPaused: true))

        #expect(failedStatus.sortPriority < runningStatus.sortPriority)
        #expect(runningStatus.sortPriority < pausedStatus.sortPriority)
    }

    @Test("Endpoint URL construction with default version")
    func endpointUrls() {
        let dagsUrl = Endpoint.dags(limit: 50, offset: 10).url(baseURL: "https://airflow.example.com")
        #expect(dagsUrl?.absoluteString.contains("/api/v1/dags") == true)
        #expect(dagsUrl?.absoluteString.contains("limit=50") == true)

        let runsUrl = Endpoint.dagRuns(dagId: "my_dag", limit: 5).url(baseURL: "https://airflow.example.com/")
        #expect(runsUrl?.absoluteString.contains("/api/v1/dags/my_dag/dagRuns") == true)

        let healthUrl = Endpoint.health.url(baseURL: "https://airflow.example.com")
        #expect(healthUrl?.absoluteString == "https://airflow.example.com/api/v1/health")
    }
}
