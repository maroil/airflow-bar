import Testing
import Foundation
@testable import AirflowBarCore

@Suite("ConfigStore Tests")
struct ConfigStoreTests {
    @Test("Default config values")
    func defaultConfig() {
        let config = AppConfig.default
        #expect(config.environments.isEmpty)
        #expect(config.refreshInterval == .fiveMinutes)
        #expect(config.showPausedDAGs == false)
        #expect(config.dagFilter == nil)
        #expect(config.maxRunsPerDAG == 5)
        #expect(config.notifications.onFailure == true)
        #expect(config.notifications.onRecovery == true)
        #expect(config.version == ConfigMigrator.currentVersion)
    }

    @Test("AppConfig encoding/decoding roundtrip")
    func configRoundtrip() throws {
        let env = AirflowEnvironment(
            name: "Test",
            baseURL: "https://airflow.test.com",
            credential: .basicAuth(username: "admin", password: "pass"),
            isEnabled: true
        )
        let config = AppConfig(
            environments: [env],
            refreshInterval: .twoMinutes,
            showPausedDAGs: true,
            dagFilter: "my_dag.*",
            maxRunsPerDAG: 3,
            notifications: NotificationSettings(onFailure: true, onRecovery: false)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.environments.count == 1)
        #expect(decoded.environments[0].name == "Test")
        #expect(decoded.environments[0].baseURL == "https://airflow.test.com")
        #expect(decoded.refreshInterval == .twoMinutes)
        #expect(decoded.showPausedDAGs == true)
        #expect(decoded.dagFilter == "my_dag.*")
        #expect(decoded.maxRunsPerDAG == 3)
        #expect(decoded.notifications.onRecovery == false)
        #expect(decoded.version == ConfigMigrator.currentVersion)
    }

    @Test("ActiveEnvironment returns first enabled")
    func activeEnvironment() {
        let disabled = AirflowEnvironment(name: "Disabled", baseURL: "", isEnabled: false)
        let enabled = AirflowEnvironment(name: "Enabled", baseURL: "https://a.com", isEnabled: true)
        let config = AppConfig(environments: [disabled, enabled])
        #expect(config.activeEnvironment?.name == "Enabled")
    }

    @Test("ActiveEnvironment returns nil when empty")
    func activeEnvironmentNil() {
        let config = AppConfig()
        #expect(config.activeEnvironment == nil)
    }

    @Test("EnabledEnvironments returns all enabled")
    func enabledEnvironments() {
        let e1 = AirflowEnvironment(name: "A", baseURL: "https://a.com", isEnabled: true)
        let e2 = AirflowEnvironment(name: "B", baseURL: "https://b.com", isEnabled: false)
        let e3 = AirflowEnvironment(name: "C", baseURL: "https://c.com", isEnabled: true)
        let config = AppConfig(environments: [e1, e2, e3])
        #expect(config.enabledEnvironments.count == 2)
    }

    @Test("RefreshInterval values")
    func refreshIntervalValues() {
        #expect(RefreshInterval.oneMinute.rawValue == 60)
        #expect(RefreshInterval.fiveMinutes.rawValue == 300)
        #expect(RefreshInterval.thirtyMinutes.rawValue == 1800)
        #expect(RefreshInterval.allCases.count == 7)
    }

    @Test("AirflowEnvironment encoding excludes credential")
    func environmentEncoding() throws {
        let env = AirflowEnvironment(
            name: "Prod",
            baseURL: "https://airflow.prod.com",
            credential: .bearerToken("secret-token"),
            isEnabled: true
        )
        let data = try JSONEncoder().encode(env)
        let jsonString = String(data: data, encoding: .utf8)!
        #expect(jsonString.contains("Prod"))
        #expect(!jsonString.contains("secret-token"))
        #expect(!jsonString.contains("credential"))
    }

    @Test("AirflowEnvironment decoding gives placeholder credential")
    func environmentDecoding() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "name": "Test",
            "baseURL": "https://airflow.test.com",
            "isEnabled": true
        }
        """.data(using: .utf8)!

        let env = try JSONDecoder().decode(AirflowEnvironment.self, from: json)
        #expect(env.name == "Test")
        // Credential should be placeholder
        if case .basicAuth(let u, let p) = env.credential {
            #expect(u == "")
            #expect(p == "")
        } else {
            Issue.record("Expected placeholder basicAuth")
        }
    }

    @Test("Config JSON matches expected format")
    func configJsonFormat() throws {
        let env = AirflowEnvironment(
            name: "Production",
            baseURL: "https://airflow.example.com",
            credential: .basicAuth(username: "admin", password: "password"),
            isEnabled: true
        )
        let config = AppConfig(
            environments: [env],
            refreshInterval: .fiveMinutes,
            showPausedDAGs: false,
            notifications: NotificationSettings(onFailure: true, onRecovery: true)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let jsonString = String(data: data, encoding: .utf8)!

        // Verify key fields are present
        #expect(jsonString.contains("\"baseURL\""))
        #expect(jsonString.contains("\"refreshInterval\""))
        #expect(jsonString.contains("\"showPausedDAGs\""))
        #expect(jsonString.contains("\"version\""))
        // Verify credentials are NOT in JSON
        #expect(!jsonString.contains("\"password\""))
        #expect(!jsonString.contains("\"credential\""))
    }
}
