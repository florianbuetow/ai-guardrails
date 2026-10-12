import AppDomain

public enum StoredWorkspace: Equatable, Sendable {
    case firstLaunch
    case existing(Workspace)
}

public protocol WorkspaceStore: Sendable {
    func load() async throws -> StoredWorkspace
    func save(_ workspace: Workspace) async throws
}
