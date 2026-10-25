import SwiftUI
import WebKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct EntryDetailView: View {
    let entry: JournalEntry
    @ObservedObject var library: Library
    var story: Story? = nil
    @State private var showCoverage = CommandLine.arguments.contains("-showCoverage")
    @AppStorage("readerTextSize") private var textSize = 17.0
    @StateObject private var listener = Listener()

    var body: some View {
        ArticleWebView(html: Self.page(for: entry, textSize: textSize), baseURL: URL(string: entry.url))
            .id(textSize)  // a new size rebuilds the page; the web view never reloads on its own
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(entry.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { library.markRead(entry) }
            .onDisappear { listener.stop() }
            .sheet(isPresented: $showCoverage) { if let story { CoverageView(story: story, library: library) } }
            .toolbar {
                if let url = URL(string: entry.url) {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if let story, story.entries.count > 1 {
                            Button { showCoverage = true } label: { Label("\(story.publishers) Sources", systemImage: "square.stack") }
                        }
                        Button { library.toggleSave(entry) } label: {
                            Label(library.isSaved(entry) ? "Remove from Saved" : "Save", systemImage: library.isSaved(entry) ? "bookmark.fill" : "bookmark")
                        }
                        Button { listener.toggle(entry) } label: {
                            Label(listener.speaking ? "Stop" : "Listen", systemImage: listener.speaking ? "stop.fill" : "speaker.wave.2")
                        }
                        ShareLink(item: url)
                        Link(destination: url) { Label("Open in Browser", systemImage: "safari") }
                    }
                }
            }
    }

    // ponytail: WKWebView instead of NSAttributedString's HTML importer. The importer
    // turns <img> into an NSTextAttachment, and SwiftUI's Text renders *nothing* for an
    // AttributedString containing one — every post starting with a banner image came up
    // blank. A web view also gets images, code blocks and links for free.
    private static func page(for entry: JournalEntry, textSize: Double) -> String {
        """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="supported-color-schemes" content="light dark">
        <style>
          :root { color-scheme: light dark; }
          /* Feed HTML is arbitrary: fixed-width cards, wide tables and long
             unbroken URLs all used to push the body past the viewport and clip
             at the right edge. Clamp every element to its parent and let the
             genuinely wide blocks scroll inside themselves instead. */
          * { max-width: 100%; box-sizing: border-box; }
          body {
            font: -apple-system-body;
            font-family: -apple-system, system-ui;
            font-size: \(Int(textSize))px; line-height: 1.5;
            margin: 0; padding: 16px 20px 40px;
            -webkit-text-size-adjust: 100%;
            overflow-wrap: break-word;
          }
          h1 { font-size: 1.4em; margin: 0 0 4px; }
          h2 { font-size: 1.2em; margin: 24px 0 8px; }
          h3 { font-size: 1.05em; margin: 20px 0 8px; }
          p { margin: 0 0 14px; }
          img { max-width: 100%; height: auto; border-radius: 12px; }
          pre, table, blockquote { display: block; overflow-x: auto; }
          code { font-size: 0.9em; }
          .date { color: gray; font-size: 13px; margin: 0 0 20px; }
          /* links in the brand blue, not WebKit's default purple; Theme.swift bugleAccent */
          a { color: #0059B3; }
          @media (prefers-color-scheme: dark) { a { color: #5aa9ff; } }
          .hero { width: 100%; max-height: 50vh; object-fit: cover; border-radius: 12px; margin: 0 0 16px; }
        </style></head><body>
        <h1>\(escape(entry.title))</h1>
        <p class="date">\(byline(for: entry))</p>
        \(heroImage(for: entry))
        \(entry.htmlContent)
        </body></html>
        """
    }

    private static func byline(for entry: JournalEntry) -> String {
        let dateString = entry.date.formatted(date: .long, time: .omitted)
        return [escape(entry.sourceTitle), dateString, entry.readingTime ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func heroImage(for entry: JournalEntry) -> String {
        guard let url = entry.imageURL else { return "" }
        return "<img class=\"hero\" src=\"\(escape(url.absoluteString))\">"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

// ponytail: one Coordinator, two thin platform shims — AppKit and UIKit differ only in
// the make/update method names and the open-URL call.
private struct ArticleWebView {
    let html: String
    let baseURL: URL?

    func make() -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = Self.sharedDelegate
        view.loadHTMLString(html, baseURL: baseURL)
        return view
    }

    static let sharedDelegate = Delegate()

    final class Delegate: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Tapped links go to the system browser; the web view only ever shows the article.
            if action.navigationType == .linkActivated, let url = action.request.url {
                #if os(iOS)
                UIApplication.shared.open(url)
                #else
                NSWorkspace.shared.open(url)
                #endif
                return decisionHandler(.cancel)
            }
            decisionHandler(.allow)
        }
    }
}

#if os(iOS)
extension ArticleWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let v = make(); v.isOpaque = false; v.backgroundColor = .clear; return v
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#else
extension ArticleWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { make() }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#endif
