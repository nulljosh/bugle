import Foundation

/// Saved stories and reading history, kept whole (body included) so a saved story still opens with no network.
/// Apple News keeps both under Following; Bugle keeps them at the top of Feeds. Mirrors web/library.js.
@MainActor
final class Library: ObservableObject {
    @Published private(set) var saved: [JournalEntry] = []
    @Published private(set) var history: [JournalEntry] = []   // newest first
    private static let historyCap = 200

    private struct Stored: Codable { var saved: [JournalEntry]; var history: [JournalEntry] }
    private let file: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }()

    init() {
        if let data = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(Stored.self, from: data) {
            saved = s.saved; history = s.history
        }
    }

    func isSaved(_ e: JournalEntry) -> Bool { saved.contains { $0.id == e.id } }
    func isRead(_ e: JournalEntry) -> Bool { history.contains { $0.id == e.id } }

    func toggleSave(_ e: JournalEntry) {
        if isSaved(e) { saved.removeAll { $0.id == e.id } } else { saved.insert(e, at: 0) }
        write()
    }

    func markRead(_ e: JournalEntry) {
        history.removeAll { $0.id == e.id }
        history.insert(e, at: 0)
        if history.count > Self.historyCap { history.removeLast(history.count - Self.historyCap) }
        write()
    }

    func clearHistory() { history = []; write() }

    private func write() {
        try? JSONEncoder().encode(Stored(saved: saved, history: history)).write(to: file, options: .atomic)
    }
}

/// Topics you follow: words that become chips on Home, one tap to read only them (Apple News, Ground News).
/// Kept as one newline-joined string in UserDefaults ("topics"). Mirrors Topics in web/library.js.
enum Topics {
    static func list(_ raw: String) -> [String] { raw.split(separator: "\n").map(String.init) }
    static func has(_ t: String, in raw: String) -> Bool { list(raw).contains { $0.caseInsensitiveCompare(t) == .orderedSame } }
    /// Follows `t`, or unfollows it in any case ("ai" unfollows "AI").
    static func toggled(_ t: String, in raw: String) -> String {
        let l = list(raw), kept = l.filter { $0.caseInsensitiveCompare(t) != .orderedSame }
        return (kept.count < l.count ? kept : l + [t]).joined(separator: "\n")
    }
}

/// "Now", "12m ago", "3h ago", "Yesterday", then a date. Undated entries (sorted to the bottom) show nothing.
/// Mirrors `ago()` in web/reader.js.
enum RelativeTime {
    static func short(_ date: Date, now: Date = Date()) -> String {
        guard date > .distantPast.addingTimeInterval(1) else { return "" }
        let s = now.timeIntervalSince(date)
        if s < 60 { return "Now" }
        if s < 3600 { return "\(Int(s / 60))m ago" }
        if s < 86400 { return "\(Int(s / 3600))h ago" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#if DEBUG
func relativeTimeDemo() {
    let now = Date()
    assert(RelativeTime.short(now.addingTimeInterval(-30), now: now) == "Now")
    assert(RelativeTime.short(now.addingTimeInterval(-600), now: now) == "10m ago")
    assert(RelativeTime.short(now.addingTimeInterval(-7200), now: now) == "2h ago")
    assert(RelativeTime.short(.distantPast, now: now) == "")
    assert(Topics.toggled("AI", in: "") == "AI")
    assert(Topics.toggled("ai", in: "Canada\nAI") == "Canada")
    assert(Topics.toggled("Apple", in: "Canada") == "Canada\nApple")
}
#endif
