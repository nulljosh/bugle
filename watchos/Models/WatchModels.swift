import Foundation

/// Mirrors `Feed` from the iOS target (Sources/Shared/Models/Feed.swift) — a plain
/// RSS/Atom subscription, title + URL only.
struct WatchFeed: Codable, Identifiable, Hashable {
    var id: String { url }
    var title: String
    let url: String
}

/// Mirrors `JournalEntry` from the iOS target (Sources/Shared/Models/JournalEntry.swift).
/// Bugle has no accounts and no user-authored content — it is a multi-feed RSS/Atom
/// reader, not a diary. imageURL is dropped here since the watch list doesn't render
/// thumbnails; every other field matches the iOS model exactly.
struct WatchEntry: Codable, Identifiable, Hashable {
    var id: String { url }
    let title: String
    let url: String
    let date: Date
    let htmlContent: String
    var sourceTitle: String = ""

    /// Crude tag-stripped preview for the watch detail screen — watchOS has no WebKit,
    /// so the rich HTML render EntryDetailView.swift does on iOS isn't available here.
    var plainTextPreview: String {
        let stripped = htmlContent.replacingOccurrences(
            of: "<[^>]+>", with: " ", options: .regularExpression)
        let decoded = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return decoded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Trimmed port of iOS's `FeedParser` (Sources/Shared/Services/JournalFeedService.swift) —
/// same title/link/date/content extraction across Atom `<entry>` and RSS `<item>`, minus the
/// thumbnail-picking logic the watch list has no use for.
final class WatchFeedParser: NSObject, XMLParserDelegate {
    private var entries: [WatchEntry] = []
    private var element = ""
    private var title = ""
    private var link = ""
    private var date = ""
    private var content = ""
    private var summary = ""   // RSS feeds often send both a summary and the full text
    private var inItem = false

    static func parse(data: Data) -> [WatchEntry] {
        let parser = XMLParser(data: data)
        let delegate = WatchFeedParser()
        parser.delegate = delegate
        parser.parse()
        return delegate.entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        element = elementName
        if elementName == "entry" || elementName == "item" {
            inItem = true; title = ""; link = ""; date = ""; content = ""; summary = ""
        } else if elementName == "link", inItem, let href = attributeDict["href"] {
            link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch element {
        case "title": title += string
        case "link": link += string
        case "published", "updated", "pubDate", "dc:date": date += string
        case "content", "content:encoded": content += string
        case "description", "summary": summary += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let s = String(data: CDATABlock, encoding: .utf8) else { return }
        switch element {
        case "content", "content:encoded": content += s
        case "description", "summary": summary += s
        case "title": title += s
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        guard elementName == "entry" || elementName == "item" else { return }
        inItem = false
        entries.append(WatchEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: link.trimmingCharacters(in: .whitespacesAndNewlines),
            date: Self.parseDate(date.trimmingCharacters(in: .whitespacesAndNewlines)),
            htmlContent: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? summary : content
        ))
    }

    private static let rfc822: [DateFormatter] = ["EEE, dd MMM yyyy HH:mm:ss Z",
                                                  "EEE, dd MMM yyyy HH:mm:ss zzz"].map {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = $0
        return f
    }

    static func parseDate(_ s: String) -> Date {
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        for f in rfc822 { if let d = f.date(from: s) { return d } }
        return .distantPast
    }
}
