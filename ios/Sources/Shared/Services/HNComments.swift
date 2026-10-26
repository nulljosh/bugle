import Foundation

/// A Hacker News story's comment thread, read in the reader under the article. One request to HN's Algolia API
/// returns the whole tree. Same rule as `web/hn.js`.
enum HNComments {
    /// The HN item id from an hnrss entry (its body links the comments page).
    static func id(_ entry: JournalEntry) -> String? {
        (entry.htmlContent + " " + entry.url).firstMatch(of: /news\.ycombinator\.com\/item\?id=(\d+)/).map { String($0.output.1) }
    }

    /// The thread as HTML, nil when there is none or it will not load.
    static func html(_ entry: JournalEntry) async -> String? {
        guard let id = id(entry), let url = URL(string: "https://hn.algolia.com/api/v1/items/\(id)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let item = try? JSONDecoder().decode(Item.self, from: data) else { return nil }
        let count = item.total
        guard count > 0 else { return nil }
        return "<h2>\(String(localized: "\(count) comments"))</h2>" + item.children.map { render($0, depth: 0) }.joined()
    }

    struct Item: Decodable {
        let author: String?
        let text: String?
        let created_at_i: Double?
        let children: [Item]
        var total: Int { children.reduce(0) { $0 + ($1.text == nil ? 0 : 1) + $1.total } }
    }

    // ponytail: indent stops at four levels; deeper replies sit at the fourth so a long thread stays readable
    private static func render(_ c: Item, depth: Int) -> String {
        let replies = c.children.map { render($0, depth: depth + 1) }.joined()
        guard let text = c.text, let author = c.author else { return replies }   // deleted comments keep their replies
        let when = c.created_at_i.map { Date(timeIntervalSince1970: $0).formatted(.relative(presentation: .named)) } ?? ""
        return "<div class=\"c\(depth > 0 && depth < 4 ? " r" : "")\"><p class=\"date\">\(clean(author)) · \(when)</p>\(clean(text))\(replies)</div>"
    }

    /// HN's own tags only (p, i, pre, code, and links out); every other tag, and any attribute, is dropped.
    static func clean(_ html: String) -> String {
        html.replacing(/<[^>]*>|<[^>]*$/) { m in
            let tag = String(m.output)
            return tag.wholeMatch(of: /<\/?(p|i|pre|code)>|<\/a>|<a href="https?:\/\/[^"<>\s]*"( rel="nofollow")?>/) != nil ? tag : ""
        }
    }
}

#if DEBUG
func hnDemo() {
    assert(HNComments.clean("<p>hi <i>x</i> <a href=\"https://a.b/c\" rel=\"nofollow\">l</a></p>") == "<p>hi <i>x</i> <a href=\"https://a.b/c\" rel=\"nofollow\">l</a></p>")
    assert(HNComments.clean("<script>alert(1)</script><p onclick=\"x\">a</p><img src=x onerror=y><a href=\"javascript:x\">b</a>") == "alert(1)a</p>b</a>")
    let e = JournalEntry(title: "t", url: "https://x.com", date: .now, htmlContent: "<a href=\"https://news.ycombinator.com/item?id=42\">c</a>")
    assert(HNComments.id(e) == "42", "hn id from the hnrss body")
}
#endif
