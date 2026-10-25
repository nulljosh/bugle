import Foundation

/// The last catch for a story with no image in its feed: the article page's own preview image (`og:image`, then
/// `twitter:image`), the one a link shows when you share it. Reads only the top of the page, and remembers every
/// answer (a miss too) so a page is asked once. Mirrors `functions/og.js`, which does the same for the web.
enum PreviewImage {
    private static let key = "previewImages"
    private static let headBytes = 256 * 1024
    @MainActor private static var cache: [String: String] = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    @MainActor private static var inFlight: [String: Task<URL?, Never>] = [:]

    @MainActor
    static func lookup(_ page: String) async -> URL? {
        if let hit = cache[page] { return hit.isEmpty ? nil : URL(string: hit) }
        if let running = inFlight[page] { return await running.value }
        let task = Task { await fetch(page) }
        inFlight[page] = task
        let found = await task.value
        inFlight[page] = nil
        cache[page] = found?.absoluteString ?? ""
        // ponytail: one dictionary in UserDefaults, capped at 2000 pages by dropping arbitrary ones; an LRU if it matters.
        if cache.count > 2000 { cache = Dictionary(uniqueKeysWithValues: cache.suffix(2000).map { ($0.key, $0.value) }) }
        UserDefaults.standard.set(cache, forKey: key)
        return found
    }

    private static func fetch(_ page: String) async -> URL? {
        guard let url = URL(string: page), url.scheme == "https" || url.scheme == "http" else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15 Bugle/1.0 (+https://bugle.jaybulb.com)", forHTTPHeaderField: "User-Agent")
        guard let (bytes, _) = try? await URLSession.shared.bytes(for: req) else { return nil }
        var data = Data()
        do {
            for try await b in bytes {
                data.append(b)
                if data.count >= headBytes { break }
            }
        } catch { return nil }
        return image(inHTML: String(decoding: data, as: UTF8.self), base: url)
    }

    /// `<meta property="og:image" content="...">` in either attribute order, then twitter:image.
    static func image(inHTML html: String, base: URL) -> URL? {
        for name in ["og:image:secure_url", "og:image", "twitter:image", "twitter:image:src"] {
            let n = NSRegularExpression.escapedPattern(for: name)
            let patterns = [#"<meta[^>]+(?:property|name)\s*=\s*["']"# + n + #"["'][^>]*content\s*=\s*["']([^"']+)["']"#,
                            #"<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]*(?:property|name)\s*=\s*["']"# + n + #"["']"#]
            for p in patterns {
                guard let re = try? NSRegularExpression(pattern: p, options: .caseInsensitive),
                      let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                      let r = Range(m.range(at: 1), in: html) else { continue }
                let raw = html[r].replacingOccurrences(of: "&amp;", with: "&")
                if let u = URL(string: raw, relativeTo: base)?.absoluteURL, u.scheme == "https" || u.scheme == "http" { return u }
            }
        }
        return nil
    }
}

#if DEBUG
func previewImageDemo() {
    let base = URL(string: "https://example.com/a/story")!
    assert(PreviewImage.image(inHTML: #"<meta property="og:image" content="https://x.com/i.jpg?a=1&amp;b=2">"#, base: base)?.absoluteString == "https://x.com/i.jpg?a=1&b=2")
    assert(PreviewImage.image(inHTML: #"<meta content="/img/p.png" name="twitter:image">"#, base: base)?.absoluteString == "https://example.com/img/p.png")
    assert(PreviewImage.image(inHTML: "<title>none</title>", base: base) == nil)
}
#endif
