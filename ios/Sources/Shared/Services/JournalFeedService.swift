import Foundation

@MainActor
final class JournalFeedService: ObservableObject {
    @Published var entries: [JournalEntry] = [] { didSet { regroup() } }
    /// Muted outlets and words (Settings, or Mute on Home) drop out before grouping.
    var muted: [String] = [] { didSet { if muted != oldValue { regroup() } } }
    /// The same story across outlets, grouped (Coverage.cluster); Home shows one row per story.
    @Published private(set) var stories: [Story] = []
    /// Podcast episodes, newest first. They stay out of `stories`: a daily show's "top stories in 10 minutes" is
    /// not news coverage, and grouping it would skew the common-word list.
    @Published private(set) var episodes: [JournalEntry] = []
    private var storyOf: [String: Story] = [:]
    @Published var isLoading = false
    /// Feeds that gave nothing on the last refresh; Feeds says "Not loading right now" under them.
    @Published private(set) var dead: Set<String> = []
    @Published var errorMessage: String?

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("journal-entries.json")
    }()

    init() {
        loadCache()
        regroup()
    }

    func story(for entry: JournalEntry) -> Story? { storyOf[entry.id] }

    private func regroup() {
        let shown = entries.filter { !Coverage.isMuted($0, muted) }
        stories = Coverage.cluster(shown.filter { $0.audioURL == nil })
        // WSJ posts one episode to two of its shows; list it once
        var titles = Set<String>()
        episodes = shown.filter { $0.audioURL != nil && titles.insert($0.title).inserted }
        storyOf = Dictionary(stories.flatMap { s in s.entries.map { ($0.id, s) } }, uniquingKeysWith: { a, _ in a })
    }

    /// Fetch every subscribed feed concurrently, tag each entry with its source, and merge.
    func refresh(feeds: [Feed]) async {
        guard !feeds.isEmpty else { entries = []; return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var merged: [JournalEntry] = []
        var failures = 0
        var gone = Set<String>()
        var shown = Date.distantPast
        let empty = entries.isEmpty   // with a cached list on screen, swap once at the end instead of shrinking it
        await withTaskGroup(of: (String, [JournalEntry]).self) { group in
            for feed in feeds {
                group.addTask {
                    // A feed that stops answering gives up after 15 seconds of silence instead of URLSession's 60.
                    guard let url = URL(string: feed.url),
                          let (data, _) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15)) else { return (feed.url, []) }
                    var got = FeedParser.parse(data: data).map { var e = $0; e.sourceTitle = feed.title; return e }
                    // ponytail: a show's newest 30 episodes; its back catalog (2000 in one WSJ feed) stays on its site
                    if got.contains(where: { $0.audioURL != nil }) { got = Array(got.sorted { $0.date > $1.date }.prefix(30)) }
                    return (feed.url, got)
                }
            }
            for await (url, result) in group {
                if result.isEmpty { failures += 1; gone.insert(url) } else { merged.append(contentsOf: result) }
                // With nothing on screen, Home fills in as feeds arrive instead of waiting on the slowest one (a first
                // launch on a phone network sat on a spinner): the first feed in, then at most every two seconds.
                if empty, !merged.isEmpty, Date().timeIntervalSince(shown) > 2 { show(merged); shown = .now }
            }
        }
        dead = gone

        if merged.isEmpty {
            if failures > 0 { errorMessage = String(localized: "Couldn't load feeds. Pull to retry.") }
            return
        }
        show(merged)
        saveCache()
        Archive.keep(entries.filter { $0.audioURL == nil })
    }

    /// Newest first, one row per link: outlets that share a newsroom (NY Post and NY Post Opinion) carry the same one.
    private func show(_ merged: [JournalEntry]) {
        var seen = Set<String>()
        entries = merged.sorted { $0.date > $1.date }.filter { seen.insert($0.id).inserted }
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return }
        entries = cached.sorted { $0.date > $1.date }
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL)
    }
}

/// ponytail: hand-rolled parser handling both Atom (<entry>) and RSS 2.0 (<item>).
/// Covers the common feed shapes; swap for a library only if exotic namespaces show up.
final class FeedParser: NSObject, XMLParserDelegate {
    private var entries: [JournalEntry] = []
    private var element = ""
    private var title = ""
    private var link = ""
    private var date = ""
    private var content = ""
    private var summary = ""   // RSS feeds often send both a summary and the full text
    private var mediaSrc = ""
    private var mediaWidth = -1
    private var enclosureSrc = ""
    private var audioSrc = ""   // a podcast episode's <enclosure type="audio/...">
    private var duration = ""   // <itunes:duration>, "1:02:03", "16:40" or seconds
    private var showNotes = ""  // <itunes:summary>, for episodes with no description (CBC)
    private var showArt = ""    // the channel's <itunes:image>
    private var inItem = false

