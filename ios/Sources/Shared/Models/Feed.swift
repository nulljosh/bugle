import Foundation

struct Feed: Codable, Identifiable, Hashable {
    var id: String { url }
    var title: String
    let url: String
}

/// Persisted list of subscribed feeds. Seeded with `seedFeeds` so the app has real content on
/// first launch, but the user can add or remove any RSS/Atom feed. Seeds are plain
/// subscriptions like any other — Bugle has no code coupling to any of these sites.
@MainActor
final class FeedStore: ObservableObject {
    @Published var feeds: [Feed] {
        didSet { save() }
    }

    /// First-launch subscriptions. The list came from newsline's curated `FEEDS`
    /// (`~/Documents/Code/newsline/src/feeds.js`), which is maintained against a recency
    /// check, not just an item count — that matters, because several big outlets ship
    /// *zombie* feeds that answer 200 with a well-formed body whose newest item is years
    /// old. Deliberately absent for that reason, do not "helpfully" add them back:
    /// CNN (frozen 2023-2024), feeds.a.dj.com (frozen 2025-01, dowjones.io is the live
    /// host and is what's used below), Reuters (killed public RSS), AP (never had one),
    /// MSNBC, CTV and the Washington Post (404 or dead redirect).
    ///
    /// newsline scores these for political bias; Bugle does not render a bias bar, so
    /// only title and URL cross over.
    /// Not in `seedFeeds`: this is a public app, users don't need the author's personal blog
    /// by default. Still addable manually or via `unsubscribedSeeds`.
    static let journalFeed = Feed(title: "Journal", url: "https://journal.jaybulb.com/feed.xml")

    static let seedFeeds: [Feed] = [
        Feed(title: "CBC", url: "https://www.cbc.ca/webfeed/rss/rss-topstories"),
        Feed(title: "The Guardian", url: "https://www.theguardian.com/world/rss"),
        Feed(title: "NPR", url: "https://feeds.npr.org/1001/rss.xml"),
        Feed(title: "BBC", url: "https://feeds.bbci.co.uk/news/world/rss.xml"),
        Feed(title: "Global News", url: "https://globalnews.ca/feed/"),
        Feed(title: "NBC News", url: "https://feeds.nbcnews.com/nbcnews/public/news"),
        Feed(title: "Wall Street Journal", url: "https://feeds.content.dowjones.io/public/rss/RSSWorldNews"),
        Feed(title: "National Post", url: "https://nationalpost.com/feed"),
        Feed(title: "Fox News", url: "https://moxie.foxnews.com/google-publisher/latest.xml"),
        Feed(title: "NY Post", url: "https://nypost.com/feed/"),
        Feed(title: "NY Post Opinion", url: "https://nypost.com/opinion/feed/"),
        Feed(title: "Daily Wire", url: "https://www.dailywire.com/feeds/rss.xml"),
        Feed(title: "Vancouver Sun", url: "https://vancouversun.com/feed"),
        Feed(title: "The Province", url: "https://theprovince.com/feed"),
        Feed(title: "Hacker News", url: "https://hnrss.org/frontpage"),
        Feed(title: "Daring Fireball", url: "https://daringfireball.net/feeds/main"),
    ]

    private let storeURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("feeds.json")
    }()

    init() {
        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONDecoder().decode([Feed].self, from: data) {
            // heyitsmejosh.com lapsed 2026-10-13; move saved subscriptions on it to jaybulb.com
            var seen = Set<String>()
            feeds = saved.map {
                Feed(title: $0.title, url: $0.url.replacingOccurrences(of: ".heyitsmejosh.com", with: ".jaybulb.com"))
            }.filter { seen.insert($0.url).inserted }
        } else {
            feeds = Self.seedFeeds
        }
    }

    func add(urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalized = trimmed
        if !normalized.lowercased().hasPrefix("http") { normalized = "https://" + normalized }
        guard let u = URL(string: normalized), let host = u.host else { return false }
        return add(Feed(title: host, url: normalized))
    }

    /// The single insertion point — every caller routes its duplicate check through here.
    @discardableResult
    func add(_ feed: Feed) -> Bool {
        guard !feeds.contains(where: { $0.url == feed.url }) else { return false }
        feeds.append(feed)
        return true
    }

    /// Seeds the user has not subscribed to, for the Suggested list.
    var unsubscribedSeeds: [Feed] {
        ([Self.journalFeed] + Self.seedFeeds).filter { seed in !feeds.contains(where: { $0.url == seed.url }) }
    }

    func remove(at offsets: IndexSet) {
        feeds.remove(atOffsets: offsets)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(feeds) else { return }
        try? data.write(to: storeURL)
    }
}

#if DEBUG
/// ponytail: minimal self-check for the seed list, same style as `feedParserDemo()`.
/// Catches a typo'd or duplicated seed URL at launch; it does not check that a feed is
/// live — that is newsline's `npm run feeds` recency job, not the app's business.
@MainActor
func seedFeedsDemo() {
    let seeds = FeedStore.seedFeeds
    assert(!seeds.isEmpty, "seedFeeds is empty")
    for f in seeds {
        assert(f.url.hasPrefix("https://"), "seed not https: \(f.url)")
        assert(URL(string: f.url)?.host != nil, "seed url unparseable: \(f.url)")
        assert(!f.title.isEmpty, "seed has no title: \(f.url)")
    }
    assert(Set(seeds.map(\.id)).count == seeds.count, "duplicate seed URL")
}
#endif
