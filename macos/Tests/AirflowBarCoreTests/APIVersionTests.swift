import Testing
import Foundation
@testable import AirflowBarCore

@Suite("API Version Tests")
struct APIVersionTests {
    @Test("APIVersion path prefixes")
    func pathPrefixes() {
        #expect(APIVersion.v1.pathPrefix == "/api/v1")
        #expect(APIVersion.v2.pathPrefix == "/api/v2")
    }

    @Test("Endpoint URLs for v1")
    func endpointUrlsV1() {
        let dagsUrl = Endpoint.dags(limit: 50, offset: 10).url(baseURL: "https://airflow.example.com", version: .v1)
        #expect(dagsUrl?.absoluteString.contains("/api/v1/dags") == true)
        #expect(dagsUrl?.absoluteString.contains("limit=50") == true)

        let runsUrl = Endpoint.dagRuns(dagId: "my_dag", limit: 5).url(baseURL: "https://airflow.example.com/", version: .v1)
        #expect(runsUrl?.absoluteString.contains("/api/v1/dags/my_dag/dagRuns") == true)
        #expect(runsUrl?.absoluteString.contains("execution_date") == true)

        let healthUrl = Endpoint.health.url(baseURL: "https://airflow.example.com", version: .v1)
        #expect(healthUrl?.absoluteString == "https://airflow.example.com/api/v1/health")
    }

    @Test("Endpoint URLs for v2")
    func endpointUrlsV2() {
        let dagsUrl = Endpoint.dags(limit: 100).url(baseURL: "https://airflow.example.com", version: .v2)
        #expect(dagsUrl?.absoluteString.contains("/api/v2/dags") == true)

        let runsUrl = Endpoint.dagRuns(dagId: "my_dag", limit: 5).url(baseURL: "https://airflow.example.com", version: .v2)
        #expect(runsUrl?.absoluteString.contains("/api/v2/dags/my_dag/dagRuns") == true)
        #expect(runsUrl?.absoluteString.contains("logical_date") == true)

        let healthUrl = Endpoint.health.url(baseURL: "https://airflow.example.com", version: .v2)
        #expect(healthUrl?.absoluteString == "https://airflow.example.com/api/v2/health")
    }

    @Test("Version endpoint URL")
    func versionEndpoint() {
        let url = Endpoint.version.url(baseURL: "https://airflow.example.com", version: .v2)
        #expect(url?.absoluteString == "https://airflow.example.com/api/v2/version")
    }

    @Test("DAGRun decodes with logical_date (v2)")
    func dagRunDecodesLogicalDate() throws {
        let json = """
        {
            "dag_run_id": "run1",
            "dag_id": "dag1",
            "state": "success",
            "logical_date": "2024-06-01T00:00:00+00:00",
            "start_date": "2024-06-01T00:00:01+00:00"
        }
        """.data(using: .utf8)!

        let run = try makeDecoder().decode(DAGRun.self, from: json)
        #expect(run.dagRunId == "run1")
        #expect(run.state == .success)
        #expect(run.logicalDate != nil)
    }

    @Test("DAGRun decodes with execution_date (v1)")
    func dagRunDecodesExecutionDate() throws {
        let json = """
        {
            "dag_run_id": "run2",
            "dag_id": "dag1",
            "state": "running",
            "execution_date": "2024-01-01T00:00:00+00:00"
        }
        """.data(using: .utf8)!

        let run = try makeDecoder().decode(DAGRun.self, from: json)
        #expect(run.dagRunId == "run2")
        #expect(run.state == .running)
        #expect(run.logicalDate != nil) // execution_date falls back to logicalDate
    }

    @Test("DAG decodes with timetable_description (v2)")
    func dagDecodesTimetable() throws {
        let json = """
        {
            "dag_id": "my_dag",
            "is_paused": false,
            "tags": [],
            "owners": [],
            "timetable_description": "Every 5 minutes"
        }
        """.data(using: .utf8)!

        let dag = try makeDecoder().decode(DAG.self, from: json)
        #expect(dag.timetableDescription == "Every 5 minutes")
        #expect(dag.scheduleInterval == nil)
    }

    @Test("DAGStatus with environment info")
    func dagStatusWithEnvironment() {
        let envId = UUID()
        let status = DAGStatus(
            dag: DAG(dagId: "test_dag"),
            environmentId: envId,
            environmentName: "Production"
        )
        #expect(status.id == "\(envId):test_dag")
        #expect(status.environmentName == "Production")
    }

    @Test("DAGStatus without environment uses dagId as id")
    func dagStatusWithoutEnvironment() {
        let status = DAGStatus(dag: DAG(dagId: "test_dag"))
        #expect(status.id == "test_dag")
    }

    @Test("APIVersion is Codable")
    func apiVersionCodable() throws {
        let v2 = APIVersion.v2
        let data = try JSONEncoder().encode(v2)
        let decoded = try JSONDecoder().decode(APIVersion.self, from: data)
        #expect(decoded == .v2)
    }

    @Test("Endpoint default version is v1")
    func endpointDefaultVersion() {
        let url = Endpoint.health.url(baseURL: "https://airflow.example.com")
        #expect(url?.absoluteString == "https://airflow.example.com/api/v1/health")
    }

    // MARK: - Helper

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
}
