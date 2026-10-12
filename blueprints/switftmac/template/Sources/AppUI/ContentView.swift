import AppApplication
import SwiftUI

public struct ContentView: View {
    @Bindable private var model: WorkspaceModel

    public init(model: WorkspaceModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView("Loading workspace…")
                    .accessibilityIdentifier("workspace-loading")
            case .firstLaunch:
                FirstLaunchView(model: model)
            case .ready(let workspace):
                WorkspaceView(
                    model: model, name: workspace.name, count: workspace.counterValue,
                    canReset: workspace.canReset)
            case .failed(let message):
                FailureView(model: model, message: message)
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .padding(32)
        .task {
            await model.load()
        }
    }
}

private struct FirstLaunchView: View {
    let model: WorkspaceModel
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create your workspace")
                .font(.largeTitle)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Name the workspace before using the counter. The name and count are saved on this Mac."
            )
            .foregroundStyle(.secondary)
            TextField("Workspace name", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("workspace-name")
            Button("Create Workspace") {
                Task {
                    await model.createWorkspace(named: name)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("create-workspace")
        }
        .frame(maxWidth: 420)
    }
}

private struct WorkspaceView: View {
    let model: WorkspaceModel
    let name: String
    let count: Int
    let canReset: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(name)
                .font(.title)
                .accessibilityAddTraits(.isHeader)
            Text(count, format: .number)
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .accessibilityLabel("Counter value")
                .accessibilityValue(String(count))
                .accessibilityIdentifier("counter-value")
            Button("Increment") {
                Task {
                    await model.increment()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("increment-counter")
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Increment", systemImage: "plus") {
                    Task {
                        await model.increment()
                    }
                }
                .accessibilityIdentifier("toolbar-increment")
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    Task {
                        await model.reset()
                    }
                }
                .disabled(!canReset)
                .accessibilityIdentifier("toolbar-reset")
            }
        }
    }
}

private struct FailureView: View {
    let model: WorkspaceModel
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Workspace unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
                .textSelection(.enabled)
                .accessibilityIdentifier("workspace-error-message")
        } actions: {
            Button("Try Again") {
                Task {
                    await model.retryLoading()
                }
            }
        }
        .accessibilityIdentifier("workspace-error")
    }
}
