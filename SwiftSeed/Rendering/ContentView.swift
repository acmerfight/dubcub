import SwiftUI

public struct ContentView: View {
    private let state: HomeViewState

    public init(state: HomeViewState) {
        self.state = state
    }

    public var body: some View {
        GeometryReader { viewport in
            ScrollView {
                welcome
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: viewport.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var welcome: some View {
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
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(32)
        .frame(maxWidth: 560)
    }
}

#Preview {
    ContentView(state: .initial)
}

#Preview("Narrow window and largest text", traits: .fixedLayout(width: 320, height: 320)) {
    ContentView(state: .initial)
        .dynamicTypeSize(.accessibility5)
}
