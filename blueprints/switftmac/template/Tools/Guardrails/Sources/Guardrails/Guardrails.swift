import Foundation
import SwiftParser
import SwiftSyntax

enum PolicyFailure: Error {
    case invalidArguments
    case missingSource(String)
    case unreadableDirectory(String)
    case violations(Int)
}

final class PolicyVisitor: SyntaxVisitor {
    private static let effectTypes: Set<String> = [
        "DispatchIO", "FileHandle", "FileManager", "InputStream", "NSFileHandle", "NSFileManager",
        "NSInputStream", "NSOutputStream", "OutputStream", "Process", "ProcessInfo", "URLSession",
        "UserDefaults",
    ]
    private static let fileContentTypes: Set<String> = ["Data", "NSData", "NSString", "String"]

    let path: String
    let locations: SourceLocationConverter
    let allowedImports: Set<String>
    let isCore: Bool
    var findings: [String] = []

    init(path: String, tree: SourceFileSyntax, allowedImports: Set<String>, isCore: Bool) {
        self.path = path
        locations = SourceLocationConverter(fileName: path, tree: tree)
        self.allowedImports = allowedImports
        self.isCore = isCore
        super.init(viewMode: .sourceAccurate)
    }

    func report(_ node: some SyntaxProtocol, _ rule: String, _ message: String) {
        let position = locations.location(for: node.positionAfterSkippingLeadingTrivia)
        findings.append("\(path):\(position.line):\(position.column): error: [\(rule)] \(message)")
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let module = node.path.first?.name.text, !allowedImports.contains(module) {
            report(
                node, "architecture.import", "Import of \(module) violates this module's boundary")
        }
        return .visitChildren
    }

    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark != nil {
            report(
                node, "errors.explicit", "Propagate or handle errors; do not discard or force them")
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard isCore else { return .visitChildren }
        let labels = Set(node.arguments.compactMap { $0.label?.text })
        guard !labels.isDisjoint(with: ["contentsOf", "contentsOfFile"]) else {
            return .visitChildren
        }
        let called = node.calledExpression.trimmedDescription
        let calledType = called.split(separator: ".").last.map(String.init)
        if called == ".init" || called.hasSuffix(".init")
            || calledType.map(Self.fileContentTypes.contains) == true
        {
            report(
                node, "architecture.effects",
                "Move Foundation file reads behind an interface implemented by AppInfrastructure")
        }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isCore else { return .visitChildren }
        let target = node.initializer.value.trimmedDescription
        let targetType = target.split(separator: ".").last.map(String.init)
        if targetType.map(Self.effectTypes.contains) == true {
            report(
                node, "architecture.effects",
                "A type alias cannot hide an effectful Foundation type in a core module")
        }
        return .visitChildren
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        if node.body.statements.isEmpty {
            report(node, "errors.empty-catch", "Handle the failure or rethrow it")
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        if node.defaultValue != nil {
            report(node, "values.explicit", "Pass function arguments explicitly")
        }
        return .visitChildren
    }

    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if node.operator.text == "??" {
            report(node, "values.no-fallback", "Handle missing values explicitly")
        }
        return .visitChildren
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.attributeName.trimmedDescription
        if name == "preconcurrency" {
            report(node, "checks.no-bypass", "Do not bypass concurrency diagnostics")
        }
        if name == "Test", let arguments = node.arguments {
            let spelling = arguments.trimmedDescription
            if spelling.contains(".disabled") || spelling.contains(".enabled(if:") {
                report(node, "tests.no-skip", "Required tests must always execute")
            }
        }
        return .visitChildren
    }

    override func visit(_ node: DeclModifierSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == "nonisolated", node.detail?.detail.text == "unsafe" {
            report(node, "checks.no-bypass", "Do not bypass actor isolation")
        }
        return .visitChildren
    }

    override func visit(_ node: AttributedTypeSyntax) -> SyntaxVisitorContinueKind {
        if node.trimmedDescription.contains("@unchecked") {
            report(node, "checks.no-bypass", "Use checked Sendable conformance")
        }
        return .visitChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if ["XCTSkip", "XCTSkipIf", "XCTSkipUnless", "withKnownIssue"].contains(name) {
            report(node, "tests.no-skip", "Do not skip or conceal test failures")
        }
        if isCore && Self.effectTypes.contains(name) {
            report(
                node, "architecture.effects",
                "Inject an interface; move \(name) into Infrastructure")
        }
        return .visitChildren
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        for trivia in [token.leadingTrivia, token.trailingTrivia] {
            for piece in trivia {
                switch piece {
                case .lineComment(let value), .blockComment(let value),
                    .docLineComment(let value), .docBlockComment(let value):
                    if [
                        "swiftlint:disable", "swift-format-ignore", "nosemgrep", "periphery:ignore",
                    ].contains(where: value.contains) {
                        report(
                            token, "checks.no-suppression",
                            "Fix the issue instead of suppressing the checker")
                    }
                default:
                    break
                }
            }
        }
        return .visitChildren
    }
}

