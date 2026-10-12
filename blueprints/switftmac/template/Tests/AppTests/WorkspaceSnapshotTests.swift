import AppApplication
import AppDomain
import AppKit
import AppUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class SnapshotTests: XCTestCase {
    func testStates() async throws {
        let workspace = try Workspace(name: "Studio", counterValue: 0)
        let model = WorkspaceModel(store: SnapshotStore(initial: .existing(workspace)))
        await model.load()

        let state = snapshotDescription(model.phase)

        assertSnapshot(of: state, as: .lines, named: "states")
    }

    func testFirstLaunchImage() async {
        let model = WorkspaceModel(store: SnapshotStore(initial: .firstLaunch))
        await model.load()

        assertSnapshot(of: hostingView(model: model), as: .image, named: "first-launch")
    }

    func testReadyImage() async throws {
        let workspace = try Workspace(name: "Studio", counterValue: 7)
        let model = WorkspaceModel(store: SnapshotStore(initial: .existing(workspace)))
        await model.load()

        assertSnapshot(of: hostingView(model: model), as: .image, named: "ready")
    }

    private func hostingView(model: WorkspaceModel) -> NSView {
        let view = ContentView(model: model)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .frame(width: 640, height: 480)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 640, height: 480)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }

    private func snapshotDescription(_ phase: WorkspacePhase) -> String {
        switch phase {
        case .loading:
            "loading"
        case .firstLaunch:
            "first-launch"
        case .ready(let workspace):
            "ready(name: \(workspace.name), count: \(workspace.counterValue))"
        case .failed(let message):
            "failed(message: \(message))"
        }
    }
}

private actor SnapshotStore: WorkspaceStore {
    private let initial: StoredWorkspace

    init(initial: StoredWorkspace) {
        self.initial = initial
    }

    func load() async throws -> StoredWorkspace {
        initial
    }

    func save(_ workspace: Workspace) async throws {
        throw SnapshotStoreError.unexpectedSave
    }
}

private enum SnapshotStoreError: Error {
    case unexpectedSave
}
