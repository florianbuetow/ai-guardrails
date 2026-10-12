import XCTest

@MainActor
final class LaunchMetricDiagnostics: XCTestCase {
    func testResponsiveFreshInstance() {
        let path = storagePath()
        measure(
            metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options()
        ) {
            application(storageFile: path).launch()
        }
    }

    func testFirstFrameFreshInstance() {
        let path = storagePath()
        measure(metrics: [XCTApplicationLaunchMetric()], options: options()) {
            application(storageFile: path).launch()
        }
    }

    func testClockUntilWorkspaceReady() {
        continueAfterFailure = false
        let app = application(storageFile: storagePath())
        defer { app.terminate() }
        let measurementOptions = options()
        measurementOptions.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTClockMetric()], options: measurementOptions) {
            app.terminate()
            startMeasuring()
            app.launch()
            XCTAssertTrue(app.textFields["workspace-name"].waitForExistence(timeout: 5))
            stopMeasuring()
        }
    }

    private func application(storageFile: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment = ["UI_TEST_STORAGE_FILE": storageFile]
        return app
    }

    private func options() -> XCTMeasureOptions {
        let value = XCTMeasureOptions()
        value.iterationCount = 10
        return value
    }

    private func storagePath() -> String {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "launch-metric-diagnostic-\(UUID().uuidString).json")
            .path
        addTeardownBlock {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
        return path
    }
}
