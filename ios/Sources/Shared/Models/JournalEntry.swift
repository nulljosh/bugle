import Foundation

struct JournalEntry: Codable, Identifiable, Hashable {
    var id: String { url }
    let title: String
    let url: String
    let date: Date
    let htmlContent: String
    var sourceTitle: String = ""
    // Optional so entries cached before thumbnails existed still decode.
    var imageURL: URL? = nil
    /// A podcast episode's audio (the feed's audio enclosure); nil for an article.
    var audioURL: URL? = nil
    /// The episode's length from the feed, when it says.
    var audioSeconds: Int? = nil
}

extension String {
    /// HTML entities a feed escaped twice ("iFixit&#8217;s" after XML has had its turn): numeric ones and the five
    /// named ones that turn up in headlines. Mirrors decodeEntities in web/parse.js.
    var decodingEntities: String {
        guard contains("&") else { return self }
        let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&nbsp;": " "]
        return replacing(/&#(x[0-9a-fA-F]+|[0-9]+);|&(amp|lt|gt|quot|apos|nbsp);/) { m in
            if let n = m.output.1 {
                let v = n.hasPrefix("x") ? UInt32(n.dropFirst(), radix: 16) : UInt32(n)
                return v.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? String(m.output.0)
            }
            return named[String(m.output.0)] ?? String(m.output.0)
        }
    }

    /// Tags out, the common entities decoded, whitespace collapsed.
    var plainText: String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8217;", with: "\u{2019}").replacingOccurrences(of: "&#8220;", with: "\u{201C}")
            .replacingOccurrences(of: "&#8221;", with: "\u{201D}")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

extension JournalEntry {
    /// The body as plain text: tags out, the common entities decoded, whitespace collapsed.
    var plainText: String { htmlContent.plainText }

    /// "4 min read" at 230 words a minute; nil for a summary too short to be worth timing. Same rule as
    /// readingTime in web/parse.js.
    var readingTime: String? {
        let words = plainText.split(separator: " ").count
        return words < 150 ? nil : String(localized: "\(Int((Double(words) / 230).rounded(.up))) min read")
    }

    /// An episode's length, "16 min" (Apple Podcasts rounds the same way); nil for an article. Same as listenTime in
    /// web/parse.js.
    var listenTime: String? {
        audioSeconds.map { String(localized: "\(max(1, Int((Double($0) / 60).rounded()))) min") }
    }
}

#if DEBUG
func readingTimeDemo() {
    func entry(_ words: Int) -> JournalEntry {
        JournalEntry(title: "t", url: "u", date: .now, htmlContent: "<p>" + Array(repeating: "word", count: words).joined(separator: " ") + "</p>")
    }
    assert(entry(149).readingTime == nil)
    assert(entry(150).readingTime == String(localized: "\(1) min read"))
    assert(entry(231).readingTime == String(localized: "\(2) min read"))
}
#endif
