import AppApplication
import AppDomain
import AppUI
import Testing
import ViewInspector

@MainActor
@Suite("Content view inspection")
struct ContentViewInspectionTests {
    @Test("first launch asks for a workspace name")
    func firstLaunchPrompt() async throws {
        let model = WorkspaceModel(store: FirstLaunchStore())
        await model.load()

        let view = ContentView(model: model)

        _ = try view.inspect().find(text: "Create your workspace")
        _ = try view.inspect().find(viewWithAccessibilityIdentifier: "workspace-name")
    }
}

private actor FirstLaunchStore: WorkspaceStore {
    func load() async throws -> StoredWorkspace {
        .firstLaunch
    }

    func save(_ workspace: Workspace) async throws {
        throw InspectionStoreError.unexpectedSave
    }
}

private enum InspectionStoreError: Error {
    case unexpectedSave
}
