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
        "Wired": .init(lean: nil, owner: "Condé Nast", publisher: "Wired"),
        "The Verge": .init(lean: nil, owner: "Vox Media", publisher: "The Verge"),
        "Ars Technica": .init(lean: nil, owner: "Condé Nast", publisher: "Ars Technica"),
        "TechCrunch": .init(lean: nil, owner: "Yahoo", publisher: "TechCrunch"),
        "Macworld": .init(lean: nil, owner: "Foundry", publisher: "Macworld"),
        "Six Colors": .init(lean: nil, owner: "Jason Snell (independent)", publisher: "Six Colors"),
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
        "Wired": (0x333333, 0xBDBDBD), "Ars Technica": (0xC2410C, 0xFF7A3D), "TechCrunch": (0x0A7A00, 0x3DDC2F), "Macworld": (0xC8102E, 0xFF6B6B),
    ]

    /// A feed Bugle doesn't know gets a steady color from its name (same set and hash as web/coverage.js).
    /// ponytail: a name hash, not the site's own color; read its theme-color if someone wants the real brand.
    static let palette: [(light: UInt32, dark: UInt32)] = [
        (0xC62828, 0xFF6B6B), (0xC24E00, 0xFF8A3D), (0x2E7D32, 0x5FD068), (0x1565C0, 0x64A8FF), (0x1A3A6B, 0x7FA8F0),
        (0xC2185B, 0xFF6FA5), (0xB00020, 0xFF5C7A), (0x1B5E20, 0x66BB6A), (0x455A64, 0xA3B4BD), (0x0D47A1, 0x82B1FF),
    ]

    static let family: [(prefix: String, outlet: String)] = [("CBC ", "CBC"), ("Global ", "Global News"), ("BBC ", "BBC"), ("NY Post ", "NY Post")]

    static func colors(_ source: String) -> (light: UInt32, dark: UInt32) {
        if let b = brand[source] { return b }
        // A newsroom's local desks wear its color: "CBC Toronto", "Global BC", "BBC London", "NY Post Metro".
        if let f = family.first(where: { source.hasPrefix($0.prefix) }) { return brand[f.outlet]! }
        let h = source.utf16.reduce(UInt32(0)) { $0 &* 31 &+ UInt32($1) }
        return palette[Int(h % UInt32(palette.count))]
    }

    static func color(_ source: String) -> Color {
        guard !source.isEmpty else { return .bugleAccent }
        let c = colors(source)
        return Color(light: c.light, dark: c.dark)
    }

    static func leanLabel(_ lean: Int) -> String {
        String(localized: String.LocalizationValue(["Left", "Leans left", "Center", "Leans right", "Right"][max(0, min(4, lean + 2))]))
    }
}

enum Side: Int, CaseIterable { case left, center, right
    init(lean: Int) { self = lean < 0 ? .left : lean > 0 ? .right : .center }
    var title: String { String(localized: String.LocalizationValue(["Left", "Center", "Right"][rawValue])) }
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

    func side(_ s: Side) -> Int { counts[s] ?? 0 }

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

    /// One story: at least two keywords in common ("Netflix" alone is not a story) and half of the shorter headline's,
    /// measured against the headline that seeded the story (its lead), never against every word a group collected.
    static func sameStory(_ a: Set<String>, _ b: Set<String>) -> Bool {
        let n = a.intersection(b).count
        return n >= 2 && Double(n) / Double(min(a.count, b.count)) >= 0.5
    }

    /// Words in so many of today's headlines they say nothing about which story it is ("apple", "iphone" on a tech
    /// day): in more headlines than any one story gets, max(8, 1 in 40). ponytail: a document-frequency cut, not TF-IDF.
    static func common(_ titles: [String]) -> Set<String> {
        var df: [String: Int] = [:]
        for t in titles { for w in keywords(t) { df[w, default: 0] += 1 } }
        let cut = max(8, titles.count / 40)
        return Set(df.filter { $0.value > cut }.keys)
    }

