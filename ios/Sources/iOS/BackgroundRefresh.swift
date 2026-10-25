import BackgroundTasks
import SwiftUI

/// Refresh in the background (Apple News and Ground News both do): iOS wakes Bugle now and then, it fetches every
/// followed feed into the cache and pulls the top stories' pictures into the disk cache, so opening the app shows
/// today's news at once, pictures and all, even offline. iOS picks the moment; we ask for no sooner than 30 minutes.
enum BackgroundRefresh {
    static let id = "com.nulljosh.journal.refresh"

    static func schedule() {
        let req = BGAppRefreshTaskRequest(identifier: id)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    @MainActor
    static func run() async {
        schedule()   // the next one, before this one's time runs out
        let feed = JournalFeedService()
        await feed.refresh(feeds: FeedStore().feeds)   // saves the entry cache Home loads first
        Alerts.post(feed.entries)                     // new stories from the outlets you asked to hear about
        for story in Coverage.today(feed.stories).prefix(12) {
            guard let u = story.lead.imageURL else { continue }
            _ = try? await URLSession.shared.data(for: URLRequest(url: u, cachePolicy: .returnCacheDataElseLoad))
        }
    }
}
