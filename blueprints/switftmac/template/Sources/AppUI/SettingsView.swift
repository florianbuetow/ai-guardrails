import AppApplication
import SwiftUI

public struct SettingsView: View {
    private let model: WorkspaceModel

    public init(model: WorkspaceModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Workspace") {
                LabeledContent("Status") {
                    Text(status)
                        .accessibilityIdentifier("settings-status")
                }
                LabeledContent("Persistence", value: "Application Support")
                Button("Reset Counter") {
                    Task {
                        await model.reset()
                    }
                }
                .disabled(!canReset)
                .accessibilityIdentifier("settings-reset")
            }
            Section("Keyboard shortcuts") {
                LabeledContent("Increment", value: "⌘+")
                LabeledContent("Reset", value: "⇧⌘R")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 260)
        .padding()
        .accessibilityIdentifier("settings-form")
    }

    private var status: String {
        switch model.phase {
        case .loading:
            "Loading"
        case .firstLaunch:
            "First launch"
        case .ready(let workspace):
            "\(workspace.name), count \(workspace.counterValue)"
        case .failed:
            "Needs attention"
        }
    }

    private var canReset: Bool {
        if case .ready(let workspace) = model.phase {
            return workspace.canReset
        }
        return false
    }
}