@main
struct Guardrails {
    private static let sourceModules: Set<String> = [
        "App", "AppApplication", "AppDomain", "AppInfrastructure", "AppUI",
    ]

    static func swiftFiles(in folder: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        let entries = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: Array(keys)
        )
        var files: [URL] = []
        for entry in entries {
            let values = try entry.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true else {
                throw PolicyFailure.unreadableDirectory(entry.path)
            }
            if values.isDirectory == true {
                files += try swiftFiles(in: entry)
            } else if values.isRegularFile == true, entry.pathExtension == "swift" {
                files.append(entry)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("Guardrails failed: \(error)\n".utf8))
            exit(1)
        }
    }

    static func sourceLayoutFindings(root: URL) throws -> [String] {
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        let entries = try FileManager.default.contentsOfDirectory(
            at: sources, includingPropertiesForKeys: Array(keys)
        )
        var findings: [String] = []
        for entry in entries.sorted(by: { $0.path < $1.path }) {
            let values = try entry.resourceValues(forKeys: keys)
            if values.isSymbolicLink == true {
                findings.append(
                    "\(entry.path):1:1: error: [architecture.modules] Symlinks are forbidden under Sources"
                )
            } else if values.isDirectory == true, !sourceModules.contains(entry.lastPathComponent) {
                findings.append(
                    "\(entry.path):1:1: error: [architecture.modules] Unexpected source module: \(entry.lastPathComponent)"
                )
            } else if values.isRegularFile == true, entry.pathExtension == "swift" {
                findings.append(
                    "\(entry.path):1:1: error: [architecture.modules] Swift files must belong to a declared source module"
                )
            }
        }
        return findings
    }

    static func run() throws {
        guard CommandLine.arguments.count == 2 else { throw PolicyFailure.invalidArguments }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let modules: [(String, Set<String>, Bool)] = [
            ("Sources/AppDomain", ["Swift", "Foundation"], true),
            ("Sources/AppApplication", ["Swift", "Foundation", "Observation", "AppDomain"], true),
            (
                "Sources/AppInfrastructure",
                ["Swift", "Foundation", "AppDomain", "AppApplication"], false
            ),
            (
                "Sources/AppUI",
                ["Swift", "Foundation", "SwiftUI", "AppKit", "Observation", "AppApplication"], false
            ),
            (
                "Sources/App",
                [
                    "Swift", "Foundation", "SwiftUI", "AppKit", "AppUI", "AppApplication",
                    "AppInfrastructure", "AppDomain",
                ], false
            ),
            (
                "Tests",
                [
                    "Swift", "Foundation", "SwiftUI", "AppKit", "Testing", "XCTest",
                    "PropertyBased", "SnapshotTesting", "ViewInspector", "AppUI", "AppDomain",
                    "AppApplication", "AppInfrastructure",
                ], false
            ),
            ("UITests", ["Swift", "Foundation", "XCTest", "XCUIAutomation"], false),
        ]
        let layoutFindings = try sourceLayoutFindings(root: root)
        for finding in layoutFindings { print(finding) }
        var count = layoutFindings.count
        for (directory, imports, isCore) in modules {
            let folder = root.appendingPathComponent(directory)
            guard FileManager.default.fileExists(atPath: folder.path) else {
                throw PolicyFailure.missingSource(directory)
            }
            let files = try swiftFiles(in: folder)
            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                let tree = Parser.parse(source: source)
                guard !tree.hasError else { throw PolicyFailure.unreadableDirectory(file.path) }
                let visitor = PolicyVisitor(
                    path: file.path, tree: tree, allowedImports: imports, isCore: isCore)
                visitor.walk(tree)
                for finding in visitor.findings { print(finding) }
                count += visitor.findings.count
            }
            guard !files.isEmpty else { throw PolicyFailure.missingSource(directory) }
        }
        guard count == 0 else { throw PolicyFailure.violations(count) }
        print("Swift policy and import boundaries passed")
    }
}
