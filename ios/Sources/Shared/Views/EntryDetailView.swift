import SwiftUI
import WebKit
import Translation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct EntryDetailView: View {
    let entry: JournalEntry
    @ObservedObject var library: Library
    var story: Story? = nil
    /// The stories above and below this one in the list it came from, for the up and down arrows (NetNewsWire's).
    var stepper: StoryStepper? = nil
    @State private var translating = false
    @State private var showCoverage = CommandLine.arguments.contains("-showCoverage")
    @AppStorage("readerTextSize") private var textSize = 17.0
    @AppStorage("readerTheme") private var readerTheme = ReaderTheme.auto.rawValue
    /// The system text size on top of the reader's own: 17 at the default, larger with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var body17 = 17.0
    @StateObject private var listener = Listener()
    /// A podcast episode's own audio (EpisodeBar); articles get Listen instead.
    @ObservedObject private var player = Player.shared
    @ObservedObject private var downloads = Downloads.shared
    /// The page's own text when the feed only sent a summary (FullText).
    @State private var full: JournalEntry?

    var body: some View {
        let size = textSize * body17 / 17
        let theme = ReaderTheme(rawValue: readerTheme) ?? .auto
        ArticleWebView(html: Self.page(for: full ?? entry, textSize: size, theme: theme), baseURL: URL(string: entry.url))
            .id("\(size) \(full != nil) \(readerTheme)")
            .background(theme.page.ignoresSafeArea())
            #if os(iOS)
            .toolbarColorScheme(theme == .auto ? nil : theme == .light ? .light : .dark, for: .navigationBar)   // the bar matches the page
            #endif  // a new size or the full text rebuilds the page; it never reloads on its own
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(entry.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { library.markRead(entry) }
            .task { full = await FullText.fill(entry) }
            .onDisappear { listener.stop() }   // an episode keeps playing; the mini player has it
            .task(id: entry.id) {   // screenshot and QA hooks
                if CommandLine.arguments.contains("-downloadEpisode") { await downloads.download(entry) }
                if CommandLine.arguments.contains("-cueEpisode") { player.cue(entry) }   // the player bar, paused and silent
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { if entry.audioURL != nil { EpisodeBar(player: player, entry: entry) } }
            .handsOff(entry)
            .sheet(isPresented: $showCoverage) { if let story { CoverageView(story: story, library: library) } }
            .toolbar {
                if let url = URL(string: entry.url) {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if let story, story.entries.count > 1 || !Archive.earlier(story).isEmpty {
                            Button { showCoverage = true } label: { Label("\(story.publishers) Sources", systemImage: "square.stack") }
                        }
                        Button { library.toggleSave(entry) } label: {
                            Label(library.isSaved(entry) ? "Remove from Saved" : "Save", systemImage: library.isSaved(entry) ? "bookmark.fill" : "bookmark")
                        }
                        .keyboardShortcut("s")
                        if entry.audioURL != nil {
                            if downloads.busy.contains(entry.id) {
                                ProgressView().accessibilityLabel("Downloading")
                            } else {
                                let saved = downloads.file(entry) != nil
                                Button { downloads.toggle(entry) } label: {
                                    Label(saved ? "Remove Download" : "Download", systemImage: saved ? "arrow.down.circle.fill" : "arrow.down.circle")
                                }
                            }
                        }
                        if entry.audioURL == nil {
                            Button { listener.toggle(full ?? entry) } label: {
                                Label(listener.speaking ? "Stop" : "Listen", systemImage: listener.speaking ? "stop.fill" : "speaker.wave.2")
                            }
                            .keyboardShortcut("l")
                        }
                        ShareLink(item: url)
                    }
                    if let stepper {
                        // beside the back button on iOS, where the trailing actions leave room; in the toolbar on the Mac
                        ToolbarItemGroup(placement: Self.stepPlacement) {
                            Button { stepper.prev.map(stepper.open) } label: { Label("Previous Story", systemImage: "chevron.up") }
                                .disabled(stepper.prev == nil)
                                .keyboardShortcut(.upArrow, modifiers: .command)
                            Button { stepper.next.map(stepper.open) } label: { Label("Next Story", systemImage: "chevron.down") }
                                .disabled(stepper.next == nil)
                                .keyboardShortcut(.downArrow, modifiers: .command)
                        }
                    }
                    ToolbarItemGroup(placement: .secondaryAction) {
                        Picker(selection: $readerTheme) {
                            ForEach(ReaderTheme.allCases) { Text($0.title).tag($0.rawValue) }
                        } label: { Label("Theme", systemImage: "circle.lefthalf.filled") }
                        if #available(iOS 17.4, macOS 14.4, *) {
                            Button { translating = true } label: { Label("Translate", systemImage: "translate") }
                        }
                        Link(destination: url) { Label("Open in Browser", systemImage: "safari") }
                            .keyboardShortcut("o", modifiers: [.command, .shift])
                    }
                }
            }
            .translates(Headline.clean(entry.title, source: entry.sourceTitle) + "\n\n" + (full ?? entry).plainText, isPresented: $translating)
    }

    #if os(iOS)
    private static let stepPlacement = ToolbarItemPlacement.topBarLeading
    #else
    private static let stepPlacement = ToolbarItemPlacement.primaryAction
    #endif

    // ponytail: WKWebView instead of NSAttributedString's HTML importer. The importer
    // turns <img> into an NSTextAttachment, and SwiftUI's Text renders *nothing* for an
    // AttributedString containing one — every post starting with a banner image came up
    // blank. A web view also gets images, code blocks and links for free.
    private static func page(for entry: JournalEntry, textSize: Double, theme: ReaderTheme = .auto) -> String {
        let pinned = theme.colors.map { c in
            "html, body { background: \(c.bg); color: \(c.text); color-scheme: \(theme == .light ? "light" : "dark"); } .date { color: \(c.sub); } a, a:visited { color: \(c.link) !important; }"
        } ?? ""
        return """
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
            margin: 0; padding: 16px 20px \(entry.audioURL == nil ? 40 : 160)px;
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
          \(pinned)
          .hero { width: 100%; max-height: 50vh; object-fit: cover; border-radius: 12px; margin: 0 0 16px; }
          .art { width: 160px; height: 160px; object-fit: cover; border-radius: 16px; margin: 0 0 16px; }   /* podcast art */
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
        return [escape(entry.sourceTitle), dateString, entry.listenTime ?? entry.readingTime ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func heroImage(for entry: JournalEntry) -> String {
        guard let url = entry.imageURL else { return "" }
        return "<img class=\"\(entry.audioURL == nil ? "hero" : "art")\" src=\"\(escape(url.absoluteString))\">"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

/// The stories either side of this one in its list, and how to open one in its place.
struct StoryStepper {
    let prev: JournalEntry?
    let next: JournalEntry?
    let open: (JournalEntry) -> Void
}

extension View {
    /// The system Translate sheet over the story's own text, on device (iOS 17.4 and macOS 14.4 or later).
    @ViewBuilder func translates(_ text: String, isPresented: Binding<Bool>) -> some View {
        if #available(iOS 17.4, macOS 14.4, *) { translationPresentation(isPresented: isPresented, text: text) } else { self }
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
