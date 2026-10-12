import AppUI
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class SnapshotTests: XCTestCase {
    func testHelloWorld() {
        let view = ContentView()
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .frame(width: 480, height: 320)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.nsImage else {
            XCTFail("Unable to render the Hello World view")
            return
        }
        let platform = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        assertSnapshot(of: image, as: .image, named: "hello-world-macos-\(platform)")
    }
}
