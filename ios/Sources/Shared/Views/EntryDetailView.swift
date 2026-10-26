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
    /// The system text size on top of the reader's own: 17 at the default, larger with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var body17 = 17.0
    @StateObject private var listener = Listener()
    /// A podcast episode's own audio (EpisodeBar); articles get Listen instead.
    @StateObject private var player = Player()
    /// The page's own text when the feed only sent a summary (FullText).
    @State private var full: JournalEntry?

    var body: some View {
        let size = textSize * body17 / 17
        ArticleWebView(html: Self.page(for: full ?? entry, textSize: size), baseURL: URL(string: entry.url))
            .id("\(size) \(full != nil)")  // a new size or the full text rebuilds the page; it never reloads on its own
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(entry.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { library.markRead(entry) }
            .task { full = await FullText.fill(entry) }
            .onDisappear { listener.stop(); player.stop() }
            .task(id: entry.id) {
                player.prepare(entry)
                if CommandLine.arguments.contains("-playEpisode") { player.play() }   // screenshot and QA hook
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { if entry.audioURL != nil { EpisodeBar(player: player) } }
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
                        if entry.audioURL == nil {
                            Button { listener.toggle(full ?? entry) } label: {
                                Label(listener.speaking ? "Stop" : "Listen", systemImage: listener.speaking ? "stop.fill" : "speaker.wave.2")
                            }
                            .keyboardShortcut("l")
                        }
                        ShareLink(item: url)
                        Link(destination: url) { Label("Open in Browser", systemImage: "safari") }
                            .keyboardShortcut("o", modifiers: [.command, .shift])
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

/// The episode's controls under its show notes, like Apple Podcasts' player: the scrubber with elapsed and left, then
/// speed, back 15, play, forward 30. Glass over the page, 48 point targets.
struct EpisodeBar: View {
    @ObservedObject var player: Player

    var body: some View {
        VStack(spacing: 4) {
            Slider(value: $player.elapsed, in: 0...max(player.duration, player.elapsed, 1)) { editing in
                player.scrubbing = editing
                if !editing { player.seek(to: player.elapsed) }
            }
            .accessibilityLabel("Position")
            .accessibilityValue(clock(player.elapsed))
            HStack {
                Text(clock(player.elapsed))
                Spacer()
                Text(player.duration > 0 ? "-" + clock(player.duration - player.elapsed) : "")
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack {
                Button { player.nextRate() } label: {
                    Text(String(format: "%g\u{00D7}", player.rate)).font(.subheadline.weight(.semibold))
                        .frame(width: 48, height: 48, alignment: .leading).contentShape(Rectangle())
                }
                .accessibilityLabel("Speed")
                .accessibilityValue(String(format: "%g", player.rate))
                Spacer()
                Button { player.skip(-15) } label: { Image(systemName: "gobackward.15").font(.title2) }
                    .accessibilityLabel("Back 15 seconds")
                Spacer()
                Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.largeTitle) }
                    .accessibilityLabel(player.playing ? "Pause" : "Play")
                    .keyboardShortcut("l")
                Spacer()
                Button { player.skip(30) } label: { Image(systemName: "goforward.30").font(.title2) }
                    .accessibilityLabel("Forward 30 seconds")
                Spacer()
                Color.clear.frame(width: 48, height: 1)   // balances the speed button so play sits in the middle
            }
            .buttonStyle(.plain)
            .frame(minHeight: 48)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .background(.regularMaterial)
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
