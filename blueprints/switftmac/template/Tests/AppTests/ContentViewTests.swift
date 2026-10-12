import AppUI
import Testing
import ViewInspector

@MainActor
@Suite("Hello World view")
struct ContentViewTests {
    @Test("shows the greeting")
    func greeting() throws {
        let view = ContentView()
        _ = try view.inspect().find(text: "Hello World!")
    }
}
