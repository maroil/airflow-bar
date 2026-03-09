import Testing
import Foundation
@testable import AirflowBarCore

@Suite("Config Migration Tests")
struct ConfigMigrationTests {
    @Test("JSON without version decodes as v1")
    func jsonWithoutVersion() throws {
        let json = """
        {
            "environments": [],
            "refreshInterval": 300,
            "showPausedDAGs": false,
            "maxRunsPerDAG": 5,
            "notifications": {"onFailure": true, "onRecovery": true}
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        #expect(config.version == 1)
    }

    @Test("JSON with version 2 decodes correctly")
    func jsonWithVersion2() throws {
        let json = """
        {
            "version": 2,
            "environments": [],
            "refreshInterval": 300,
            "showPausedDAGs": false,
            "maxRunsPerDAG": 5,
            "notifications": {"onFailure": true, "onRecovery": true}
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        #expect(config.version == 2)
    }

    @Test("Migration chain runs sequentially")
    func migrationChain() throws {
        var json: [String: Any] = [
            "environments": [],
            "refreshInterval": 300,
            "showPausedDAGs": false,
            "maxRunsPerDAG": 5,
            "notifications": ["onFailure": true, "onRecovery": true],
        ]

        let didMigrate = try ConfigMigrator.migrate(json: &json)
        #expect(didMigrate == true)
        #expect(json["version"] as? Int == ConfigMigrator.currentVersion)
    }

    @Test("No migration needed for current version")
    func noMigrationNeeded() throws {
        var json: [String: Any] = [
            "version": ConfigMigrator.currentVersion,
            "environments": [],
        ]

        let didMigrate = try ConfigMigrator.migrate(json: &json)
        #expect(didMigrate == false)
    }

    @Test("v1 to v2 migration strips credentials from JSON")
    func v1ToV2StripsCredentials() throws {
        let envId = UUID()
        var json: [String: Any] = [
            "environments": [
                [
                    "id": envId.uuidString,
                    "name": "Test",
                    "baseURL": "https://airflow.test.com",
                    "isEnabled": true,
                    "credential": [
                        "type": "basicAuth",
                        "username": "admin",
                        "password": "secret",
                    ],
                ] as [String: Any],
            ],
        ]

        let didMigrate = try ConfigMigrator.migrate(json: &json)
        #expect(didMigrate == true)

        // Verify credential was stripped from environments
        if let envs = json["environments"] as? [[String: Any]], let env = envs.first {
            #expect(env["credential"] == nil)
            #expect(env["name"] as? String == "Test")
        } else {
            Issue.record("Expected environments array")
        }
    }

    @Test("v1 to v2 migration keeps inline credentials when keychain save fails")
    func v1ToV2PreservesCredentialsOnSaveFailure() {
        struct SaveFailure: Error {}

        let envId = UUID()
        var json: [String: Any] = [
            "environments": [
                [
                    "id": envId.uuidString,
                    "name": "Test",
                    "baseURL": "https://airflow.test.com",
                    "isEnabled": true,
                    "credential": [
                        "type": "basicAuth",
                        "username": "admin",
                        "password": "secret",
                    ],
                ] as [String: Any],
            ],
        ]

        #expect(throws: ConfigMigrationError.self) {
            try ConfigMigrator.migrate(json: &json) { _, _ in
                throw SaveFailure()
            }
        }

        if let envs = json["environments"] as? [[String: Any]], let env = envs.first {
            #expect(env["credential"] != nil)
        } else {
            Issue.record("Expected environments array")
        }
    }

    @Test("AirflowEnvironment JSON excludes credential")
    func environmentExcludesCredential() throws {
        let env = AirflowEnvironment(
            name: "Prod",
            baseURL: "https://airflow.prod.com",
            credential: .basicAuth(username: "admin", password: "secret"),
            isEnabled: true
        )

        let data = try JSONEncoder().encode(env)
        let jsonString = String(data: data, encoding: .utf8)!

        // credential should NOT be in JSON
        #expect(!jsonString.contains("password"))
        #expect(!jsonString.contains("secret"))
        #expect(!jsonString.contains("username"))
        // Other fields should be present
        #expect(jsonString.contains("baseURL"))
        #expect(jsonString.contains("name"))
    }

    @Test("AppConfig includes version field")
    func configIncludesVersion() throws {
        let config = AppConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["version"] as? Int == ConfigMigrator.currentVersion)
    }

    @Test("URL validation")
    func urlValidation() {
        // Valid URLs
        let validURLs = ["https://airflow.example.com", "http://localhost:8080"]
        for urlString in validURLs {
            let url = URL(string: urlString)
            #expect(url != nil)
            #expect(url?.scheme != nil)
            #expect(url?.host != nil)
        }

        // Invalid URLs
        let noScheme = URL(string: "airflow.example.com")
        #expect(noScheme?.scheme != "http" && noScheme?.scheme != "https")
    }

    @Test("Regex validation")
    func regexValidation() {
        // Valid regex
        let valid = try? NSRegularExpression(pattern: "my_dag.*")
        #expect(valid != nil)

        // Invalid regex
        let invalid = try? NSRegularExpression(pattern: "[invalid")
        #expect(invalid == nil)
    }

    @Test("DAG regex filter matching")
    func dagRegexFiltering() throws {
        let regex = try NSRegularExpression(pattern: "etl_.*")
        let dagIds = ["etl_daily", "etl_hourly", "ml_training", "etl_weekly"]

        let matched = dagIds.filter { dagId in
            let range = NSRange(dagId.startIndex..., in: dagId)
            return regex.firstMatch(in: dagId, range: range) != nil
        }

        #expect(matched.count == 3)
        #expect(matched.contains("etl_daily"))
        #expect(!matched.contains("ml_training"))
    }
}
