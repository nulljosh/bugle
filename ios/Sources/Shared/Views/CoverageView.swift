import SwiftUI

/// Every outlet's take on one story, Ground News style: who covered it, how the coverage leans, a blindspot note when
/// only one side did, the headlines side by side by lean, and the days before. Opened from the reader's Sources button.
struct CoverageView: View {
    let story: Story
    @ObservedObject var library: Library
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(Headline.clean(story.lead.title, source: story.lead.sourceTitle)).font(.headline)
                    LeanBar(counts: story.counts)
                    if let side = story.blindspot {
                        Label("Blindspot: only \(side == .center ? "center" : side.title.lowercased() + "-leaning") outlets covered this.", systemImage: "eye.slash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Covered by \(story.publishers) newsrooms. Leans are Bugle's own rating of each outlet.")
                }
                ForEach(Side.allCases, id: \.self) { side in
                    let rows = story.entries.filter { e in Outlet.of(e.sourceTitle)?.lean.map { Side(lean: $0) == side } ?? false }
                    if !rows.isEmpty { Section(side.title) { ForEach(rows) { CoverageRow(entry: $0) } } }
                }
                let unrated = story.entries.filter { Outlet.of($0.sourceTitle)?.lean == nil }
                if !unrated.isEmpty { Section("Not rated") { ForEach(unrated) { CoverageRow(entry: $0) } } }
                // The days before: the same story as the feeds carried it earlier in the week (Archive).
                let earlier = Archive.earlier(story)
                if !earlier.isEmpty {
                    Section("Earlier") {
                        ForEach(earlier) { e in
                            NavigationLink(value: e) {
                                VStack(alignment: .leading, spacing: 2) {
                                    (Text(e.sourceTitle).foregroundColor(Outlet.color(e.sourceTitle))
                                        + Text(" · " + e.date.formatted(.dateTime.weekday(.wide).month().day())).foregroundColor(.secondary))
                                        .font(.caption)
                                    Text(Headline.clean(e.title, source: e.sourceTitle)).font(.body)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Coverage")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: JournalEntry.self) { EntryDetailView(entry: $0, library: library) }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }
}

private struct CoverageRow: View {
    let entry: JournalEntry

    var body: some View {
        NavigationLink(value: entry) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(entry.sourceTitle).fontWeight(.semibold).foregroundStyle(Outlet.color(entry.sourceTitle))
                    if let lean = Outlet.of(entry.sourceTitle)?.lean { Text("· " + Outlet.leanLabel(lean)).foregroundStyle(.secondary) }
                    let ago = RelativeTime.short(entry.date)
                    if !ago.isEmpty { Text("· " + ago).foregroundStyle(.secondary) }   // undated entries show no time
                }
                .font(.caption)
                Text(Headline.clean(entry.title, source: entry.sourceTitle)).font(.body)
            }
            .padding(.vertical, 2)
        }
    }
}

/// Left, center and right as one bar, each part as wide as its share, with the counts under it.
struct LeanBar: View {
    let counts: [Side: Int]
    static let colors: [Side: Color] = [.left: Color(red: 0.0, green: 0.455, blue: 0.851), .center: Color.secondary.opacity(0.5), .right: Color(red: 0.843, green: 0.0, blue: 0.082)]

    var body: some View {
        let total = max(1, counts.values.reduce(0, +))
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Side.allCases, id: \.self) { side in
                        let n = counts[side, default: 0]
                        if n > 0 { Self.colors[side]!.frame(width: max(6, geo.size.width * CGFloat(n) / CGFloat(total) - 2)) }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            .opacity(counts.isEmpty ? 0.3 : 1)
            HStack {
                ForEach(Side.allCases, id: \.self) { side in
                    Text("\(side.title) \(counts[side, default: 0])").font(.caption).foregroundStyle(.secondary)
                    if side != .right { Spacer() }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
