import SwiftUI

/// First run: pick a few topics to follow, like Yahoo News and SmartNews. Each becomes a chip on Home that shows only
/// stories with that word. Words that turn up in headlines, not sections. Same list as web/picker.js.
struct TopicPicker: View {
    @Binding var topics: String
    let done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var still
    /// When the last chip was picked: the mascot toots for it.
    @State private var tooted = Date.distantPast
    static let words = ["AI", "Climate", "Economy", "Election", "Housing", "Markets", "Oil", "Space", "Health",
                        "Canada", "Vancouver", "China", "Ukraine", "Apple", "Tesla", "Crypto"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // the mascot bobs while you choose and sounds its horn for every pick
                    TimelineView(.animation(paused: still)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate, since = tl.date.timeIntervalSince(tooted)
                        Mascot(blink: Splash.pulse(t.truncatingRemainder(dividingBy: 4), at: 3.6, for: 0.16),
                               toot: Splash.pulse(since, at: 0, for: 0.3), waves: since < 0.6 ? min(3, since / 0.08) : 0)
                            .frame(width: 96, height: 96)
                            .offset(y: still ? 0 : sin(t * 2.2) * 3)
                    }
                    .frame(maxWidth: .infinity)
                    Text("Pick a few. Each one becomes a chip on Home, and you can change them any time.")
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(Self.words, id: \.self) { w in
                            let on = Topics.has(w, in: topics)
                            Button(w) { topics = Topics.toggled(w, in: topics); tooted = .now }
                                .buttonStyle(Chip(on: on)).frame(maxWidth: .infinity)
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("What do you follow?")
            .safeAreaInset(edge: .bottom) {
                Button { done() } label: { Text("Continue").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { done() } } }
        }
    }
}
