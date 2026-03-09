import Testing
import Foundation
@testable import AirflowBarCore

@Suite("Keychain Service Tests")
struct KeychainServiceTests {
    @Test("Save and load credential roundtrip")
    func saveLoadRoundtrip() throws {
        let envId = UUID()
        let credential = AuthCredential.basicAuth(username: "testuser", password: "testpass")

        // Save
        try KeychainService.save(credential: credential, for: envId)

        // Load
        let loaded = KeychainService.load(for: envId)
        #expect(loaded != nil)
        if case .basicAuth(let u, let p) = loaded {
            #expect(u == "testuser")
            #expect(p == "testpass")
        } else {
            Issue.record("Expected basicAuth credential")
        }

        // Cleanup
        KeychainService.delete(for: envId)
    }

    @Test("Delete removes credential")
    func deleteCredential() throws {
        let envId = UUID()
        try KeychainService.save(credential: .bearerToken("tok123"), for: envId)

        KeychainService.delete(for: envId)
        let loaded = KeychainService.load(for: envId)
        #expect(loaded == nil)
    }

    @Test("Load non-existent returns nil")
    func loadNonExistent() {
        let loaded = KeychainService.load(for: UUID())
        #expect(loaded == nil)
    }

    @Test("Update credential overwrites")
    func updateCredential() throws {
        let envId = UUID()
        try KeychainService.save(credential: .basicAuth(username: "old", password: "old"), for: envId)
        try KeychainService.save(credential: .bearerToken("newtoken"), for: envId)

        let loaded = KeychainService.load(for: envId)
        if case .bearerToken(let t) = loaded {
            #expect(t == "newtoken")
        } else {
            Issue.record("Expected bearerToken after update")
        }

        // Cleanup
        KeychainService.delete(for: envId)
    }

    @Test("Bearer token roundtrip")
    func bearerTokenRoundtrip() throws {
        let envId = UUID()
        let credential = AuthCredential.bearerToken("my-secret-token-123")

        try KeychainService.save(credential: credential, for: envId)
        let loaded = KeychainService.load(for: envId)

        if case .bearerToken(let t) = loaded {
            #expect(t == "my-secret-token-123")
        } else {
            Issue.record("Expected bearerToken")
        }

        KeychainService.delete(for: envId)
    }
}
