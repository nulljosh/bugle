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
    /// An episode's cover color, which tints the player's glass.
    @State private var art: Color?
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
    /// The feed sent next to nothing (Hacker News sends only links) and the page had no article to pull: show the page.
    @State private var livePage = false
    /// A Hacker News story's comment thread, under the article.
    @State private var comments: String?

    var body: some View {
        let size = textSize * body17 / 17
        let theme = ReaderTheme(rawValue: readerTheme) ?? .auto
        let hn = HNComments.id(entry) != nil
        // an HN story is its article and its thread; the feed's own body is only links
        let body = full ?? (hn ? JournalEntry(title: entry.title, url: entry.url, date: entry.date,
            htmlContent: "<p><a href=\"\(Self.escape(entry.url))\">\(Self.escape(URL(string: entry.url)?.host() ?? entry.url))</a></p>", sourceTitle: entry.sourceTitle) : entry)
        ArticleWebView(html: Self.page(for: body, textSize: size, theme: theme, extra: comments ?? ""), baseURL: URL(string: entry.url), underBars: entry.audioURL != nil,
                       page: livePage ? URL(string: entry.url) : nil)
            .id("\(size) \(full != nil) \(readerTheme) \(livePage) \(comments != nil)")
            .background(theme.page.ignoresSafeArea())
            #if os(iOS)
            .toolbarColorScheme(theme == .auto ? nil : theme == .light ? .light : .dark, for: .navigationBar)   // the bar matches the page
            #endif  // a new size or the full text rebuilds the page; it never reloads on its own
            .ignoresSafeArea(edges: entry.audioURL != nil ? .vertical : .bottom)   // an episode's cover runs up under the glass bar
            .navigationTitle(entry.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { library.markRead(entry) }
            .task {
                async let thread = HNComments.html(entry)
                full = await FullText.fill(entry)
                comments = await thread
                livePage = full == nil && comments == nil && HNComments.id(entry) == nil && entry.audioURL == nil
                    && entry.plainText.split(separator: " ").count < 40
            }
            .onDisappear { listener.stop() }   // an episode keeps playing; the mini player has it
            .task(id: entry.id) {
                if entry.audioURL != nil, let u = entry.imageURL { art = await ArtColor.of(u) }
            }
            .task(id: entry.id) {   // screenshot and QA hooks
                if CommandLine.arguments.contains("-downloadEpisode") { await downloads.download(entry) }
                if CommandLine.arguments.contains("-cueEpisode") { player.cue(entry) }   // the player bar, paused and silent
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { if entry.audioURL != nil { EpisodeBar(player: player, entry: entry, tint: art) } }
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
    private static func page(for entry: JournalEntry, textSize: Double, theme: ReaderTheme = .auto, extra: String = "") -> String {
        let pinned = theme.colors.map { c in
            "html, body { background: \(c.bg); color: \(c.text); color-scheme: \(theme == .light ? "light" : "dark"); } .date { color: \(c.sub); } a, a:visited { color: \(c.link) !important; }"
        } ?? ""
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
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
          .c { margin: 0 0 16px; } .c.r { margin-left: 16px; } .c > .date { margin: 0 0 4px; }   /* HN comments */
          .hero { width: 100%; max-height: 50vh; object-fit: cover; border-radius: 12px; margin: 0 0 16px; }
          /* An episode's cover as the hero, Apple Podcasts style: the art blurred across the top third, under the glass
             bar, fading into the page, with the sharp square centered on it. */
          .cover { position: relative; max-width: none; height: 38vh; margin: -16px -20px 16px; padding: calc(env(safe-area-inset-top) + 8px) 0 16px;
                   display: flex; justify-content: center; align-items: center; }
          .cover::before { content: ""; position: absolute; inset: 0; background: var(--art) center / cover; filter: blur(48px) saturate(1.6);
                           transform: translateY(calc(var(--y, 0) * .5px)) scale(calc(1.3 + var(--pull, 0) / 300)); opacity: .9; -webkit-mask-image: linear-gradient(#000 55%, transparent); }
          .cover img { position: relative; height: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 16px;
                       box-shadow: 0 12px 32px rgba(0, 0, 0, .3);
                       transform: translateY(calc(var(--y, 0) * .3px)) scale(calc(1 - var(--y, 0) / 1500)); opacity: calc(1 - var(--y, 0) / 400); }
        </style></head><body>
        \(entry.audioURL != nil ? heroImage(for: entry) : "")
        <h1>\(escape(entry.title))</h1>
        <p class="date">\(byline(for: entry))</p>
        \(entry.audioURL == nil ? heroImage(for: entry) : "")
        \(entry.htmlContent)
        \(extra)
        \(scrollHook)
        \(entry.audioURL != nil ? parallax : "")
        </body></html>
        """
    }

    /// The hero's parallax: the blur moves at half the scroll, the art a third and fades, a pull past the top swells
    /// the blur. Off under Reduce Motion.
    private static let parallax = """
    <script>
    if (!matchMedia('(prefers-reduced-motion: reduce)').matches) {
      const root = document.documentElement.style; let queued = false
      addEventListener('scroll', () => {
        if (queued) return; queued = true
        requestAnimationFrame(() => {
          const y = scrollY; queued = false
          root.setProperty('--y', Math.max(0, Math.min(y, 400))); root.setProperty('--pull', Math.max(0, -y))
        })
      }, { passive: true })
    }
    </script>
    """

    /// QA: `-scrollTo N` opens the page scrolled N points down (the thread, the hero mid-parallax).
    private static var scrollHook: String {
        guard let i = CommandLine.arguments.firstIndex(of: "-scrollTo"), let y = CommandLine.arguments.dropFirst(i + 1).first.flatMap({ Int($0) }) else { return "" }
        return "<script>addEventListener('load', () => setTimeout(() => scrollTo(0, \(y)), 300))</script>"
    }

    private static func byline(for entry: JournalEntry) -> String {
        let dateString = entry.date.formatted(date: .long, time: .omitted)
        return [escape(entry.sourceTitle), dateString, entry.listenTime ?? entry.readingTime ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func heroImage(for entry: JournalEntry) -> String {
        guard let url = entry.imageURL else { return "" }
        let src = escape(HiRes.upsize(url).absoluteString)   // both heroes are phone-wide: ask for the big copy
        guard entry.audioURL != nil else { return "<img class=\"hero\" src=\"\(src)\">" }
        return "<div class=\"cover\" style=\"--art: url('\(src.replacingOccurrences(of: "'", with: "%27"))')\"><img src=\"\(src)\" alt=\"\"></div>"
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
    /// The page runs under the bars and lays itself out with safe-area padding (an episode's cover hero).
    var underBars = false
    /// A live page to load instead of the html.
    var page: URL? = nil

    func make() -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = Self.sharedDelegate
        if let page { view.load(URLRequest(url: page)) } else { view.loadHTMLString(html, baseURL: baseURL) }
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
        let v = make(); v.isOpaque = false; v.backgroundColor = .clear
        if underBars { v.scrollView.contentInsetAdjustmentBehavior = .never }
        return v
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#else
extension ArticleWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { make() }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#endif
