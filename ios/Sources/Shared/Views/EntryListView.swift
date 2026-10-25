import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct EntryListView: View {
    @StateObject private var feed: JournalFeedService
    @StateObject private var store: FeedStore
    @StateObject private var account = Account()
    @StateObject private var library = Library()
    @State private var path: [JournalEntry] = []
    @State private var query = UserDefaults.standard.string(forKey: "search") ?? ""   // `-search BBC` for screenshots

    /// Both default to the real thing; the parameters exist so the macOS screenshot capture can
    /// hand in a pre-loaded service and a trimmed feed list without writing to the user's saved
    /// subscriptions. No caller in the app passes either.
    init(feed: JournalFeedService? = nil, store: FeedStore? = nil) {
        _feed = StateObject(wrappedValue: feed ?? JournalFeedService())
        _store = StateObject(wrappedValue: store ?? FeedStore())
    }

    // `-tab 1` on the launch line opens a tab for screenshots; launch args are never persisted.
    @State private var tab = UserDefaults.standard.integer(forKey: "tab")
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        TabView(selection: $tab) {
            Group {
                NavigationStack(path: $path) { home }
                    .tabItem { Label("Home", systemImage: "newspaper") }.tag(0)
                ManageFeedsView(store: store, library: library)
                    .tabItem { Label("Feeds", systemImage: "list.bullet.rectangle") }.tag(1)
                SettingsView(store: store, account: account, library: library)
                    .tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
            }
            #if os(iOS)
            .environment(\.horizontalSizeClass, sizeClass)
            #endif
        }
        #if os(iOS)
        // iPad puts tabs at the top in regular width; compact keeps the bar at the bottom.
        .environment(\.horizontalSizeClass, .compact)
        #endif
        .task(id: store.feeds) {
            if account.signedIn { try? await account.push(store.feeds) }   // keep the account's copy current
            await feed.refresh(feeds: store.feeds)
            // ponytail: store screenshot hook so a frame can open on an article
            if CommandLine.arguments.contains("-selectFirst"), let first = feed.entries.first { path = [first] }
            // `-showCoverage` opens the first story several outlets covered, with its Coverage sheet up
            if CommandLine.arguments.contains("-showCoverage"), let s = feed.stories.first(where: { $0.publishers > 1 }) { path = [s.lead] }
        }
    }

    private var home: some View {
        // Search matches headlines and outlet names ("BBC" shows only BBC). While searching there is no hero.
        let q = query.trimmingCharacters(in: .whitespaces)
        // One row per story (the same story from several outlets is grouped, Ground News style).
        let shown = q.isEmpty ? feed.stories : feed.stories.filter { $0.entries.contains { $0.title.localizedStandardContains(q) || $0.sourceTitle.localizedStandardContains(q) } }
        // The hero is the newest story with a picture among the first few; everything else is a row.
        let hero = q.isEmpty ? shown.prefix(5).first { $0.lead.imageURL != nil } : nil
        return List {
            SearchField(text: $query).listRowSeparator(.hidden)
            if let hero { HeroRow(entry: hero.lead, library: library, story: hero).listRowSeparator(.hidden) }
            ForEach(shown.filter { $0.id != hero?.id }) { EntryRow(entry: $0.lead, library: library, story: $0) }
            if !q.isEmpty && shown.isEmpty {
                Text("No stories match \u{201C}\(q)\u{201D}.").foregroundStyle(.secondary).listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)   // flush with the view, like Mail and News
        .refreshable { await feed.refresh(feeds: store.feeds) }
        .overlay {
            if feed.entries.isEmpty && feed.isLoading {
                ProgressView()
            } else if feed.entries.isEmpty {
                ContentUnavailableView("No entries yet", systemImage: "doc.text", description: Text("Add a feed or pull to refresh"))
            }
        }
        .navigationTitle("Bugle")   // still names the back button and the Mac window
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)   // the tab bar already says Home; stories start at the top
        #endif
        .navigationDestination(for: JournalEntry.self) { EntryDetailView(entry: $0, library: library, story: feed.story(for: $0)) }
    }
}

/// One story in a list: thumbnail, a title cut to fit, the outlet and how long ago. Swipe right or press and hold
/// to save, share or copy the link. A story you have opened dims, like a read mail. Used by Home, Saved and History.
struct EntryRow: View {
    let entry: JournalEntry
    @ObservedObject var library: Library
    var story: Story? = nil

    var body: some View {
        let read = library.isRead(entry)
        RowLink(entry: entry) {
            // News-app convention (Mobbin: Yahoo, Artifact, USA Today, NYT, Guardian): the outlet above the
            // headline, text on the left so every title starts on the same edge, the picture on the right.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Kicker(entry: entry, saved: library.isSaved(entry), sources: story?.publishers ?? 1)
                    FittedTitle(variants: Headline.variants(entry.title, source: entry.sourceTitle))
                        .foregroundStyle(read ? .secondary : .primary)
                }
                Spacer(minLength: 0)
                EntryThumbnail(url: entry.imageURL, page: entry.url, source: entry.sourceTitle)
                    .opacity(read ? 0.6 : 1)
            }
            .padding(.vertical, 6)
        }
        .swipeActions(edge: .leading) {
            Button { library.toggleSave(entry) } label: {
                Label(library.isSaved(entry) ? "Unsave" : "Save", systemImage: library.isSaved(entry) ? "bookmark.slash" : "bookmark")
            }
            .tint(.bugleAccent)
        }
        .contextMenu {
            Button { library.toggleSave(entry) } label: {
                Label(library.isSaved(entry) ? "Remove from Saved" : "Save", systemImage: library.isSaved(entry) ? "bookmark.slash" : "bookmark")
            }
            if let url = URL(string: entry.url) {
                ShareLink(item: url)
                Button { Pasteboard.copy(entry.url) } label: { Label("Copy Link", systemImage: "link") }
                Link(destination: url) { Label("Open in Browser", systemImage: "safari") }
            }
        }
    }
}

