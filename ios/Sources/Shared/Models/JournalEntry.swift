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
