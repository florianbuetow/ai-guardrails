import Foundation

enum PerformanceFailure: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case .invalid(let message): message
        }
    }
}

struct MetricsTest: Decodable {
    let testIdentifier: String
    let testRuns: [MetricsRun]
}

struct MetricsRun: Decodable {
    let testPlanConfiguration: MetricsConfiguration
    let device: MetricsDevice
    let metrics: [MetricsMetric]
}

struct MetricsConfiguration: Decodable, Equatable {
    let configurationId: String
    let configurationName: String
}

struct MetricsDevice: Decodable, Equatable {
    let deviceId: String
    let deviceName: String
}

struct MetricsMetric: Decodable {
    let displayName: String
    let unitOfMeasurement: String
    let measurements: [Double]
    let identifier: String?
}

struct Quality: Decodable {
    let performanceIterations: Int
    let performanceRegressionPercent: Double
}

struct Baseline: Codable {
    let schemaVersion: Int
    let iterations: Int
    let regressionPercent: Double
    let runner: BaselineRunner
    let tests: [BaselineTest]
}

struct BaselineRunner: Codable, Equatable {
    let deviceId: String
    let deviceName: String
    let configurationId: String
    let configurationName: String
}

struct BaselineTest: Codable {
    let testIdentifier: String
    let metrics: [BaselineMetric]
}

struct BaselineMetric: Codable {
    let identifier: String
    let displayName: String
    let unitOfMeasurement: String
    let average: Double
}

func decode<T: Decodable>(_ type: T.Type, from path: String) throws -> T {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(type, from: data)
}

func requireText(_ value: String, _ field: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw PerformanceFailure.invalid("Missing required performance field: \(field)")
    }
}

func average(_ measurements: [Double], iterations: Int, metric: String) throws -> Double {
    guard measurements.count == iterations else {
        throw PerformanceFailure.invalid(
            "Metric \(metric) produced \(measurements.count) measurements; expected \(iterations)")
    }
    guard measurements.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
        throw PerformanceFailure.invalid("Metric \(metric) contains an invalid measurement")
    }
    return measurements.reduce(0, +) / Double(measurements.count)
}

func normalized(_ tests: [MetricsTest], quality: Quality) throws -> Baseline {
    guard quality.performanceIterations > 0 else {
        throw PerformanceFailure.invalid("performanceIterations must be positive")
    }
    guard quality.performanceRegressionPercent > 0,
        quality.performanceRegressionPercent <= 100
    else {
        throw PerformanceFailure.invalid("performanceRegressionPercent must be in (0, 100]")
    }
    guard !tests.isEmpty else {
        throw PerformanceFailure.invalid("Performance metrics report contains no tests")
    }

    var runner: BaselineRunner?
    var identifiers = Set<String>()
    var baselineTests: [BaselineTest] = []
    for test in tests.sorted(by: { $0.testIdentifier < $1.testIdentifier }) {
        try requireText(test.testIdentifier, "testIdentifier")
        guard identifiers.insert(test.testIdentifier).inserted else {
            throw PerformanceFailure.invalid("Duplicate performance test: \(test.testIdentifier)")
        }
        guard test.testRuns.count == 1, let run = test.testRuns.first else {
            throw PerformanceFailure.invalid(
                "Performance test \(test.testIdentifier) must have exactly one runner-bound run")
        }
        let currentRunner = BaselineRunner(
            deviceId: run.device.deviceId,
            deviceName: run.device.deviceName,
            configurationId: run.testPlanConfiguration.configurationId,
            configurationName: run.testPlanConfiguration.configurationName
        )
        for (value, field) in [
            (currentRunner.deviceId, "deviceId"),
            (currentRunner.deviceName, "deviceName"),
            (currentRunner.configurationId, "configurationId"),
            (currentRunner.configurationName, "configurationName"),
        ] {
            try requireText(value, field)
        }
        if let runner, runner != currentRunner {
            throw PerformanceFailure.invalid("Performance metrics contain multiple runners")
        }
        runner = currentRunner
        guard !run.metrics.isEmpty else {
            throw PerformanceFailure.invalid(
                "Performance test \(test.testIdentifier) has no metrics")
        }

        var metricIdentifiers = Set<String>()
        var metrics: [BaselineMetric] = []
        for metric in run.metrics {
            guard let identifier = metric.identifier else {
                throw PerformanceFailure.invalid("Performance metric is missing its identifier")
            }
            try requireText(identifier, "metric.identifier")
            try requireText(metric.displayName, "metric.displayName")
            try requireText(metric.unitOfMeasurement, "metric.unitOfMeasurement")
            guard metricIdentifiers.insert(identifier).inserted else {
                throw PerformanceFailure.invalid("Duplicate metric identifier: \(identifier)")
            }
            metrics.append(
                BaselineMetric(
                    identifier: identifier,
                    displayName: metric.displayName,
                    unitOfMeasurement: metric.unitOfMeasurement,
                    average: try average(
                        metric.measurements,
                        iterations: quality.performanceIterations,
                        metric: identifier
                    )
                ))
        }
        baselineTests.append(
            BaselineTest(
                testIdentifier: test.testIdentifier,
                metrics: metrics.sorted(by: { $0.identifier < $1.identifier })
            ))
    }
    guard let runner else {
        throw PerformanceFailure.invalid("Performance report has no runner")
    }
    return Baseline(
        schemaVersion: 1,
        iterations: quality.performanceIterations,
        regressionPercent: quality.performanceRegressionPercent,
        runner: runner,
        tests: baselineTests
    )
}

