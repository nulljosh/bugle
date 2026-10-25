import Foundation

/// A week of headlines, kept across refreshes, so a story can show its timeline: the days before, including what
/// the feeds no longer carry (Ground News's timeline). Bodies are dropped to keep it small; an earlier story opens through
/// FullText like any summary. Same rule as `web/timeline.js`.
@MainActor
enum Archive {
    private static let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("bugle-archive.json")
    private static var entries: [JournalEntry] = {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([JournalEntry].self, from: data)) ?? []
    }()

    static func keep(_ fresh: [JournalEntry], now: Date = .now) {
        var seen = Set<String>()
        entries = (fresh.map { e -> JournalEntry in
            var slim = JournalEntry(title: e.title, url: e.url, date: e.date, htmlContent: "")
            slim.sourceTitle = e.sourceTitle
            slim.imageURL = e.imageURL
            return slim
        } + entries)
            .filter { now.timeIntervalSince($0.date) < 7 * 86_400 && seen.insert($0.id).inserted }
            .sorted { $0.date > $1.date }
            .prefix(3000).map { $0 }   // ponytail: a cap, not a smarter store; a week of 25 feeds fits
        try? JSONEncoder().encode(entries).write(to: url)
    }

    /// The story's timeline: its own headlines and the archive's matching ones (same grouping rule) from more than
    /// 12 hours before the lead, newest first.
    static func earlier(_ story: Story) -> [JournalEntry] {
        earlier(story, in: entries)
    }

    nonisolated static func earlier(_ story: Story, in archive: [JournalEntry]) -> [JournalEntry] {
        let ids = Set(story.entries.map(\.id))
        // the same test the grouping uses, with the week's own common words left out
        let noise = Coverage.common(archive.map(\.title)), kw = Coverage.keywords(story.lead.title).subtracting(noise)
        let matches = archive.filter { !ids.contains($0.id) && Coverage.sameStory(kw, Coverage.keywords($0.title).subtracting(noise)) }
        let cutoff = story.lead.date.addingTimeInterval(-12 * 3600)
        return (story.entries + matches).filter { $0.date < cutoff }.sorted { $0.date > $1.date }
    }
}

#if DEBUG
@MainActor
func archiveDemo() {
    func e(_ title: String, _ hoursAgo: Double) -> JournalEntry {
        JournalEntry(title: title, url: title, date: .now.addingTimeInterval(-hoursAgo * 3600), htmlContent: "")
    }
    let lead = e("Hurricane Maria makes landfall in Florida", 1)
    let story = Story(lead: lead, entries: [lead, e("Hurricane Maria nears Florida", 20)])
    let found = Archive.earlier(story, in: [e("Hurricane Maria strengthens off Florida coast", 30), e("Florida votes on budget", 40),
                                            e("Hurricane Maria landfall Florida live", 0.5)])
    assert(found.map(\.title) == ["Hurricane Maria nears Florida", "Hurricane Maria strengthens off Florida coast"], "timeline: the days before, newest first")
}
#endif
