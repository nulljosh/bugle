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
        Feed(title: "Wired", url: "https://www.wired.com/feed/rss"),
        Feed(title: "The Verge", url: "https://www.theverge.com/rss/index.xml"),
        Feed(title: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index"),
        Feed(title: "TechCrunch", url: "https://techcrunch.com/feed/"),
        Feed(title: "MacRumors", url: "https://feeds.macrumors.com/MacRumors-All"),
        Feed(title: "9to5Mac", url: "https://9to5mac.com/feed/"),
        Feed(title: "AppleInsider", url: "https://appleinsider.com/rss/news/"),
        Feed(title: "Macworld", url: "https://www.macworld.com/feed"),
        Feed(title: "Six Colors", url: "https://sixcolors.com/feed/"),
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

    /// A site address works as well as a feed address: if the page is not a feed, the feed it links to
    /// (`<link rel="alternate" type="application/rss+xml">`). Anything that fails comes back as typed.
    static func discover(_ typed: String) async -> String {
        var s = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        guard let url = URL(string: s), let (data, _) = try? await URLSession.shared.data(from: url),
              FeedParser.parse(data: data).isEmpty, let page = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return typed }
        let tags = page.matches(of: /<link\b[^>]*>/.ignoresCase()).map { String($0.output) }
        guard let tag = tags.first(where: { $0.range(of: #"rel=["']?[^"'>]*alternate"#, options: [.regularExpression, .caseInsensitive]) != nil
                                         && $0.range(of: #"(rss|atom)\+xml"#, options: [.regularExpression, .caseInsensitive]) != nil }),
              let href = tag.firstMatch(of: /href=["']([^"']+)["']/.ignoresCase())?.1,
              let feed = FeedParser.resolve(String(href), against: s) else { return typed }
        return feed.absoluteString
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

    /// Local newsrooms by city (Apple News and Ground News both have a Local feed). Mirrors LOCAL in web/reader.js.
    static let local: [(city: String, feeds: [Feed])] = [
        ("Vancouver", [Feed(title: "Vancouver Sun", url: "https://vancouversun.com/feed"), Feed(title: "The Province", url: "https://theprovince.com/feed"), Feed(title: "CBC British Columbia", url: "https://www.cbc.ca/webfeed/rss/rss-canada-britishcolumbia"), Feed(title: "Global BC", url: "https://globalnews.ca/bc/feed/"), Feed(title: "Vancouver Is Awesome", url: "https://www.vancouverisawesome.com/rss")]),
        ("Calgary", [Feed(title: "Calgary Herald", url: "https://calgaryherald.com/feed"), Feed(title: "CBC Calgary", url: "https://www.cbc.ca/webfeed/rss/rss-canada-calgary"), Feed(title: "Global Calgary", url: "https://globalnews.ca/calgary/feed/")]),
        ("Edmonton", [Feed(title: "Edmonton Journal", url: "https://edmontonjournal.com/feed"), Feed(title: "Global Edmonton", url: "https://globalnews.ca/edmonton/feed/")]),
        ("Toronto", [Feed(title: "Toronto Sun", url: "https://torontosun.com/feed"), Feed(title: "CBC Toronto", url: "https://www.cbc.ca/webfeed/rss/rss-canada-toronto"), Feed(title: "Global Toronto", url: "https://globalnews.ca/toronto/feed/")]),
        ("Ottawa", [Feed(title: "Ottawa Citizen", url: "https://ottawacitizen.com/feed"), Feed(title: "CBC Ottawa", url: "https://www.cbc.ca/webfeed/rss/rss-canada-ottawa")]),
        ("Montreal", [Feed(title: "CBC Montreal", url: "https://www.cbc.ca/webfeed/rss/rss-canada-montreal"), Feed(title: "Global Montreal", url: "https://globalnews.ca/montreal/feed/")]),
        ("Seattle", [Feed(title: "Seattle Times", url: "https://www.seattletimes.com/seattle-news/feed/")]),
        ("New York", [Feed(title: "Gothamist", url: "https://gothamist.com/feed"), Feed(title: "NY Post Metro", url: "https://nypost.com/metro/feed/")]),
        ("Los Angeles", [Feed(title: "LA Times California", url: "https://www.latimes.com/california/rss2.0.xml"), Feed(title: "LAist", url: "https://laist.com/index.atom")]),
        ("London", [Feed(title: "BBC London", url: "https://feeds.bbci.co.uk/news/england/london/rss.xml"), Feed(title: "Evening Standard", url: "https://www.standard.co.uk/news/london/rss")])
    ]

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

/// OPML, the file every feed reader trades: export writes the followed feeds, import follows each outline with an
/// xmlUrl that is not followed yet and says how many that was.
extension FeedStore {
    var opml: String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "<", with: "&lt;")
        }
        let body = feeds.map { "    <outline type=\"rss\" text=\"\(esc($0.title))\" title=\"\(esc($0.title))\" xmlUrl=\"\(esc($0.url))\"/>" }
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<opml version=\"2.0\">\n  <head><title>Bugle feeds</title></head>\n  <body>\n"
            + body.joined(separator: "\n") + "\n  </body>\n</opml>\n"
    }

    /// The export as a file, for the share sheet.
    var opmlFile: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Bugle.opml")
        try? opml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func importOPML(_ data: Data) -> Int {
        OPMLParser.feeds(in: data).filter { add($0) }.count
    }
}

final class OPMLParser: NSObject, XMLParserDelegate {
    private var feeds: [Feed] = []

    static func feeds(in data: Data) -> [Feed] {
        let p = OPMLParser(), x = XMLParser(data: data)
        x.delegate = p
        x.parse()
        return p.feeds
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String] = [:]) {
        guard elementName == "outline", let url = a["xmlUrl"], url.lowercased().hasPrefix("http"), let host = URL(string: url)?.host else { return }
        feeds.append(Feed(title: a["title"] ?? a["text"] ?? host, url: url))
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
    let back = OPMLParser.feeds(in: Data(FeedStore().opml.utf8))
    assert(!back.isEmpty && back.allSatisfy { $0.url.hasPrefix("http") }, "OPML export does not read back")
    for f in FeedStore.local.flatMap(\.feeds) { assert(f.url.hasPrefix("https://") && URL(string: f.url)?.host != nil, "bad local feed: \(f.url)") }
}
#endif
