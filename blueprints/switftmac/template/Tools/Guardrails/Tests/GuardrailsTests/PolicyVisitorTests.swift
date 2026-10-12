import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@testable import Guardrails

@Suite("SwiftSyntax architecture policy")
struct PolicyVisitorTests {
    @Test("allows pure Foundation value operations in core modules")
    func allowsValueOperations() {
        let source = """
            import Foundation

            struct DomainFailure: LocalizedError {
                let errorDescription: String?
            }

            func normalized(_ value: String) -> String {
                value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            """

        #expect(findings(in: source).isEmpty)
    }

    @Test("rejects explicit and inferred Foundation file reads in core modules")
    func rejectsFileReads() {
        let source = """
            import Foundation

            func explicitRead(_ url: URL) throws -> Data {
                try Data(contentsOf: url)
            }

            func inferredRead(_ url: URL) throws -> Data {
                try .init(contentsOf: url)
            }
            """

        let violations = findings(in: source).filter { $0.contains("[architecture.effects]") }
        #expect(violations.count == 2)
    }

    @Test("rejects direct and aliased effect types in core modules")
    func rejectsEffectTypes() {
        let source = """
            import Foundation

            typealias HiddenFiles = FileManager

            func standardFiles() -> FileManager {
                FileManager.default
            }
            """

        let violations = findings(in: source).filter { $0.contains("[architecture.effects]") }
        #expect(violations.count >= 2)
    }

    @Test("accepts the declared source modules and rejects an extra module")
    func validatesSourceModules() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sources = root.appending(path: "Sources", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: sources, withIntermediateDirectories: true, attributes: nil)
        for module in ["App", "AppApplication", "AppDomain", "AppInfrastructure", "AppUI"] {
            try FileManager.default.createDirectory(
                at: sources.appending(path: module, directoryHint: .isDirectory),
                withIntermediateDirectories: false,
                attributes: nil
            )
        }

        #expect(try Guardrails.sourceLayoutFindings(root: root).isEmpty)

        try FileManager.default.createDirectory(
            at: sources.appending(path: "UnexpectedFeature", directoryHint: .isDirectory),
            withIntermediateDirectories: false,
            attributes: nil
        )
        let violations = try Guardrails.sourceLayoutFindings(root: root)
        #expect(violations.count == 1)
        guard let violation = violations.first else {
            Issue.record("Expected an architecture.modules violation")
            return
        }
        #expect(violation.contains("[architecture.modules]"))

        try FileManager.default.removeItem(at: root)
    }

    private func findings(in source: String) -> [String] {
        let tree = Parser.parse(source: source)
        let visitor = PolicyVisitor(
            path: "Fixture.swift",
            tree: tree,
            allowedImports: ["Foundation", "Swift"],
            isCore: true
        )
        visitor.walk(tree)
        return visitor.findings
    }
}
