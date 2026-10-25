import Foundation

/// Short, clean list titles (Joshua 2026-10-25: "shorten the title names and simplify them, there shouldn't be … at
/// the end"). `variants` runs longest to shortest; the list shows the first one that fits on one line, so a title is
/// cut at a clause or a whole word instead of trailing off. The reader still shows the full title.
/// Mirrors `web/headline.js`; change both or neither.
enum Headline {
    /// Section tags, the outlet's own name and asides, gone.
    static func clean(_ title: String, source: String = "") -> String {
        var t = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        // "Opinion | ...", "WATCH: ...", "Breaking - ..."
        t = t.replacingOccurrences(of: #"^(opinion|analysis|watch|live|breaking|exclusive|update|video|explainer|editorial)\s*[:|\-–—]\s*"#,
                                   with: "", options: [.regularExpression, .caseInsensitive])
        // "... | BBC News", "... - The Guardian"
        if !source.isEmpty {
            let name = NSRegularExpression.escapedPattern(for: source)
            t = t.replacingOccurrences(of: #"\s+[|\-–—]\s+(the\s+)?"# + name + #"(\s+news)?\s*$"#,
                                       with: "", options: [.regularExpression, .caseInsensitive])
        }
        t = t.replacingOccurrences(of: #"\s*[(\[][^)\]]*[)\]]"#, with: "", options: .regularExpression)   // (asides), [Video]
        return trimTail(t)
    }

    /// The clean title, then cuts at a clause (": ", " — ", ", ", " as "...), longest first, then whole-word cuts.
    /// A natural break beats squeezing in two more words.
    static func variants(_ title: String, source: String = "") -> [String] {
        let full = clean(title, source: source)
        var clauses: [String] = []
        for sep in [": ", " — ", " – ", " - ", " | ", ", ", "; ", " as ", " after ", " amid ", " while ", " but "] {
            guard let r = full.range(of: sep) else { continue }
            let head = trimTail(String(full[..<r.lowerBound]))
            if head.split(separator: " ").count >= 3 { clauses.append(head) }   // "Show HN: ..." keeps its colon
        }
        var out = [full] + clauses.sorted { $0.count > $1.count }
        // Word cuts come from the shortest clause, so a squeeze never drags the tail of the sentence back in.
        let words = (out.last ?? full).split(separator: " ").map(String.init)
        if words.count > 2 {
            // Cut only where the next word starts a new phrase ("cars | that put", "drivers | at greatest"), so a cut
            // ends on a whole idea; with no such break, any word will do.
            let breaks = (3..<words.count).filter { phraseStarts.contains(words[$0].lowercased().trimmingCharacters(in: .punctuationCharacters)) }
            let cuts = Array(stride(from: words.count - 1, through: 2, by: -1))
            // phrase breaks first; plain word cuts after them, as the last resort for a narrow row
            for n in cuts.filter({ breaks.contains($0) }) + cuts.filter({ !breaks.contains($0) }) {
                out.append(trimTail(words.prefix(n).joined(separator: " ")))
            }
        }
        var seen = Set<String>()
        return out.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Words that open a new phrase: a cut just before one ends on a whole idea.
    private static let phraseStarts: Set<String> = ["to", "of", "in", "on", "at", "by", "for", "from", "with", "and", "or", "but", "as", "after", "amid", "over", "that", "who", "which", "whose", "into", "about", "than", "while", "when", "where", "vs", "because", "before", "during", "until", "against", "without", "under", "near"]

    /// A cut never ends on "to", "the", "of" or a dangling comma.
    private static let filler: Set<String> = ["a", "an", "the", "to", "of", "in", "on", "at", "by", "for", "from", "with",
                                              "and", "or", "but", "as", "is", "are", "was", "his", "her", "its", "their", "after", "amid", "over",
                                              "vs", "v", "that", "who", "which", "whose", "other", "how", "what", "when", "where", "why", "into", "up", "about", "than", "this", "these", "those", "your", "my", "our", "be", "has", "have", "had", "will", "would", "can", "could", "not", "no", "more", "most", "very", "just", "&", "new", "top", "mr", "mrs", "ms", "dr", "sgt", "gov", "sen", "rep", "pres", "gen", "lt", "col", "capt", "st", "prof", "u.s"]
    private static func trimTail(_ s: String) -> String {
        var words = s.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        while words.count > 1 {
            let last = words[words.count - 1].trimmingCharacters(in: .punctuationCharacters).lowercased()
            if filler.contains(last) || last.isEmpty { words.removeLast() } else { break }
        }
        var t = words.joined(separator: " ")
        while let c = t.last, ",;:|-–—".contains(c) { t.removeLast(); t = t.trimmingCharacters(in: .whitespaces) }
        return t
    }
}

#if DEBUG
/// ponytail: minimal self-check, same style as `feedParserDemo()`.
func headlineDemo() {
    assert(Headline.clean("Opinion | Congress’s Russia Problems") == "Congress’s Russia Problems")
    assert(Headline.clean("Storm hits coast - BBC News", source: "BBC") == "Storm hits coast")
    assert(Headline.clean("Rates fall (again) [Video]") == "Rates fall")
    let v = Headline.variants("Jaylen Brown ratchets up Jayson Tatum drama: ‘He should stay ready at all times’")
    assert(v.contains("Jaylen Brown ratchets up Jayson Tatum drama"))
    assert(Headline.variants("Show HN: I put employees inside S&P 500 bubbles").contains { $0.hasPrefix("Show HN:") })
    assert(!v.contains { ["to", "the", "of", "at"].contains($0.split(separator: " ").last.map(String.init) ?? "") })
    assert(v.first?.hasSuffix("times’") == true && v[1] == "Jaylen Brown ratchets up Jayson Tatum drama")
}
#endif
