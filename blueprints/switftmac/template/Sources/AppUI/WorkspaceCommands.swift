import AppApplication
import SwiftUI

public struct WorkspaceCommands: Commands {
    private let model: WorkspaceModel

    public init(model: WorkspaceModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandMenu("Workspace") {
            Button("Increment Counter") {
                Task {
                    await model.increment()
                }
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(!isReady)

            Button("Reset Counter") {
                Task {
                    await model.reset()
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!canReset)
        }
    }

    private var isReady: Bool {
        if case .ready = model.phase {
            return true
        }
        return false
    }

    private var canReset: Bool {
        if case .ready(let workspace) = model.phase {
            return workspace.canReset
        }
        return false
    }
}