func calibrate(metricsPath: String, baselinePath: String, quality: Quality) throws {
    let metrics = try decode([MetricsTest].self, from: metricsPath)
    let baseline = try normalized(metrics, quality: quality)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(baseline)
    data.append(0x0A)
    try data.write(to: URL(fileURLWithPath: baselinePath), options: .atomic)
    print("Wrote runner-bound performance baseline: \(baselinePath)")
}

func verify(metricsPath: String, baselinePath: String, quality: Quality) throws {
    let expected = try decode(Baseline.self, from: baselinePath)
    guard expected.schemaVersion == 1 else {
        throw PerformanceFailure.invalid("Unsupported performance baseline schema")
    }
    guard expected.iterations == quality.performanceIterations,
        expected.regressionPercent == quality.performanceRegressionPercent
    else {
        throw PerformanceFailure.invalid(
            "Performance policy changed; review a new baseline explicitly")
    }
    let actual = try normalized(
        decode([MetricsTest].self, from: metricsPath),
        quality: quality
    )
    guard actual.runner == expected.runner else {
        throw PerformanceFailure.invalid("Performance baseline belongs to a different runner")
    }
    guard actual.tests.count == expected.tests.count else {
        throw PerformanceFailure.invalid("Performance test set changed; review a new baseline")
    }

    for expectedTest in expected.tests {
        guard
            let actualTest = actual.tests.first(where: {
                $0.testIdentifier == expectedTest.testIdentifier
            })
        else {
            throw PerformanceFailure.invalid(
                "Missing performance test: \(expectedTest.testIdentifier)")
        }
        guard actualTest.metrics.count == expectedTest.metrics.count else {
            throw PerformanceFailure.invalid(
                "Performance metric set changed for \(expectedTest.testIdentifier)")
        }
        for expectedMetric in expectedTest.metrics {
            guard
                let actualMetric = actualTest.metrics.first(where: {
                    $0.identifier == expectedMetric.identifier
                })
            else {
                throw PerformanceFailure.invalid("Missing metric: \(expectedMetric.identifier)")
            }
            guard actualMetric.displayName == expectedMetric.displayName,
                actualMetric.unitOfMeasurement == expectedMetric.unitOfMeasurement
            else {
                throw PerformanceFailure.invalid(
                    "Metric identity changed: \(expectedMetric.identifier)")
            }
            let maximum = expectedMetric.average * (1 + expected.regressionPercent / 100)
            guard actualMetric.average <= maximum else {
                throw PerformanceFailure.invalid(
                    "\(expectedMetric.displayName) regressed: \(actualMetric.average) "
                        + "> allowed \(maximum) \(actualMetric.unitOfMeasurement)")
            }
        }
    }
    print("Performance metrics passed the runner-bound baseline")
}

do {
    guard CommandLine.arguments.count == 4 else {
        throw PerformanceFailure.invalid(
            "Usage: performance.swift calibrate|verify metrics.json baseline.json")
    }
    let quality = try decode(Quality.self, from: "config/quality.json")
    switch CommandLine.arguments[1] {
    case "calibrate":
        try calibrate(
            metricsPath: CommandLine.arguments[2],
            baselinePath: CommandLine.arguments[3],
            quality: quality
        )
    case "verify":
        try verify(
            metricsPath: CommandLine.arguments[2],
            baselinePath: CommandLine.arguments[3],
            quality: quality
        )
    default:
        throw PerformanceFailure.invalid("Unknown performance verification command")
    }
} catch {
    FileHandle.standardError.write(Data("Performance verification failed: \(error)\n".utf8))
    exit(1)
}
