import Foundation

/// Bugle has no accounts and no server-side personal data — the iOS app (see
/// Sources/Shared/Models/Feed.swift, JournalFeedService.swift) is a standalone RSS/Atom
/// reader that fetches subscribed feeds directly from their public URLs, no auth required.
/// This mirrors that: entries come straight from the feed URLs below.
///
/// `apiToken` exists for the CMS/CRM pivot the iOS app's CLAUDE.md describes as underway
/// (Supabase-backed `inkpress_posts`/`inkpress_contacts`, no Swift code against it yet).
/// There's nothing to authenticate against today, so it isn't required for entries to load,
/// but it's sent as a header when present so this app doesn't need another round of surgery
/// once that backend exists — and, per house pattern, having *no* UI to set a token the app
/// already reads from UserDefaults is the specific gap being avoided here.
final class WatchAPI: @unchecked Sendable {
    static let shared = WatchAPI()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let defaults = UserDefaults.standard

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        session = URLSession(configuration: config)
    }

    // MARK: - Pairing

    var apiToken: String {
        get { defaults.string(forKey: "api_token") ?? "" }
        set { defaults.set(newValue, forKey: "api_token") }
    }

    var isPaired: Bool { !apiToken.isEmpty }

    // MARK: - Feeds

    /// Same default subscription iOS seeds first (`FeedStore.seedFeeds[0]`) — the user's own
    /// journal.jaybulb.com blog. The watch stays scoped to that single real "journal"
    /// rather than mirroring all 16 curated news feeds, which don't fit a watch face.
    static let defaultFeeds: [WatchFeed] = [
        WatchFeed(title: "Journal", url: "https://journal.jaybulb.com/feed.xml")
    ]

    var feeds: [WatchFeed] {
        get {
            guard let data = defaults.data(forKey: "watch_feeds"),
                  let saved = try? decoder.decode([WatchFeed].self, from: data),
                  !saved.isEmpty else { return Self.defaultFeeds }
            return saved
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: "watch_feeds")
        }
    }

    // MARK: - Entries

    /// Fetches every subscribed feed concurrently and merges, mirroring
    /// `JournalFeedService.refresh(feeds:)` on iOS.
    func fetchEntries() async throws -> [WatchEntry] {
        let subscriptions = feeds
        guard !subscriptions.isEmpty else { return [] }

        var merged: [WatchEntry] = []
        await withTaskGroup(of: [WatchEntry].self) { group in
            for feed in subscriptions {
                group.addTask { [weak self] in
                    guard let self, let url = URL(string: feed.url) else { return [] }
                    var request = URLRequest(url: url)
                    let token = self.apiToken
                    if !token.isEmpty { request.setValue(token, forHTTPHeaderField: "x-api-token") }
                    guard let (data, response) = try? await self.session.data(for: request),
                          let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode
                    else { return [] }
                    return WatchFeedParser.parse(data: data).map {
                        var e = $0; e.sourceTitle = feed.title; return e
                    }
                }
            }
            for await result in group { merged.append(contentsOf: result) }
        }

        guard !merged.isEmpty else { throw URLError(.badServerResponse) }
        let sorted = merged.sorted { $0.date > $1.date }
        cache(sorted)
        return sorted
    }

    func cachedEntries() -> [WatchEntry]? {
        guard let data = defaults.data(forKey: "cache_entries") else { return nil }
        return try? decoder.decode([WatchEntry].self, from: data)
    }

    private func cache(_ entries: [WatchEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: "cache_entries")
        defaults.set(Date().timeIntervalSince1970, forKey: "cache_entries_time")
    }
}
