import SwiftUI

public struct ContentView: View {
    private let state: HomeViewState

    public init(state: HomeViewState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.indigo)
                .accessibilityHidden(true)
            Text(state.title)
                .font(.largeTitle.bold())
            Text(state.subtitle)
                .font(.title3)
            Text(state.message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView(state: .initial)
}
