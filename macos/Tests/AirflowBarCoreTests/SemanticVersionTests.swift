import Testing
@testable import AirflowBarCore

@Suite("SemanticVersion Tests")
struct SemanticVersionTests {
    @Test("Parse valid version strings")
    func parseValid() {
        let v = SemanticVersion("1.2.3")
        #expect(v != nil)
        #expect(v?.major == 1)
        #expect(v?.minor == 2)
        #expect(v?.patch == 3)
    }

    @Test("Parse version with v prefix")
    func parseWithPrefix() {
        let v = SemanticVersion("v1.0.5")
        #expect(v != nil)
        #expect(v?.major == 1)
        #expect(v?.minor == 0)
        #expect(v?.patch == 5)
    }

    @Test("Parse version with pre-release suffix")
    func parsePreRelease() {
        let v = SemanticVersion("0.0.0-dev")
        #expect(v != nil)
        #expect(v?.major == 0)
        #expect(v?.minor == 0)
        #expect(v?.patch == 0)
        #expect(v?.isDev == true)
    }

    @Test("Invalid version strings return nil")
    func parseInvalid() {
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("1.2") == nil)
        #expect(SemanticVersion("abc") == nil)
        #expect(SemanticVersion("1.2.3.4") == nil)
    }

    @Test("Version comparison - less than")
    func lessThan() {
        #expect(SemanticVersion("1.0.0")! < SemanticVersion("2.0.0")!)
        #expect(SemanticVersion("1.0.0")! < SemanticVersion("1.1.0")!)
        #expect(SemanticVersion("1.0.0")! < SemanticVersion("1.0.1")!)
        #expect(SemanticVersion("0.9.9")! < SemanticVersion("1.0.0")!)
    }

    @Test("Version comparison - equal")
    func equal() {
        #expect(SemanticVersion("1.2.3")! == SemanticVersion("1.2.3")!)
        #expect(SemanticVersion("v1.2.3")! == SemanticVersion("1.2.3")!)
    }

    @Test("Version comparison - greater than")
    func greaterThan() {
        #expect(SemanticVersion("2.0.0")! > SemanticVersion("1.0.0")!)
        #expect(SemanticVersion("1.1.0")! > SemanticVersion("1.0.9")!)
    }

    @Test("Dev version detection")
    func devVersion() {
        #expect(SemanticVersion("0.0.0")!.isDev == true)
        #expect(SemanticVersion("0.0.1")!.isDev == false)
        #expect(SemanticVersion("1.0.0")!.isDev == false)
    }

    @Test("Description format")
    func description() {
        #expect(SemanticVersion("v1.2.3")!.description == "1.2.3")
    }
}
