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
    @ObservedObject private var player = Player.shared
    @State private var nowPlaying = false
    @State private var briefing = false
    @State private var path: [JournalEntry] = []
    /// The search tab's own stack, so a story opened there does not land on Home too.
    @State private var searchPath: [JournalEntry] = []
    @State private var query = UserDefaults.standard.string(forKey: "search") ?? ""   // `-search BBC` for screenshots
    @AppStorage("topics") private var topics = ""
    @AppStorage("muted") private var muted = ""
    @AppStorage("compactList") private var compact = false

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

    /// Three columns on the Mac and on iPad in regular width (HomeSplit); one stack on a phone.
    private var split: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    /// iOS 18 and later: a semantic search tab, which iOS 26 sets apart at the trailing end of the bar and opens as a
    /// glass field at the bottom (Apple: "Use semantic search tabs"). It searches the same query Home filters by.
    @ViewBuilder private var tabs: some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            TabView(selection: $tab) {
                Tab("Home", systemImage: "newspaper", value: 0) { homeTab }
                Tab("Feeds", systemImage: "list.bullet.rectangle", value: 1) { feedsTab }
                Tab("Settings", systemImage: "gearshape", value: 2) { settingsTab }
                Tab(value: 3, role: .search) {
                    NavigationStack(path: $searchPath) { home(path: $searchPath, title: "Search", inlineSearch: false) }
                }
            }
            .environment(\.horizontalSizeClass, .compact)   // iPad keeps the bar at the bottom, as on a phone
            .searchable(text: $query, prompt: "Stories and outlets")   // on the TabView, so the search tab becomes the field
            .opensSearchOnTab()
        } else { classicTabs }
        #else
        classicTabs
        #endif
    }

    private var classicTabs: some View {
        TabView(selection: $tab) {
            homeTab.tabItem { Label("Home", systemImage: "newspaper") }.tag(0)
            feedsTab.tabItem { Label("Feeds", systemImage: "list.bullet.rectangle") }.tag(1)
            settingsTab.tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
        }
        #if os(iOS)
        // iPad puts tabs at the top in regular width; compact keeps the bar at the bottom.
        .environment(\.horizontalSizeClass, .compact)
        #endif
    }

    private var homeTab: some View {
        Group {
            if split { HomeSplit(query: $query, path: $path, feeds: store.feeds, topics: Topics.list(topics)) { home(path: $path) } story: { EntryDetailView(entry: $0, library: library, story: feed.story(for: $0), stepper: stepper($0, path: $path)) } }
            else { NavigationStack(path: $path) { home(path: $path) } }
        }
        #if os(iOS)
        .environment(\.horizontalSizeClass, sizeClass)
        #endif
    }

    private var feedsTab: some View {
        ManageFeedsView(store: store, library: library, entries: feed.entries, dead: feed.dead) { query = $0.title; tab = 0 }
            #if os(iOS)
            .environment(\.horizontalSizeClass, sizeClass)
            #endif
    }

    private var settingsTab: some View {
        SettingsView(store: store, account: account, library: library)
            #if os(iOS)
            .environment(\.horizontalSizeClass, sizeClass)
            #endif
    }

    /// Before iOS 18 there is no search tab, so Home keeps its own field at the top.
    private var hasSearchTab: Bool {
        #if os(iOS)
        if #available(iOS 18, *) { return true }
        #endif
        return false
    }

    var body: some View {
        tabs
        .tint(accent)
        // hidden on the playing episode's own story, where its full player already is
        .miniPlayer(player, hidden: (tab == 3 ? searchPath : path).last?.id == player.entry?.id) { _ in nowPlaying = true }
        .minimizesTabBar()
        .sheet(isPresented: $nowPlaying) { NowPlayingView(player: player) { tab = 0; path = [$0] } }
        .sheet(isPresented: $briefing) { BriefingView(stories: Array(Coverage.today(feed.stories).prefix(5))) { tab = 0; path = [$0] } }
        // Keyboard (Mac, iPad): ⌘R refreshes, ⌘1 to ⌘3 pick a tab. Invisible buttons carry the shortcuts.
        .background {
            Group {
                Button("Refresh") { Task { await feed.refresh(feeds: store.feeds) } }.keyboardShortcut("r")
                Button("Home") { tab = 0 }.keyboardShortcut("1")
                Button("Feeds") { tab = 1 }.keyboardShortcut("2")
                Button("Settings") { tab = 2 }.keyboardShortcut("3")
            }
            .opacity(0).accessibilityHidden(true)
        }
        .onChange(of: muted, initial: true) { feed.muted = Topics.list(muted) }
        // signed in: saves, topics and mutes reach the account as they change, like the feed list does
        .onChange(of: "\(library.saved.count)|\(topics)|\(muted)") { if account.signedIn { Task { try? await account.push(store.feeds) } } }
        .onAppear { account.library = library }
        .continuesStories(in: library) { tab = 0; path = [$0] }
        .drainsInbox(store: store, library: library)
        .task(id: store.feeds) {
            if account.signedIn { try? await account.push(store.feeds) }   // keep the account's copy current
            await feed.refresh(feeds: store.feeds)
            // ponytail: store screenshot hook so a frame can open on an article
            if CommandLine.arguments.contains("-selectFirst"), let first = feed.entries.first { path = [first] }
            if CommandLine.arguments.contains("-selectEpisode"), let first = feed.episodes.first { path = [first] }
            if CommandLine.arguments.contains("-selectHN"), let hn = feed.entries.first(where: { HNComments.id($0) != nil && !$0.htmlContent.contains("# Comments: 0") }) { path = [hn] }
            if CommandLine.arguments.contains("-briefing") { briefing = true }
            if CommandLine.arguments.contains("-nowPlaying") {   // Now Playing with an episode and three in Up Next
                if let first = feed.episodes.first { player.cue(first) }   // paused: no sound from QA
                feed.episodes.dropFirst().prefix(3).filter { !player.isQueued($0) }.forEach(player.toggleQueue)
                nowPlaying = true
            }
            // `-showCoverage` opens the first story several outlets covered, with its Coverage sheet up
            if CommandLine.arguments.contains("-showCoverage"), let s = feed.stories.first(where: { $0.publishers > 1 }) { path = [s.lead] }
        }
    }

    /// Search matches headlines and outlet names ("BBC" shows only BBC). One row per story (the same story from
    /// several outlets is grouped, Ground News style); Today's biggest lead.
    private var shown: [Story] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if let picked = Coverage.pick(q, from: feed.stories) { return picked }
        if q.caseInsensitiveCompare(Coverage.unread) == .orderedSame { return Coverage.today(feed.stories).filter { !library.isRead($0.lead) } }
        // Up Next first, in order, then every other episode newest first
        if q.caseInsensitiveCompare(Coverage.podcasts) == .orderedSame {
            return (player.queue + feed.episodes.filter { !player.isQueued($0) }).map { Story(lead: $0, entries: [$0]) }
        }
        if q.isEmpty { return Coverage.today(feed.stories) }
        func hit(_ e: JournalEntry) -> Bool { e.title.localizedStandardContains(q) || e.sourceTitle.localizedStandardContains(q) }
        // episodes too, so a show tapped in Feeds lists its episodes
        return feed.stories.filter { $0.entries.contains(where: hit) } + feed.episodes.filter(hit).map { Story(lead: $0, entries: [$0]) }
    }

    /// Up and down in the reader walk the list as Home shows it, replacing the open story.
    private func stepper(_ e: JournalEntry, path: Binding<[JournalEntry]>) -> StoryStepper {
        let leads = shown.map(\.lead)
        let i = leads.firstIndex { $0.id == e.id }
        func at(_ j: Int?) -> JournalEntry? { j.flatMap { leads.indices.contains($0) ? leads[$0] : nil } }
        return StoryStepper(prev: at(i.map { $0 - 1 }), next: at(i.map { $0 + 1 })) { next in
            if path.wrappedValue.isEmpty { path.wrappedValue = [next] } else { path.wrappedValue[path.wrappedValue.count - 1] = next }
        }
    }

    /// Every story on Home from one outlet (one feed followed, or a search for it): the app wears its color, HN
    /// orange, BBC red. Several outlets: Bugle blue.
    private var accent: Color {
        let sources = Set(shown.map(\.lead.sourceTitle))
        return sources.count == 1 ? Outlet.color(sources.first!) : .bugleAccent
    }

    /// Home and the search tab: the same list. A large title, as Apple's own apps have; filtered, it names the filter
    /// and a glass button clears it.
    private func home(path: Binding<[JournalEntry]>, title: LocalizedStringKey = "Home", inlineSearch: Bool? = nil) -> some View {
        let inline = inlineSearch ?? !hasSearchTab
        // While searching there is no hero.
        let q = query.trimmingCharacters(in: .whitespaces)
        let shown = self.shown
        // The hero is the newest story with a picture among the first few; everything else is a row.
        let hero = q.isEmpty && !compact ? shown.prefix(5).first { $0.lead.imageURL != nil } : nil
        return List {
            if inline { SearchField(text: $query).listRowSeparator(.hidden) }
            // Searching for a word that is not an outlet offers to follow it.
            let followable = !q.isEmpty && Outlet.of(q) == nil && !store.feeds.contains { $0.title.caseInsensitiveCompare(q) == .orderedSame }
                && !Coverage.isCollection(q) && q.caseInsensitiveCompare(Coverage.podcasts) != .orderedSame
            TopicBar(query: $query, topics: $topics, muted: $muted, followable: followable, briefing: inline ? { briefing = true } : nil).listRowSeparator(.hidden)
            if q.caseInsensitiveCompare(Coverage.podcasts) == .orderedSame && !feed.episodes.isEmpty { ShowsRow(episodes: feed.episodes) { query = $0 } }
            if let hero { HeroRow(entry: hero.lead, library: library, story: hero).listRowSeparator(.hidden) }
            ForEach(shown.filter { $0.id != hero?.id }) { EntryRow(entry: $0.lead, library: library, story: $0) }
            if !q.isEmpty && shown.isEmpty {
                Text(q.caseInsensitiveCompare(Coverage.blindspots) == .orderedSame ? "No blindspots right now."
                     : q.caseInsensitiveCompare(Coverage.podcasts) == .orderedSame ? "No episodes yet. Follow a podcast in Feeds."
                     : q.caseInsensitiveCompare(Coverage.unread) == .orderedSame ? "All caught up."
                     : Coverage.isCollection(q) ? "Nothing here right now."
                     : "No stories match \u{201C}\(q)\u{201D}.").foregroundStyle(.secondary).listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)   // flush with the view, like Mail and News
        .refreshable { await feed.refresh(feeds: store.feeds) }
        .overlay {
            if shown.isEmpty && feed.isLoading {   // podcasts can land before the news: still loading, not empty
                ProgressView()
            } else if feed.entries.isEmpty {
                ContentUnavailableView("No entries yet", systemImage: "doc.text", description: Text("Add a feed or pull to refresh"))
            }
        }
        #if os(iOS)
        .navigationTitle(inline || q.isEmpty || title == "Search" ? title : LocalizedStringKey(q))
        .navigationBarTitleDisplayMode(inline ? .inline : .large)
        .toolbar(inline ? .hidden : .automatic, for: .navigationBar)   // iOS 17: the field sits where the title would
        .toolbar {
            if !inline {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !q.isEmpty && title != "Search" { Button { query = "" } label: { Label("Show All", systemImage: "xmark") } }
                    if title != "Search" { Button { briefing = true } label: { Label("Briefing", systemImage: "list.number") } }
                }
            }
        }
        .todaySubtitle(!inline && q.isEmpty && title != "Search")
        #else
        .navigationTitle("Bugle")   // the Mac window
        #endif
        .navigationDestination(for: JournalEntry.self) { EntryDetailView(entry: $0, library: library, story: feed.story(for: $0), stepper: stepper($0, path: path)) }
    }
}

extension View {
    /// Tapping the search tab puts the cursor in the field (iOS 26).
    @ViewBuilder func opensSearchOnTab() -> some View {
        #if os(iOS)
        if #available(iOS 26, *) { tabViewSearchActivation(.searchTabSelection) } else { self }
        #else
        self
        #endif
    }

    /// Today's date under Home's large title, like Apple News (iOS 26).
    @ViewBuilder func todaySubtitle(_ on: Bool) -> some View {
        #if os(iOS)
        if #available(iOS 26, *), on { navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())) } else { self }
        #else
        self
        #endif
    }
}
