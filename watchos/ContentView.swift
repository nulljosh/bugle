import SwiftUI

/// The phone's Home on the wrist: the same feeds, grouped into stories, Today's biggest first, each outlet in its
/// color. A story opens as plain text (watchOS has no WebKit) with Save, which keeps it like the phone does.
struct ContentView: View {
    @StateObject private var feed = JournalFeedService()
    @StateObject private var store = FeedStore()
    @StateObject private var library = Library()

    var body: some View {
        NavigationStack {
            List(Coverage.today(feed.stories)) { story in
                NavigationLink(value: story.lead) { StoryRow(story: story, read: library.isRead(story.lead)) }
            }
            .overlay {
                if feed.entries.isEmpty { feed.isLoading ? AnyView(ProgressView()) : AnyView(Text("Pull to refresh").foregroundStyle(.secondary)) }
            }
            .navigationTitle("Bugle")
            .navigationDestination(for: JournalEntry.self) { StoryView(entry: $0, library: library) }
            .task(id: store.feeds) { await feed.refresh(feeds: store.feeds) }
            .refreshable { await feed.refresh(feeds: store.feeds) }
        }
        .tint(.bugleAccent)
    }
}

struct StoryRow: View {
    let story: Story
    let read: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Kicker(entry: story.lead, sources: story.publishers)
            Text(Headline.clean(story.lead.title, source: story.lead.sourceTitle))
                .font(.headline).lineLimit(3)
                .foregroundStyle(read ? .secondary : .primary)
        }
    }
}

/// "BBC · 2h ago · 4 sources", the outlet in its color, like the phone's rows.
struct Kicker: View {
    let entry: JournalEntry
    var sources = 1

    var body: some View {
        let rest = [RelativeTime.short(entry.date), sources > 1 ? "\(sources) sources" : ""].filter { !$0.isEmpty }
        (Text(entry.sourceTitle).foregroundColor(Outlet.color(entry.sourceTitle))
            + Text(rest.map { " · " + $0 }.joined()).foregroundColor(.secondary))
            .font(.caption2).lineLimit(1)
    }
}

struct StoryView: View {
    let entry: JournalEntry
    @ObservedObject var library: Library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(Headline.clean(entry.title, source: entry.sourceTitle)).font(.headline)
                Kicker(entry: entry)
                Button(library.isSaved(entry) ? "Saved" : "Save") { library.toggleSave(entry) }
                Text(entry.plainText.isEmpty ? "Open it on your phone to read the rest." : entry.plainText).font(.footnote)
            }
        }
        .onAppear { library.markRead(entry) }
    }
}

extension JournalEntry {
    /// The body as plain text: tags out, the common entities decoded, whitespace collapsed.
    var plainText: String {
        htmlContent.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&nbsp;", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
