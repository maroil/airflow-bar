import Testing
import Foundation
@testable import AirflowBarCore

@Suite("Airflow Web URL Tests")
struct AirflowWebURLTests {
    @Test("Build home URL from base URL")
    func buildHomeURL() {
        let url = AirflowWebURL.home(baseURL: "https://airflow.example.com")
        #expect(url?.absoluteString == "https://airflow.example.com/home")
    }

    @Test("Encode DAG ID as a single path segment")
    func buildDagGridURL() {
        let url = AirflowWebURL.dagGrid(
            baseURL: "https://airflow.example.com/airflow",
            dagId: "team dag/foo"
        )

        #expect(
            url?.absoluteString ==
            "https://airflow.example.com/airflow/dags/team%20dag%2Ffoo/grid"
        )
    }
}