    static func parse(data: Data) -> [JournalEntry] {
        let parser = XMLParser(data: data)
        let delegate = FeedParser()
        parser.delegate = delegate
        parser.parse()
        // WSJ and Megaphone shows give every episode the show's page as its link; an episode is then known by its
        // audio, or the whole show would collapse into one row
        // An episode with no art of its own wears the show's.
        let links = Dictionary(delegate.entries.map { ($0.url, 1) }, uniquingKeysWith: +)
        let showArt = URL(string: delegate.showArt).flatMap(sharpen)
        return delegate.entries.map { e in
            guard let audio = e.audioURL else { return e }
            var one = JournalEntry(title: e.title, url: links[e.url, default: 0] > 1 ? audio.absoluteString : e.url, date: e.date,
                                   htmlContent: e.htmlContent, imageURL: e.imageURL ?? showArt, audioURL: audio)
            one.audioSeconds = e.audioSeconds
            return one
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        element = elementName
        if elementName == "entry" || elementName == "item" {
            inItem = true; title = ""; link = ""; date = ""; content = ""; summary = ""
            mediaSrc = ""; mediaWidth = -1; enclosureSrc = ""; audioSrc = ""; duration = ""; showNotes = ""
        } else if elementName == "link", inItem,
                  attributeDict["rel"] == nil || attributeDict["rel"] == "alternate",
                  let href = attributeDict["href"] {
            // Atom links carry the URL in the href attribute.
            link = href
        } else if inItem, elementName == "media:thumbnail" || elementName == "media:content" {
            // <media:thumbnail> is an image by definition; <media:content> carries video too. The widest wins
            // (the Guardian lists 140, 460 and 700 px copies).
            let w = Int(attributeDict["width"] ?? "") ?? 0
            if w > mediaWidth, let u = attributeDict["url"],
               elementName == "media:thumbnail" || Self.isImage(attributeDict, url: u) {
                mediaSrc = u; mediaWidth = w
            }
        } else if !inItem, elementName == "itunes:image", showArt.isEmpty, let u = attributeDict["href"] {
            showArt = u
        } else if inItem, elementName == "itunes:image", mediaSrc.isEmpty, let u = attributeDict["href"] {
            mediaWidth = 0
            mediaSrc = u   // podcast and some blog feeds put the episode art here
        } else if inItem, elementName == "enclosure" {
            if enclosureSrc.isEmpty, let u = attributeDict["url"], Self.isImage(attributeDict, url: u) {
                enclosureSrc = u
            } else if audioSrc.isEmpty, let u = attributeDict["url"], Self.isAudio(attributeDict, url: u) {
                audioSrc = u
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch element {
        case "title": title += string
        case "link": link += string                 // RSS puts the URL in element text
        case "published", "updated", "pubDate", "dc:date": date += string
        case "content", "content:encoded": content += string
        case "description", "summary": summary += string
        case "itunes:summary": showNotes += string
        case "itunes:duration": duration += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let s = String(data: CDATABlock, encoding: .utf8) else { return }
        switch element {
        case "content", "content:encoded": content += s
        case "description", "summary": summary += s
        case "itunes:summary": showNotes += s
        case "title": title += s
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "entry" || elementName == "item" else { return }
        inItem = false
        let audio = Self.resolve(audioSrc, against: link)
        // an episode with no page of its own is known by its audio
        let entryURL = link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (audio?.absoluteString ?? "")
            : link.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = [content, summary, showNotes].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
        var entry = JournalEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: entryURL,
            date: Self.parseDate(date.trimmingCharacters(in: .whitespacesAndNewlines)),
            htmlContent: body,
            imageURL: Self.pickImage(media: mediaSrc, enclosure: enclosureSrc,
                                     html: content + summary, entryURL: entryURL).flatMap(Self.sharpen),
            audioURL: audio
        )
        entry.audioSeconds = audio == nil ? nil : Self.seconds(duration)
        entries.append(entry)
    }

    /// "1:02:03", "16:40" or "1000" as seconds; nil when the feed gives none.
    static func seconds(_ s: String) -> Int? {
        let parts = s.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":").map { Int($0) }
        guard !parts.isEmpty, parts.count <= 3, !parts.contains(nil) else { return nil }
        let total = parts.reduce(0) { $0 * 60 + $1! }
        return total > 0 ? total : nil
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "avif"]

    /// A media/enclosure element is an image if it says so, or — when it declares neither a
    /// type nor a medium — if the URL ends in an image extension.
    static func isImage(_ attributes: [String: String], url: String) -> Bool {
        if let type = attributes["type"] { return type.lowercased().hasPrefix("image/") }
        if let medium = attributes["medium"] { return medium.lowercased() == "image" }
        let ext = (URL(string: url)?.pathExtension ?? "").lowercased()
        return imageExtensions.contains(ext)
    }

    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "ogg", "oga", "opus", "wav"]

    /// An enclosure is a podcast episode's audio if its type says audio, or, with no type, its URL ends in an
    /// audio extension. Same rule as audioFor in web/parse.js.
    static func isAudio(_ attributes: [String: String], url: String) -> Bool {
        if let type = attributes["type"] { return type.lowercased().hasPrefix("audio/") }
        return audioExtensions.contains((URL(string: url)?.pathExtension ?? "").lowercased())
    }

    private static let imgTagRegex = try? NSRegularExpression(pattern: "<img\\b[^>]*>", options: .caseInsensitive)
    private static let attrRegex = try? NSRegularExpression(
        pattern: "\\b(data-src|data-lazy-src|data-original|srcset|src)\\s*=\\s*[\"']([^\"']+)[\"']", options: .caseInsensitive)

    /// Every image URL the body offers, in order: lazy-load attributes (data-src and friends) before `src`, which
    /// is often a placeholder; the first `srcset` entry; tracking pixels (1 by 1) skipped. Mirrors `imageFor` in
    /// web/reader.js.
    static func imageSrcs(inHTML html: String) -> [String] {
        guard let tagRe = imgTagRegex, let attrRe = attrRegex else { return [] }
        let ns = html as NSString
        var out: [String] = []
        for tag in tagRe.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let t = ns.substring(with: tag.range)
            if t.range(of: #"(width|height)\s*=\s*["']?1["'\s>]"#, options: [.regularExpression, .caseInsensitive]) != nil { continue }
            let tns = t as NSString
            var found: [String: String] = [:]
            for m in attrRe.matches(in: t, range: NSRange(location: 0, length: tns.length)) {
                found[tns.substring(with: m.range(at: 1)).lowercased()] = tns.substring(with: m.range(at: 2))
            }
            for key in ["data-src", "data-lazy-src", "data-original", "src", "srcset"] {
                guard var v = found[key] else { continue }
                if key == "srcset" { v = String(v.split(separator: ",").first?.split(separator: " ").first ?? "") }
                out.append(v)
            }
        }
        return out
    }

    /// Resolve a feed-supplied src against the entry link. Handles protocol-relative
    /// (`//host/x.jpg`) and plain relative paths, and refuses anything that is not http(s)
    /// so `data:` blobs never reach AsyncImage.
    static func resolve(_ src: String, against base: String) -> URL? {
        let s = src.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let baseURL = URL(string: base)
        let resolved: URL?
        if s.hasPrefix("//") {
            resolved = URL(string: (baseURL?.scheme ?? "https") + ":" + s)
        } else if let u = URL(string: s), u.scheme != nil {
            resolved = u
        } else {
            resolved = URL(string: s, relativeTo: baseURL)?.absoluteURL
        }
        guard let out = resolved, let scheme = out.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        return out
    }

    /// media:* wins over <enclosure>, which wins over the first <img> in the body.
    /// No match means no thumbnail — never a placeholder URL.
    /// BBC feeds point at a 240 px copy; the same path serves 976 px. NY Post escapes its whole path and query
    /// ("wp-content%2F...?w%3D1024"), so the resize never applies and a 5000 px original loads; unescape it.
    /// Mirrors sharpen in web/parse.js.
    /// Pictures load over https (the apps' ATS refuses plain http; BBC podcast art is http), and BBC podcast art asks for
    /// 480 px instead of 3000.
    static func sharpen(_ url: URL) -> URL? {
        var s = url.absoluteString.replacingOccurrences(of: #"(ichef\.bbci\.co\.uk/(?:ace/\w+|news))/\d+/"#, with: "$1/976/", options: .regularExpression)
            .replacingOccurrences(of: #"^http://"#, with: "https://", options: .regularExpression)
            .replacingOccurrences(of: #"(ichef\.bbci\.co\.uk/images/ic)/\d+x\d+/"#, with: "$1/480x480/", options: .regularExpression)
        if let r = s.range(of: #"^https?://[^/]+/"#, options: .regularExpression), s[r.upperBound...].contains("%2F"),
           let rest = s[r.upperBound...].removingPercentEncoding {
            s = String(s[..<r.upperBound]) + rest
        }
        return URL(string: s) ?? url
    }

    static func pickImage(media: String, enclosure: String, html: String, entryURL: String) -> URL? {
        for candidate in [media, enclosure] where !candidate.isEmpty {
            if let u = resolve(candidate, against: entryURL) { return u }
        }
        return imageSrcs(inHTML: html).lazy.compactMap { resolve($0, against: entryURL) }.first
    }

    /// Accept both ISO8601 (Atom) and RFC822 (RSS pubDate). Two RFC822 shapes, because the
    /// zone is written either as an offset (`-0400`) or as a name (`EDT`, `GMT`) and `Z`
    /// only reads the offset form — CBC ships named zones, so one format is not enough.
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
        // ponytail: sink undated entries rather than defaulting to `Date()`. Entries are
        // sorted newest-first, so "now" would pin every unparseable entry above real news
        // forever — a whole feed's worth, if that feed uses a format we miss.
        return .distantPast
    }
}
