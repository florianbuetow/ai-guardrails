import Foundation

enum VerificationError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case .invalid(let message): return message
        }
    }
}

func object(_ path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw VerificationError.invalid("Expected JSON object: \(path)")
    }
    return value
}

func require<T>(_ dictionary: [String: Any], _ key: String, as type: T.Type) throws -> T {
    guard let value = dictionary[key] as? T else {
        throw VerificationError.invalid("Missing or invalid required field: \(key)")
    }
    return value
}

func verifyTests(_ path: String) throws {
    let result = try object(path)
    let total = try require(result, "totalTestCount", as: Int.self)
    let passed = try require(result, "passedTests", as: Int.self)
    let failed = try require(result, "failedTests", as: Int.self)
    let skipped = try require(result, "skippedTests", as: Int.self)
    let expected = try require(result, "expectedFailures", as: Int.self)
    let status = try require(result, "result", as: String.self)
    guard total > 0, passed == total, failed == 0, skipped == 0, expected == 0, status == "Passed"
    else {
        throw VerificationError.invalid(
            "Tests must execute and pass without skips or expected failures: \(path)")
    }
    print("Verified \(passed) executed tests")
}

func verifyCoverage(_ path: String) throws {
    let config = try object("config/quality.json")
    let threshold = try require(config, "coveragePercent", as: Double.self)
    guard threshold > 0, threshold <= 100 else {
        throw VerificationError.invalid("Invalid coverage threshold")
    }
    let expected = try require(config, "coverageTargets", as: [String].self)
    guard !expected.isEmpty else {
        throw VerificationError.invalid("Coverage target list is empty")
    }
    let report = try object(path)
    let targets = try require(report, "targets", as: [[String: Any]].self)
    for name in expected {
        let matches = try targets.filter { try require($0, "name", as: String.self) == name }
        guard matches.count == 1, let target = matches.first else {
            throw VerificationError.invalid("Missing or duplicate coverage target: \(name)")
        }
        let lines = try require(target, "executableLines", as: Int.self)
        let covered = try require(target, "coveredLines", as: Int.self)
        guard lines > 0, covered >= 0, covered <= lines else {
            throw VerificationError.invalid("Invalid coverage counts for \(name)")
        }
        let percent = Double(covered) / Double(lines) * 100
        guard percent >= threshold else {
            throw VerificationError.invalid("\(name) coverage \(percent)% is below \(threshold)%")
        }
        print("\(name): \(percent)% line coverage")
    }
}

func verifyGraph(_ path: String) throws {
    let spec = try object(path)
    let settings = try require(spec, "settings", as: [String: Any].self)
    let base = try require(settings, "base", as: [String: Any].self)
    guard try require(base, "SWIFT_VERSION", as: String.self) == "6.0",
        try require(base, "SWIFT_STRICT_CONCURRENCY", as: String.self) == "complete",
        try require(base, "SWIFT_TREAT_WARNINGS_AS_ERRORS", as: Bool.self),
        try require(base, "MACOSX_DEPLOYMENT_TARGET", as: String.self) == "26.0"
    else { throw VerificationError.invalid("Required Swift compiler checks were changed") }
    let flags = try require(base, "OTHER_SWIFT_FLAGS", as: [String].self)
    guard flags.contains("-strict-memory-safety") else {
        throw VerificationError.invalid("Strict memory safety must be enabled")
    }
    let targets = try require(spec, "targets", as: [String: [String: Any]].self)
    let allowed: [String: Set<String>] = [
        "AppUI": [],
        "App": ["AppUI"],
    ]
    let expectedTargets = Set(allowed.keys).union(["AppTests", "AppUITests", "PerformanceTests"])
    guard Set(targets.keys) == expectedTargets else {
        throw VerificationError.invalid("Unexpected or missing targets in the guarded architecture")
    }
    for (name, permitted) in allowed {
        guard let target = targets[name] else {
            throw VerificationError.invalid("Missing target \(name)")
        }
        // XcodeGen's canonical dump includes the complete dependencies collection.
        let dependencies: [[String: Any]]
        if target["dependencies"] == nil, permitted.isEmpty {
            dependencies = []
        } else {
            dependencies = try require(target, "dependencies", as: [[String: Any]].self)
        }
        var referenced = Set<String>()
        for dependency in dependencies {
            let fields: Set<String> = ["target", "embed", "link", "codeSign", "implicit"]
            guard Set(dependency.keys).isSubset(of: fields),
                let other = dependency["target"] as? String,
                permitted.contains(other), referenced.insert(other).inserted
            else {
                throw VerificationError.invalid("Forbidden or malformed dependency of \(name)")
            }
        }
    }
    print("Declared application dependency graph passed")
}

func verifyScanner(_ path: String) throws {
    let report = try object(path)
    let paths = try require(report, "paths", as: [String: Any].self)
    let scanned = try require(paths, "scanned", as: [String].self)
    let errors = try require(report, "errors", as: [Any].self)
    let results = try require(report, "results", as: [Any].self)
    guard !scanned.isEmpty, errors.isEmpty, results.isEmpty else {
        throw VerificationError.invalid(
            "Scanner must inspect files and report no errors or findings")
    }
    print("Verified scan of \(scanned.count) files")
}

func verifyBundle(_ path: String) throws {
    let info = try object(path)
    if let policy = info["NSAppTransportSecurity"] {
        guard let dictionary = policy as? [String: Any] else {
            throw VerificationError.invalid("Malformed transport security policy")
        }
        for key in [
            "NSAllowsArbitraryLoads", "NSAllowsArbitraryLoadsInWebContent",
            "NSAllowsArbitraryLoadsForMedia",
        ] {
            if let value = dictionary[key] {
                guard let enabled = value as? Bool, !enabled else {
                    throw VerificationError.invalid("Unsafe transport policy: \(key)")
                }
            }
        }
        if dictionary["NSExceptionDomains"] != nil {
            throw VerificationError.invalid("Transport exception domains are forbidden")
        }
    }
    print("Application transport security policy passed")
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw VerificationError.invalid(
            "Usage: verify.swift tests|coverage|graph|bundle|scanner report.json")
    }
    switch CommandLine.arguments[1] {
    case "tests": try verifyTests(CommandLine.arguments[2])
    case "coverage": try verifyCoverage(CommandLine.arguments[2])
    case "graph": try verifyGraph(CommandLine.arguments[2])
    case "bundle": try verifyBundle(CommandLine.arguments[2])
    case "scanner": try verifyScanner(CommandLine.arguments[2])
    default: throw VerificationError.invalid("Unknown verification command")
    }
} catch {
    FileHandle.standardError.write(Data("Verification failed: \(error)\n".utf8))
    exit(1)
}
