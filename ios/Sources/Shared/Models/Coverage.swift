import SwiftUI

/// Ground News-style coverage, ported from Sidewise (`sidewise/src/stories.js`): the same story grouped across
/// outlets, each outlet's lean and owner, a left / center / right count per story, and blindspots (a story only
/// one side covers). Mirrors web/coverage.js; change both or neither.
///
/// Lean ratings are Bugle's own editorial reading of each outlet (Sidewise's table), from -2 (left) to +2 (right).
/// Tech outlets and personal blogs carry no political lean and are left out of every count rather than called center.
struct Outlet {
    let lean: Int?          // -2...2, nil when not rated
    let owner: String
    let publisher: String   // one newsroom with two feeds (NY Post and its opinion feed) counts once

    static let known: [String: Outlet] = [
        "CBC": .init(lean: -1, owner: "Canadian public broadcaster", publisher: "CBC"),
        "The Guardian": .init(lean: -1, owner: "Guardian Media Group (Scott Trust)", publisher: "The Guardian"),
        "NPR": .init(lean: -1, owner: "US nonprofit public radio", publisher: "NPR"),
        "BBC": .init(lean: 0, owner: "UK public broadcaster", publisher: "BBC"),
        "Global News": .init(lean: 0, owner: "Corus Entertainment", publisher: "Global News"),
        "NBC News": .init(lean: -1, owner: "NBCUniversal (Comcast)", publisher: "NBC News"),
        "Wall Street Journal": .init(lean: 1, owner: "Dow Jones (News Corp)", publisher: "Wall Street Journal"),
        "National Post": .init(lean: 1, owner: "Postmedia", publisher: "National Post"),
        "Fox News": .init(lean: 2, owner: "Fox Corporation", publisher: "Fox News"),
        "NY Post": .init(lean: 2, owner: "News Corp", publisher: "NY Post"),
        "NY Post Opinion": .init(lean: 2, owner: "News Corp", publisher: "NY Post"),
        "Daily Wire": .init(lean: 2, owner: "The Daily Wire (independent)", publisher: "Daily Wire"),
        "Vancouver Sun": .init(lean: 0, owner: "Postmedia", publisher: "Postmedia BC"),
        "The Province": .init(lean: 0, owner: "Postmedia", publisher: "Postmedia BC"),
        "Hacker News": .init(lean: nil, owner: "Y Combinator", publisher: "Hacker News"),
        "Daring Fireball": .init(lean: nil, owner: "John Gruber (independent)", publisher: "Daring Fireball"),
        "Journal": .init(lean: nil, owner: "Joshua's blog", publisher: "Journal"),
    ]

    static func of(_ source: String) -> Outlet? { known[source] }

    /// Each outlet's own color (light, dark), the same table as web/coverage.js, where test.mjs checks every pair is
    /// 4.5:1 on white and on black. Anything else gets Bugle blue.
    static let brand: [String: (light: UInt32, dark: UInt32)] = [
        "Hacker News": (0xC24E00, 0xFF7A1A), "BBC": (0xBB1919, 0xFF6B6B), "CBC": (0xCC0000, 0xFF6B6B),
        "The Guardian": (0x052962, 0x7FA8F0), "NPR": (0x1D6AA5, 0x5AAEF0), "Global News": (0x1565C0, 0x64A8FF),
        "NBC News": (0x0A66B0, 0x4CB6F5), "Wall Street Journal": (0x111111, 0xF5F5F7), "National Post": (0x005A9C, 0x63A4E0),
        "Fox News": (0x003366, 0x6FA3E0), "NY Post": (0xCC0000, 0xFF6B6B), "NY Post Opinion": (0xCC0000, 0xFF6B6B),
        "Daily Wire": (0x111111, 0xF5F5F7), "Vancouver Sun": (0x12599E, 0x6AA6E6), "The Province": (0xC8102E, 0xFF6B78),
        "Daring Fireball": (0x4A525A, 0xA3ABB3), "Journal": (0x0059B3, 0x5AA9FF),
    ]

    /// A feed Bugle doesn't know gets a steady color from its name (same set and hash as web/coverage.js).
    /// ponytail: a name hash, not the site's own color; read its theme-color if someone wants the real brand.
    static let palette: [(light: UInt32, dark: UInt32)] = [
        (0xC62828, 0xFF6B6B), (0xC24E00, 0xFF8A3D), (0x2E7D32, 0x5FD068), (0x1565C0, 0x64A8FF), (0x1A3A6B, 0x7FA8F0),
        (0xC2185B, 0xFF6FA5), (0xB00020, 0xFF5C7A), (0x1B5E20, 0x66BB6A), (0x455A64, 0xA3B4BD), (0x0D47A1, 0x82B1FF),
    ]

    static func colors(_ source: String) -> (light: UInt32, dark: UInt32) {
        if let b = brand[source] { return b }
        let h = source.utf16.reduce(UInt32(0)) { $0 &* 31 &+ UInt32($1) }
        return palette[Int(h % UInt32(palette.count))]
    }

    static func color(_ source: String) -> Color {
        guard !source.isEmpty else { return .bugleAccent }
        let c = colors(source)
        return Color(light: c.light, dark: c.dark)
    }

