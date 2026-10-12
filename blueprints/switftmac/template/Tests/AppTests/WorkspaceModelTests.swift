import AppApplication
import AppDomain
import Testing

@MainActor
@Suite("Workspace application")
struct WorkspaceModelTests {
    @Test("exposes first launch explicitly")
    func firstLaunch() async {
        let store = MemoryWorkspaceStore(initial: .firstLaunch)
        let model = WorkspaceModel(store: store)

        await model.load()

        #expect(model.phase == .firstLaunch)
    }

    @Test("persists before publishing an increment")
    func increment() async throws {
        let original = try Workspace(name: "Studio", counterValue: 3)
        let store = MemoryWorkspaceStore(initial: .existing(original))
        let model = WorkspaceModel(store: store)
        await model.load()

        await model.increment()

        let saved = await store.savedWorkspace()
        let expected = try Workspace(name: "Studio", counterValue: 4)
        #expect(saved == expected)
        #expect(model.phase == .ready(expected))
    }
}

private actor MemoryWorkspaceStore: WorkspaceStore {
    private let initial: StoredWorkspace
    private var saved: Workspace?

    init(initial: StoredWorkspace) {
        self.initial = initial
    }

    func load() async throws -> StoredWorkspace {
        initial
    }

    func save(_ workspace: Workspace) async throws {
        saved = workspace
    }

    func savedWorkspace() -> Workspace? {
        saved
    }
}
