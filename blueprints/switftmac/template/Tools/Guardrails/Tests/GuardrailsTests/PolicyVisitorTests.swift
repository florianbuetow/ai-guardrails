import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@testable import Guardrails

@Suite("SwiftSyntax architecture policy")
struct PolicyVisitorTests {
    @Test("allows the AppUI import boundary")
    func allowsAppUIImports() {
        let source = """
            import SwiftUI

            struct Greeting: View {
                var body: some View { Text("Hello World!") }
            }
            """

        #expect(findings(in: source).isEmpty)
    }

    @Test("rejects imports outside the AppUI boundary")
    func rejectsForbiddenImport() {
        let source = """
            import Foundation
            """

        #expect(findings(in: source).contains { $0.contains("[architecture.import]") })
    }

    @Test("rejects silent defaults, discarded errors, and checker suppression")
    func rejectsPolicyBypasses() {
        let source = """
            // swiftlint:disable force_unwrapping
            func greeting(_ value: String? = nil) -> String {
                _ = try? riskyOperation()
                return value ?? "Hello World!"
            }
            """

        let violations = findings(in: source)
        #expect(violations.contains { $0.contains("[checks.no-suppression]") })
        #expect(violations.contains { $0.contains("[errors.explicit]") })
        #expect(violations.contains { $0.contains("[values.explicit]") })
        #expect(violations.contains { $0.contains("[values.no-fallback]") })
    }

    @Test("accepts the declared source modules and rejects an extra module")
    func validatesSourceModules() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sources = root.appending(path: "Sources", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: sources, withIntermediateDirectories: true, attributes: nil)
        for module in ["App", "AppUI"] {
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
            allowedImports: ["SwiftUI"]
        )
        visitor.walk(tree)
        return visitor.findings
    }
}