    static func leanLabel(_ lean: Int) -> String {
        ["Left", "Leans left", "Center", "Leans right", "Right"][max(0, min(4, lean + 2))]
    }
}

enum Side: Int, CaseIterable { case left, center, right
    init(lean: Int) { self = lean < 0 ? .left : lean > 0 ? .right : .center }
    var title: String { ["Left", "Center", "Right"][rawValue] }
}

struct Story: Identifiable {
    let lead: JournalEntry          // the newest headline is the story's title
    let entries: [JournalEntry]     // lead first, then the rest, newest first
    var id: String { lead.id }

    /// Newsrooms covering it; one publisher's two feeds count once.
    var publishers: Int { Set(entries.map { Outlet.of($0.sourceTitle)?.publisher ?? $0.sourceTitle }).count }

    /// Newsrooms per side, rated outlets only.
    var counts: [Side: Int] {
        var seen: [Side: Set<String>] = [:]
        for e in entries {
            guard let o = Outlet.of(e.sourceTitle), let lean = o.lean else { continue }
            seen[Side(lean: lean), default: []].insert(o.publisher)
        }
        return seen.mapValues(\.count)
    }

    /// Covered by more than one newsroom, all on one side: the other side's readers likely never saw it.
    var blindspot: Side? {
        let c = counts.filter { $0.value > 0 }
        return c.count == 1 && publishers > 1 ? c.keys.first : nil
    }
}

enum Coverage {
    private static let stop: Set<String> = Set(("the a an of to in on for and or as at by is are was with after over from amid says say new " +
        "this that it its his her their they we you but not has have had will would could should " +
        "about into more than what when who how why been being were where which").split(separator: " ").map(String.init))

    static func keywords(_ title: String) -> Set<String> {
        let cleaned = title.lowercased().map { ($0.isLetter && $0.isASCII) || $0.isNumber ? $0 : " " }
        return Set(String(cleaned).split(separator: " ").map(String.init).filter { $0.count > 2 && !stop.contains($0) })
    }

    /// Group stories that share at least half their headline keywords, newest seeding each group so the title is the
    /// latest wording. ponytail: O(n²) keyword overlap, same as Sidewise; embeddings if it ever groups badly.
    static func cluster(_ entries: [JournalEntry]) -> [Story] {
        var groups: [(kw: Set<String>, items: [JournalEntry])] = []
        for e in entries.sorted(by: { $0.date > $1.date }) {
            let kw = keywords(e.title)
            guard !kw.isEmpty else { groups.append((kw, [e])); continue }
            if let i = groups.firstIndex(where: { !$0.kw.isEmpty && Double($0.kw.intersection(kw).count) / Double(min($0.kw.count, kw.count)) >= 0.5 }) {
                groups[i].items.append(e)
                groups[i].kw.formUnion(kw)
            } else {
                groups.append((kw, [e]))
            }
        }
        return groups.map { Story(lead: $0.items[0], entries: $0.items) }.sorted { $0.lead.date > $1.lead.date }
    }

    /// Today: the five biggest stories of the last day (most newsrooms, at least two) lead Home, then the rest, newest first.
    static func today(_ stories: [Story], now: Date = .now) -> [Story] {
        let top = stories.filter { $0.publishers > 1 && now.timeIntervalSince($0.lead.date) < 86_400 }
            .sorted { ($0.publishers, $0.lead.date) > ($1.publishers, $1.lead.date) }.prefix(5)
        let ids = Set(top.map(\.id))
        return Array(top) + stories.filter { !ids.contains($0.id) }
    }

    /// The lean of what you read: per side, how many of your opened stories came from it.
    static func readingLean(_ history: [JournalEntry]) -> [Side: Int] {
        var c: [Side: Int] = [:]
        for e in history { if let lean = Outlet.of(e.sourceTitle)?.lean { c[Side(lean: lean), default: 0] += 1 } }
        return c
    }
}

#if DEBUG
func coverageDemo() {
    func e(_ t: String, _ s: String, _ m: Double) -> JournalEntry {
        JournalEntry(title: t, url: "https://x/\(t.hashValue)\(s)", date: Date(timeIntervalSince1970: m), htmlContent: "", sourceTitle: s)
    }
    let stories = Coverage.cluster([
        e("Senate passes border funding bill after long debate", "Fox News", 3),
        e("Border funding bill passes Senate", "NY Post", 2),
        e("Senate approves border funding package", "NY Post Opinion", 1),
        e("Apple ships new MacBook", "Daring Fireball", 0),
    ])
    assert(stories.count == 2)
    let border = stories.first { $0.entries.count == 3 }!
    assert(border.publishers == 2)              // NY Post and its opinion feed are one newsroom
    assert(border.blindspot == .right)          // two newsrooms, all on the right
    assert(stories.first { $0.entries.count == 1 }!.counts.isEmpty)   // tech outlets are not rated
    assert(Outlet.colors("Ars Technica") == Outlet.palette[7])   // the same index web/coverage.js picks (test.mjs)
    let ranked = Coverage.today(stories, now: Date(timeIntervalSince1970: 10))
    assert(ranked.first?.entries.count == 3)    // the story two newsrooms carry leads Today
}
#endif
