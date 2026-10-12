import AppApplication
import AppDomain
import Foundation

public actor FileWorkspaceStore: WorkspaceStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, fileManager: FileManager) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    public func load() async throws -> StoredWorkspace {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .firstLaunch
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw FileWorkspaceStoreError.readFailed(String(describing: error))
        }

        do {
            return .existing(try decoder.decode(Workspace.self, from: data))
        } catch let DecodingError.keyNotFound(key, _) {
            throw FileWorkspaceStoreError.missingRequiredField(key.stringValue)
        } catch let DecodingError.valueNotFound(_, context) {
            guard let key = context.codingPath.last else {
                throw FileWorkspaceStoreError.corruptData("A missing value had no coding path.")
            }
            throw FileWorkspaceStoreError.missingRequiredField(key.stringValue)
        } catch let error as DecodingError {
            throw FileWorkspaceStoreError.corruptData(String(describing: error))
        } catch {
            throw FileWorkspaceStoreError.decodeFailed(String(describing: error))
        }
    }

    public func save(_ workspace: Workspace) async throws {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(workspace)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw FileWorkspaceStoreError.writeFailed(String(describing: error))
        }
    }
}

public enum FileWorkspaceStoreError: Error, Equatable, LocalizedError, Sendable {
    case readFailed(String)
    case missingRequiredField(String)
    case corruptData(String)
    case decodeFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .readFailed(let detail):
            "The workspace could not be read: \(detail)"
        case .missingRequiredField(let field):
            "The saved workspace is missing the required field '\(field)'."
        case .corruptData(let detail):
            "The saved workspace is corrupt: \(detail)"
        case .decodeFailed(let detail):
            "The saved workspace could not be decoded: \(detail)"
        case .writeFailed(let detail):
            "The workspace could not be saved: \(detail)"
        }
    }
}