    /// Group stories that share their headline keywords, newest seeding each group so the title is the latest wording.
    /// ponytail: O(n²) keyword overlap, same as Sidewise; embeddings if it ever groups badly.
    static func cluster(_ entries: [JournalEntry]) -> [Story] {
        var groups: [(kw: Set<String>, items: [JournalEntry])] = []
        let noise = common(entries.map(\.title))
        for e in entries.sorted(by: { $0.date > $1.date }) {
            let kw = keywords(e.title).subtracting(noise)
            guard !kw.isEmpty else { groups.append((kw, [e])); continue }
            if let i = groups.firstIndex(where: { sameStory($0.kw, kw) }) {
                groups[i].items.append(e)
            } else {
                groups.append((kw, [e]))
            }
        }
        return groups.map { Story(lead: $0.items[0], entries: $0.items) }.sorted { $0.lead.date > $1.lead.date }
    }

    /// Today: the five biggest stories of the last day (most newsrooms, at least two) lead Home, then the rest, newest first.
    /// Muted: an outlet by name, or any headline containing the word. Mirrors muted in web/coverage.js.
    static func isMuted(_ e: JournalEntry, _ list: [String]) -> Bool {
        list.contains { e.sourceTitle.caseInsensitiveCompare($0) == .orderedSame || e.title.localizedCaseInsensitiveContains($0) }
    }

    /// The Home chip (and search word) that shows only blindspot stories.
    static let blindspots = "Blindspots"
    /// The Podcasts chip: episodes, newest first, apart from the news.
    static let podcasts = "Podcasts"

    /// Ground News's collections, each a Home chip and a search word: blindspots, what one side covers most, and what
    /// both sides covered (where to compare the takes). Biggest first. Mirrors COLLECTIONS in web/coverage.js.
    static var collections: [(name: String, icon: String, keep: (Story) -> Bool)] {
        [(blindspots, "eye.slash", { $0.blindspot != nil }),
         ("Popular Left", "arrow.left", { $0.side(.left) >= 2 && $0.side(.left) > $0.side(.right) }),
         ("Popular Right", "arrow.right", { $0.side(.right) >= 2 && $0.side(.right) > $0.side(.left) }),
         ("Both Sides", "arrow.left.and.right", { $0.side(.left) > 0 && $0.side(.right) > 0 })]
    }

    /// The collection a search word names, biggest story first; nil when it names none.
    static func pick(_ q: String, from stories: [Story]) -> [Story]? {
        guard let c = collections.first(where: { $0.name.caseInsensitiveCompare(q) == .orderedSame }) else { return nil }
        return stories.filter(c.keep).sorted { ($0.publishers, $0.lead.date) > ($1.publishers, $1.lead.date) }
    }

    static func isCollection(_ q: String) -> Bool { collections.contains { $0.name.caseInsensitiveCompare(q) == .orderedSame } }

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
    assert(Coverage.pick("popular right", from: stories)?.map(\.id) == [border.id], "two right newsrooms make Popular Right")
    assert(Coverage.pick("Popular Left", from: stories)?.isEmpty == true && Coverage.pick("BBC", from: stories) == nil)
    // a busy topic does not swallow its neighbours: on a tech day "apple iphone duo" is in everything
    let day = (1...9).map { e("Apple iPhone Duo review roundup part \($0)", "Macworld", Double(100 + $0)) }
    let duo = Coverage.cluster(day + [e("Apple wants to fix Safari's cramped layout on iPhone Duo", "MacRumors", 50),
                                      e("Apple exploring fix for Safari's cramped layout on the iPhone Duo's outer display", "9to5Mac", 40),
                                      e("Using an Apple Pencil with the iPhone Duo: what to know", "MacRumors", 30),
                                      e("New Apple TV 4K adds Siri AI support", "Six Colors", 20)])
    let size = { (word: String) in duo.first { $0.lead.title.contains(word) || $0.entries.contains { $0.title.contains(word) } }!.entries.count }
    assert(size("Safari") == 2 && size("Pencil") == 1 && size("Siri") == 1, "grouping: the same story joins, its neighbours do not")
    assert(stories.first { $0.entries.count == 1 }!.counts.isEmpty)   // tech outlets are not rated
    assert(Outlet.colors("The Verge") == Outlet.palette[4])
    assert(Outlet.colors("CBC Toronto") == Outlet.colors("CBC") && Outlet.colors("Global BC") == Outlet.colors("Global News"))   // the same index web/coverage.js picks (test.mjs)
    let ranked = Coverage.today(stories, now: Date(timeIntervalSince1970: 10))
    assert(ranked.first?.entries.count == 3)    // the story two newsrooms carry leads Today
}
#endif
