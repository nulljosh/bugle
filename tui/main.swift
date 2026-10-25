import Foundation
import SwiftTUI

// ponytail: Foundation's XMLParser (native, no dependency) is enough to pull item
// titles out of RSS/Atom — a real feed parser is bugle's own job, this just proves
// the terminal client can list a feed. `bugle-tui <feed-url>` fetches through the
// same CORS proxy the web reader uses.

final class TitleExtractor: NSObject, XMLParserDelegate {
    var titles: [String] = []
    private var inItem = false
    private var inTitle = false
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if name == "item" || name == "entry" { inItem = true }
        if inItem && name == "title" { inTitle = true; buffer = "" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTitle { buffer += string }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if inTitle && name == "title" {
            titles.append(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
            inTitle = false
        }
        if name == "item" || name == "entry" { inItem = false }
    }
}

let args = CommandLine.arguments.dropFirst()
guard let feedURL = args.first,
      let encoded = feedURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
      let proxyURL = URL(string: "https://bugle.jaybulb.com/feed?url=\(encoded)") else {
    print("usage: bugle-tui <feed-url>")
    exit(1)
}

func fetchTitles() async -> [String] {
    guard let (data, _) = try? await URLSession.shared.data(from: proxyURL) else { return [] }
    let extractor = TitleExtractor()
    let parser = XMLParser(data: data)
    parser.delegate = extractor
    parser.parse()
    return extractor.titles
}

struct FeedCard: View {
    let titles: [String]

    var body: some View {
        VStack(alignment: .leading) {
            Text("bugle").bold()
            if titles.isEmpty {
                Text("No items — check the feed URL")
            } else {
                ForEach(titles.prefix(10), id: \.self) { t in Text(t) }
            }
        }
        .padding()
        .border()
    }
}

let semaphore = DispatchSemaphore(value: 0)
var titles: [String] = []
Task {
    titles = await fetchTitles()
    semaphore.signal()
}
semaphore.wait()

Application(rootView: FeedCard(titles: titles)).start()
