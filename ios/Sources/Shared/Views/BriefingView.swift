import SwiftUI

/// The Briefing: today's five biggest stories, numbered, each with its first line, and how long they take to read. Listen
/// reads it top to bottom. Ground News calls theirs The Last 24, Apple has News Today. Same picks as briefing in
/// web/briefing.js.
struct BriefingView: View {
    let stories: [Story]
    let open: (JournalEntry) -> Void
    @StateObject private var listener = Listener()
    @Environment(\.dismiss) private var dismiss

    /// The first sentence of a story's text, or nothing when the feed sent none. A sentence ends at . ! or ? after a
    /// lowercase letter or digit, before a space or the end, so "B.C." and "U.S." do not cut it short.
    static func firstLine(_ e: JournalEntry) -> String {
        let text = e.plainText.hasPrefix("Photograph:") ? "" : e.plainText   // the Guardian sends only a photo credit
        let end = text.firstMatch(of: /[a-z0-9)\u{201D}\u{2019}][.!?](?=\s|$)/).map { $0.range.upperBound } ?? text.endIndex
        let line = String(text[..<end]).trimmingCharacters(in: .whitespaces)
        return line.count > 160 ? String(line.prefix(157)) + "\u{2026}" : line
    }

    /// Minutes to read the five, at least one.
    static func minutes(_ stories: [Story]) -> Int {
        max(1, Int((Double(stories.map { $0.lead.plainText.split(separator: " ").count }.reduce(0, +)) / 230).rounded(.up)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(stories.enumerated()), id: \.element.id) { i, s in
                        Button { dismiss(); open(s.lead) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(i + 1)").font(.title2.weight(.bold)).foregroundStyle(Color.bugleAccent).frame(minWidth: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Kicker(entry: s.lead, saved: false, sources: s.publishers)
                                    Text(Headline.clean(s.lead.title, source: s.lead.sourceTitle)).font(.headline)
                                    let line = Self.firstLine(s.lead)
                                    if !line.isEmpty { Text(line).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(stories.count) stories \u{00B7} \(Self.minutes(stories)) min")
                }
            }
            .navigationTitle("Briefing")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { listener.toggle(text: script) } label: {
                        Label(listener.speaking ? "Stop" : "Listen", systemImage: listener.speaking ? "stop.fill" : "speaker.wave.2")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onDisappear { listener.stop() }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    /// What Listen reads: each story's number, outlet, headline and first line.
    private var script: String {
        stories.enumerated().map { i, s in
            "\(i + 1). \(s.lead.sourceTitle). \(Headline.clean(s.lead.title, source: s.lead.sourceTitle)). \(Self.firstLine(s.lead))"
        }.joined(separator: "\n")
    }
}

#if DEBUG
func briefingDemo() {
    let e = JournalEntry(title: "t", url: "u", date: .now, htmlContent: "<p>The vote passed late on Sunday. Both sides claimed a win.</p>")
    assert(BriefingView.firstLine(e) == "The vote passed late on Sunday.", "briefing first line")
    let bc = JournalEntry(title: "t", url: "u", date: .now, htmlContent: "<p>The U.S. and B.C. agreed on Saturday. More soon.</p>")
    assert(BriefingView.firstLine(bc) == "The U.S. and B.C. agreed on Saturday.", "abbreviations do not end a sentence")
    assert(BriefingView.minutes([Story(lead: e, entries: [e])]) == 1, "briefing minutes")
}
#endif
