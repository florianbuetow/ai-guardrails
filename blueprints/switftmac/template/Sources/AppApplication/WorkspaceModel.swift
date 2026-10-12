import AppDomain
import Foundation
import Observation

public enum WorkspacePhase: Equatable, Sendable {
    case loading
    case firstLaunch
    case ready(Workspace)
    case failed(String)
}

@MainActor
@Observable
public final class WorkspaceModel {
    public private(set) var phase: WorkspacePhase
    private let store: any WorkspaceStore

    public init(store: any WorkspaceStore) {
        phase = .loading
        self.store = store
    }

    public func load() async {
        guard phase == .loading else {
            return
        }
        do {
            switch try await store.load() {
            case .firstLaunch:
                phase = .firstLaunch
            case .existing(let workspace):
                phase = .ready(workspace)
            }
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    public func retryLoading() async {
        phase = .loading
        await load()
    }

    public func createWorkspace(named name: String) async {
        do {
            let workspace = try Workspace(name: name, counterValue: 0)
            try await store.save(workspace)
            phase = .ready(workspace)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    public func increment() async {
        guard case .ready(let workspace) = phase else {
            phase = .failed("A workspace must be loaded before its counter can be changed.")
            return
        }
        do {
            let updated = try workspace.incremented()
            try await store.save(updated)
            phase = .ready(updated)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    public func reset() async {
        guard case .ready(let workspace) = phase else {
            phase = .failed("A workspace must be loaded before its counter can be reset.")
            return
        }
        do {
            let updated = try workspace.reset()
            try await store.save(updated)
            phase = .ready(updated)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: any Error) -> String {
        if let localizedError = error as? any LocalizedError,
            let description = localizedError.errorDescription
        {
            return description
        }
        return "Unexpected failure: \(String(describing: error))"
    }
}
