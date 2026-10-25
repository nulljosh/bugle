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
}

extension JournalEntry {
    /// The body as plain text: tags out, the common entities decoded, whitespace collapsed.
    var plainText: String {
        htmlContent.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&nbsp;", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
