import AppApplication
import AppKit
import SwiftUI

public struct WorkspaceMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    private let model: WorkspaceModel

    public init(model: WorkspaceModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            switch model.phase {
            case .loading:
                Text("Loading workspace…")
            case .firstLaunch:
                Text("Create a workspace to begin")
            case .ready(let workspace):
                Text("\(workspace.name): \(workspace.counterValue)")
                Button("Increment") {
                    Task {
                        await model.increment()
                    }
                }
                .accessibilityIdentifier("menu-increment")
            case .failed(let message):
                Text(message)
            }
            Divider()
            Button("Open Window") {
                openWindow(id: "main")
            }
            .accessibilityIdentifier("menu-open-window")
            Button("Settings…") {
                openSettings()
            }
            .accessibilityIdentifier("menu-open-settings")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

public struct MenuBarLabel: View {
    private let model: WorkspaceModel

    public init(model: WorkspaceModel) {
        self.model = model
    }

    public var body: some View {
        Label(label, systemImage: "square.stack.3d.up")
            .accessibilityIdentifier("menu-bar-workspace")
            .accessibilityLabel(label)
    }

    private var label: String {
        if case .ready(let workspace) = model.phase {
            return "Workspace count \(workspace.counterValue)"
        }
        return "Workspace"
    }
}