/// "BBC · 2h ago" above a headline; the outlet in the accent, a bookmark when saved.
struct Kicker: View {
    let entry: JournalEntry
    let saved: Bool
    var sources = 1

    var body: some View {
        let ago = RelativeTime.short(entry.date)
        HStack(spacing: 4) {
            if !entry.sourceTitle.isEmpty { Text(entry.sourceTitle).fontWeight(.semibold).foregroundStyle(Color.bugleAccent) }
            if !entry.sourceTitle.isEmpty && !ago.isEmpty { Text("·").foregroundStyle(.secondary) }
            Text(ago).foregroundStyle(.secondary)
            if sources > 1 { Text("· \(sources) sources").foregroundStyle(.secondary) }
            if saved { Image(systemName: "bookmark.fill").foregroundStyle(Color.bugleAccent).imageScale(.small) }
        }
        .font(.caption)
        .lineLimit(1)
    }
}

/// The top story, big: full-width picture, the outlet, and the whole headline (the one place a title gets more
/// than a line). Every news app on Mobbin opens this way.
struct HeroRow: View {
    let entry: JournalEntry
    @ObservedObject var library: Library
    var story: Story? = nil

    /// The longest clean cut up to 90 characters, so even the hero ends on a whole phrase, never "…".
    static func headline(_ e: JournalEntry) -> String {
        let v = Headline.variants(e.title, source: e.sourceTitle)
        return v.first { $0.count <= 90 } ?? v.last ?? e.title
    }

    var body: some View {
        RowLink(entry: entry) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: entry.imageURL) { phase in
                    if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { Color.bugleAccent.opacity(0.12) }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Kicker(entry: entry, saved: library.isSaved(entry), sources: story?.publishers ?? 1)
                Text(Self.headline(entry))
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(library.isRead(entry) ? .secondary : .primary)
            }
            .padding(.vertical, 8)
        }
        .contextMenu {
            Button { library.toggleSave(entry) } label: { Label(library.isSaved(entry) ? "Remove from Saved" : "Save", systemImage: "bookmark") }
            if let url = URL(string: entry.url) { ShareLink(item: url) }
        }
    }
}

/// A navigation link without the disclosure arrow: news apps don't draw one, the whole row is the target.
struct RowLink<Content: View>: View {
    let entry: JournalEntry
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            NavigationLink(value: entry) { EmptyView() }.opacity(0)
            content
        }
    }
}

/// A capsule search field with a leading magnifier and a clear button, 44 points tall (house Apple rules).
struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search stories and outlets", text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                #if os(iOS)
                .submitLabel(.search)
                #endif
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

enum Pasteboard {
    static func copy(_ s: String) {
        #if os(iOS)
        UIPasteboard.general.string = s
        #else
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string)
        #endif
    }
}

/// The longest headline variant that fits on one line, so titles end on a word, not "…". The last child is the
/// shortest variant allowed to truncate, for a window too narrow even for that.
private struct FittedTitle: View {
    let variants: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(variants, id: \.self) { Text($0).font(.headline).lineLimit(1).fixedSize(horizontal: true, vertical: false) }
            Text(variants.last ?? "").font(.headline).lineLimit(1)
        }
    }
}

/// Every row gets the same square, so the list lines up: the story's image when it has one, otherwise the outlet's
/// initials on a blue tile (Joshua 2026-10-25: a mix of rows with and without thumbnails looked funny).
private struct EntryThumbnail: View {
    let url: URL?
    let page: String
    let source: String
    @State private var preview: URL?
    private let side: CGFloat = 56

    var body: some View {
        Group {
            if let url = url ?? preview {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { outlet }
                }
            } else {
                outlet
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        // no image in the feed: ask the article page for its preview image before settling on initials
        .task(id: page) { if url == nil { preview = await PreviewImage.lookup(page) } }
    }

    /// The outlet's own icon from its site (apple-touch-icon, then favicon), else its initials.
    private var outlet: some View {
        let host = URL(string: page)?.host
        return ZStack {
            Color.bugleAccent.opacity(0.12)
            if let host, let touch = URL(string: "https://\(host)/apple-touch-icon.png"), let fav = URL(string: "https://\(host)/favicon.ico") {
                AsyncImage(url: touch) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        AsyncImage(url: fav) { p in
                            if case .success(let icon) = p { icon.resizable().interpolation(.high).scaledToFit().frame(width: 28, height: 28) } else { monogram }
                        }
                    default: monogram
                    }
                }
            } else {
                monogram
            }
        }
    }

    private var monogram: some View {
        Text(Self.initials(source)).font(.system(size: 17, weight: .bold)).foregroundStyle(Color.bugleAccent)
    }

    /// "BBC" stays BBC; "Hacker News" is HN; "The Province" is P. Mirrors `initials` in web/read.html.
    static func initials(_ source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 4, trimmed == trimmed.uppercased(), !trimmed.isEmpty { return trimmed }
        let words = trimmed.split(separator: " ").filter { $0.lowercased() != "the" }
        let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "C" : letters
    }
}
