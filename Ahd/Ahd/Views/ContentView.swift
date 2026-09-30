import SwiftUI

/// Routing: setup first; an unpaid debt blocks everything; then unanswered days; then home.
struct ContentView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.scenePhase) private var scenePhase
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !store.isSetUp {
                SetupView()
            } else if store.totalOwed > 0 {
                PayView()
            } else if let day = store.pendingDay {
                CheckInView(day: day).id(day)
            } else {
                HomeView()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
        .onReceive(ticker) { _ in store.refresh() }
    }
}

/// Shared look for the cards on every screen.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.07)))
    }
}

/// A text box for the typed sentence, with a live ✓ when it matches.
struct SentenceField: View {
    let sentence: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("اكتب بإيدك: «\(sentence)»")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                TextField(sentence, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                if Store.matches(text, sentence) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
    }
}
