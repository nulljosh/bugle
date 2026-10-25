import Foundation
import UserNotifications

/// Notifications for the outlets you pick (Apple News and Ground News both do it): swipe right on a feed in Feeds.
/// After a background refresh, stories from those outlets newer than the last one announced become notifications,
/// three at most, newest first. The first refresh only sets the mark, so turning it on never floods you.
enum Alerts {
    static let key = "notify"        // newline-joined outlet names, the same shape as topics (Topics helpers)
    private static let mark = "notifiedUntil"

    static func isOn(_ source: String, in raw: String) -> Bool { Topics.has(source, in: raw) }

    /// Turns alerts for one outlet on or off, asking for permission the first time one goes on.
    @MainActor
    static func toggle(_ source: String) async {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        if !isOn(source, in: raw) { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
        UserDefaults.standard.set(Topics.toggled(source, in: raw), forKey: key)
    }

    static func post(_ entries: [JournalEntry], now: Date = .now) {
        let sources = Topics.list(UserDefaults.standard.string(forKey: key) ?? "")
        let since = UserDefaults.standard.double(forKey: mark)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: mark)
        guard since > 0, !sources.isEmpty else { return }
        for e in fresh(entries, sources: sources, since: Date(timeIntervalSince1970: since)) {
            let c = UNMutableNotificationContent()
            c.title = e.sourceTitle
            c.body = Headline.clean(e.title, source: e.sourceTitle)
            c.userInfo = ["url": e.url]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: e.url, content: c, trigger: nil))
        }
    }

    /// Stories from the chosen outlets published after `since`, newest first, three at most.
    static func fresh(_ entries: [JournalEntry], sources: [String], since: Date) -> [JournalEntry] {
        Array(entries.filter { e in e.date > since && sources.contains { $0.caseInsensitiveCompare(e.sourceTitle) == .orderedSame } }
            .sorted { $0.date > $1.date }.prefix(3))
    }
}

#if DEBUG
func alertsDemo() {
    let t = Date(timeIntervalSince1970: 100)
    func e(_ s: String, _ d: Double) -> JournalEntry { JournalEntry(title: "x\(d)", url: "u\(s)\(d)", date: Date(timeIntervalSince1970: d), htmlContent: "", sourceTitle: s) }
    let got = Alerts.fresh([e("BBC", 50), e("BBC", 150), e("NPR", 160), e("bbc", 170), e("BBC", 180), e("BBC", 190)], sources: ["BBC"], since: t)
    assert(got.map(\.date.timeIntervalSince1970) == [190, 180, 170])   // newest three, any case, nothing older, other outlets out
}
#endif
