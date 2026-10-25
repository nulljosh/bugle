import Foundation

/// The whole article when a feed only sends a summary: fetch the page and keep the paragraphs of its main block
/// (the `<article>` or `<main>` with the most text), as plain text, so nothing from the page runs or styles
/// the reader. Same rule as `web/fulltext.js`.
/// ponytail: paragraphs only, no pictures or links from the page; the story's own picture and Open original stay.
enum FullText {
    static func paragraphs(inHTML page: String) -> [String] {
        // menus, sidebars, footers and forms are not the story; neither is any line the page repeats
        let html = page.replacing(/(?s)<(nav|aside|footer|header|form|figure)\b[^>]*>.*?<\/\1>/.ignoresCase(), with: "")
        let blocks = html.matches(of: /(?s)<(article|main)\b[^>]*>(.*?)<\/\1>/.ignoresCase()).map { String($0.output.2) }
        func paras(_ s: String) -> [String] {
            s.matches(of: /(?s)<p\b[^>]*>(.*?)<\/p>/.ignoresCase()).map { String($0.output.1).plainText }.filter { $0.count > 60 }
        }
        let seen = Dictionary(paras(html).map { ($0, 1) }, uniquingKeysWith: +)
        func once(_ p: [String]) -> [String] { p.filter { seen[$0] == 1 } }
        let best = blocks.map { once(paras($0)) }.max { $0.joined().count < $1.joined().count } ?? []
        return best.isEmpty ? once(paras(html)) : best
    }

    /// The entry with the page's text as its body, or nil when the page has no more than the feed did.
    static func fill(_ entry: JournalEntry) async -> JournalEntry? {
        guard entry.readingTime == nil, let url = URL(string: entry.url),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return nil }
        let found = paragraphs(inHTML: html)
        guard found.joined(separator: " ").split(separator: " ").count >= 150 else { return nil }
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        var full = JournalEntry(title: entry.title, url: entry.url, date: entry.date,
                                htmlContent: found.map { "<p>\(esc($0))</p>" }.joined())
        full.sourceTitle = entry.sourceTitle
        full.imageURL = entry.imageURL
        return full
    }
}

#if DEBUG
func fullTextDemo() {
    let long = String(repeating: "This sentence is part of the real story and runs long. ", count: 2)
    let page = "<html><body><nav><p>\(long) menu</p></nav><article><p>\(long)one</p><p>short</p><p>\(long)two</p>"
        + "<p>\(long)signup</p><p>\(long)signup</p></article>"
        + "<aside><article><p>\(long)related</p></article></aside></body></html>"
    let found = FullText.paragraphs(inHTML: page)
    assert(found.count == 2 && found[0].hasSuffix("one") && found[1].hasSuffix("two"), "full text picks the main article")
}
#endif
