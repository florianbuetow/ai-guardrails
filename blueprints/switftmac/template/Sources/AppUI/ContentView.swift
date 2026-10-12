import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        Text("Hello World!")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(minWidth: 360, minHeight: 240)
            .accessibilityIdentifier("greeting")
    }
}
