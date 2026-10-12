import Foundation

public struct Workspace: Codable, Equatable, Sendable {
    public let name: String
    public let counterValue: Int

    public var canReset: Bool {
        counterValue > 0
    }

    public init(name: String, counterValue: Int) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw WorkspaceError.emptyName
        }
        guard counterValue >= 0 else {
            throw WorkspaceError.negativeCount(counterValue)
        }
        self.name = normalizedName
        self.counterValue = counterValue
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case counterValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: container.decode(String.self, forKey: .name),
            counterValue: container.decode(Int.self, forKey: .counterValue))
    }

    public func incremented() throws -> Workspace {
        let (nextCount, overflowed) = counterValue.addingReportingOverflow(1)
        guard !overflowed else {
            throw WorkspaceError.counterOverflow
        }
        return try Workspace(name: name, counterValue: nextCount)
    }

    public func reset() throws -> Workspace {
        try Workspace(name: name, counterValue: 0)
    }
}

public enum WorkspaceError: Error, Equatable, LocalizedError, Sendable {
    case emptyName
    case negativeCount(Int)
    case counterOverflow

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            "Workspace name is required."
        case .negativeCount(let count):
            "Workspace count cannot be negative: \(count)."
        case .counterOverflow:
            "The counter reached its maximum value."
        }
    }
}
