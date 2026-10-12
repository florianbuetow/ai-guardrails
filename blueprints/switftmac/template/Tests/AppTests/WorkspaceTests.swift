import AppDomain
import Foundation
import PropertyBased
import Testing

@Suite("Workspace domain")
struct WorkspaceTests {
    @Test("normalizes a valid name")
    func normalizesName() throws {
        let workspace = try Workspace(name: "  Studio  ", counterValue: 4)
        let expected = try Workspace(name: "Studio", counterValue: 4)

        #expect(workspace == expected)
        #expect(workspace.canReset)
    }

    @Test("rejects a missing name")
    func rejectsMissingName() {
        #expect(throws: WorkspaceError.emptyName) {
            try Workspace(name: "   ", counterValue: 0)
        }
    }

    @Test("a reset counter cannot be reset again")
    func resetAvailability() throws {
        let workspace = try Workspace(name: "Studio", counterValue: 0)
        #expect(!workspace.canReset)
    }

    @Test("persisted data cannot bypass domain validation")
    func rejectsInvalidPersistedCounter() {
        let data = Data(#"{"name":"Studio","counterValue":-1}"#.utf8)
        #expect(throws: WorkspaceError.negativeCount(-1)) {
            try JSONDecoder().decode(Workspace.self, from: data)
        }
    }

    @Test("increment advances every valid counter", .timeLimit(.minutes(1)))
    func incrementProperty() async {
        await propertyCheck(count: 200, input: Gen.int(in: 0...1_000_000)) { count in
            do {
                let workspace = try Workspace(name: "Property", counterValue: count)
                let incremented = try workspace.incremented()
                #expect(incremented.counterValue == count + 1)
                #expect(incremented.name == workspace.name)
            } catch {
                Issue.record("A valid generated workspace failed: \(String(describing: error))")
            }
        }
    }
}
