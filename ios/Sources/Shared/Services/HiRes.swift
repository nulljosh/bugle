import Foundation

/// The lead story's picture at full size. Feeds send small copies (BBC 240 px, the Guardian 460, CBC 620) and the hero
/// is a phone-wide card, about 1200 px. Picture servers that size by URL take a bigger size; the Guardian signs its
/// URLs, so its widest plain copy comes from the story's own page. Mirrors web/hires.js.
enum HiRes {
    /// The same picture asked for at about 1600 px, where the server sizes by URL; otherwise the URL as it was.
    static func upsize(_ url: URL) -> URL {
        let s = url.absoluteString
            .replacing(/ichef\.bbci\.co\.uk\/(ace\/\w+|news)\/\d+\//) { "ichef.bbci.co.uk/\($0.output.1)/1536/" }
            .replacing(/ichef\.bbci\.co\.uk\/images\/ic\/\d+x\d+\//, with: "ichef.bbci.co.uk/images/ic/1200x1200/")   // podcast art
            .replacing(/Resize(%3D|=)\d+/) { "Resize\($0.output.1)1600" }                                            // CBC
            .replacing(/(a57\.foxnews\.com\/.+?)\/\d+\/\d+\//) { "\($0.output.1)/1600/900/" }                      // Fox
            .replacing(/([?&](?:#038;)?w=)\d+/) { "\($0.output.1)1600" }                                             // WordPress: NY Post, Postmedia
        return URL(string: s) ?? url
    }

    @MainActor private static var found: [String: URL] = [:]

    /// A Guardian picture: the widest copy the story's page offers of the same image, without the logo overlay its
    /// share image carries. nil for anyone else, or when the page has none.
    @MainActor static func fromPage(_ url: URL, story: String) async -> URL? {
        guard url.host == "i.guim.co.uk", let page = URL(string: story) else { return nil }
        if let hit = found[story] { return hit }
        guard let (data, _) = try? await URLSession.shared.data(from: page), let html = String(data: data, encoding: .utf8) else { return nil }
        let stem = String(url.absoluteString.split(separator: "?")[0])
        let best = widest(html.matches(of: /https:\/\/i\.guim\.co\.uk\/img\/[^"\s]+/).map { String($0.output).replacingOccurrences(of: "&amp;", with: "&") }
            .filter { $0.hasPrefix(stem) && $0.contains("fit=max") && !$0.contains("overlay") })
        let out = best.flatMap(URL.init(string:))
        found[story] = out
        return out
    }

    static func widest(_ urls: [String]) -> String? {
        func width(_ s: String) -> Int { s.firstMatch(of: /width=(\d+)/).flatMap { Int($0.output.1) } ?? 0 }
        return urls.max { width($0) < width($1) }
    }
}

#if DEBUG
func hiResDemo() {
    assert(HiRes.upsize(URL(string: "https://ichef.bbci.co.uk/ace/standard/976/cps/a.jpg")!).absoluteString == "https://ichef.bbci.co.uk/ace/standard/1536/cps/a.jpg")
    assert(HiRes.upsize(URL(string: "https://nypost.com/a.jpg?quality=75&strip=all&w=1024")!).absoluteString.hasSuffix("w=1600"))
    assert(HiRes.upsize(URL(string: "https://example.com/a.jpg")!).absoluteString == "https://example.com/a.jpg")
    assert(HiRes.widest(["x?width=700&fit=max", "x?width=1065&fit=max", "x?width=140"]) == "x?width=1065&fit=max")
}
#endif
