import AppApplication
import AppDomain
import AppInfrastructure
import Foundation
import Testing

@Suite("File workspace store")
struct FileWorkspaceStoreTests {
    @Test("distinguishes a missing file from corrupt data")
    func firstLaunchAndCorruption() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "workspace.json", directoryHint: .notDirectory)
        let store = FileWorkspaceStore(fileURL: fileURL, fileManager: .default)

        #expect(try await store.load() == .firstLaunch)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try Data("not-json".utf8).write(to: fileURL)

        await #expect(throws: FileWorkspaceStoreError.self) {
            try await store.load()
        }
        try FileManager.default.removeItem(at: directory)
    }

    @Test("reports a missing required field")
    func missingRequiredField() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let fileURL = directory.appending(path: "workspace.json", directoryHint: .notDirectory)
        try Data(#"{"name":"Studio"}"#.utf8).write(to: fileURL)
        let store = FileWorkspaceStore(fileURL: fileURL, fileManager: .default)

        do {
            _ = try await store.load()
            Issue.record("Loading data without count should fail.")
        } catch let error as FileWorkspaceStoreError {
            #expect(error == .missingRequiredField("counterValue"))
        } catch {
            Issue.record("Unexpected error: \(String(describing: error))")
        }
        try FileManager.default.removeItem(at: directory)
    }
}
