#if DEBUG
import SwiftUI
import AppKit
import WebKit

/// Headless App Store screenshot capture for the Mac app.
///
/// ponytail: an offscreen window rendered into a bitmap, not a screen grab. `screencapture`
/// and CGWindowList both want Screen Recording permission and an interactive prompt, and
/// driving the real UI would need System Events, which the house rule forbids. Hosting the
/// same views in an offscreen `NSWindow` and calling `cacheDisplay` needs no permissions, no
/// window IDs and no timing races — and it captures WKWebView content, which `ImageRenderer`
/// cannot do at all (the reading view is a web view).
///
///     Bugle --capture list
///
/// Frames come out at exactly 1280x800 with alpha flattened, which is what App Store Connect
/// accepts for macOS. The app is sandboxed and cannot write outside its container, so the PNG
/// lands in the container's temp directory and the absolute path is printed on stdout —
/// `scripts/capture-mac-shots.sh` copies it into place.
enum ScreenshotCapture {
    /// App Store's smallest accepted macOS size. This is the *content* size: the title bar is
    /// deliberately outside the shot. `cacheDisplay` does not render NSToolbar item contents —
    /// the Feeds button comes out as a blank white pill — so including the chrome would ship a
    /// rendering artifact. Content-only is clean, and the feeds screen gets its own frame.
    static let size = NSSize(width: 1280, height: 800)

    enum State: String, CaseIterable {
        case list, article, feeds
    }

    /// Returns false when the process was launched normally, so `main` can carry on.
    @MainActor
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--capture") else { return false }
        guard flag + 1 < args.count, let state = State(rawValue: args[flag + 1]) else {
            fail("usage: --capture <\(State.allCases.map(\.rawValue).joined(separator: "|"))>")
        }
        capture(state: state)
        return true
    }

    @MainActor
    private static func capture(state: State) {
        NSApplication.shared.setActivationPolicy(.regular)

        // Warm the on-disk entry cache first. `JournalFeedService.init` reads it, so the view
        // has real content the moment it is hosted instead of racing its own `.task`.
        let store = FeedStore()
        let service = JournalFeedService()
        // Trim the subscriptions before anything renders. The list view refreshes from this
        // store, so without the trim it refetches all seventeen seeds and undoes the curation;
        // and the feeds screen gets a real Following/Suggested split instead of one flat list.
        // This writes feeds.json in the app's sandbox container — DEBUG-only, and the Mac app
        // has never shipped, so there is no real subscription list to disturb.
        store.feeds = store.feeds.filter { listSources.contains($0.title) }

        var article: JournalEntry?
        if state != .feeds {
            await_ { await service.refresh(feeds: store.feeds) }
            if service.entries.isEmpty {
                fail("no entries fetched — check the network before trusting this frame")
            }
            article = pickArticle(from: service.entries)
        }

        let window = makeWindow()
        switch state {
        case .list:
            window.contentViewController = NSHostingController(
                rootView: EntryListView(feed: service, store: store))
        case .article:
            guard let article else {
                fail("no entry from \(articleSources.joined(separator: " or ")) — refusing to " +
                     "freeze an arbitrary live headline into a store screenshot")
            }
            window.contentViewController = NSHostingController(
                rootView: NavigationStack { EntryDetailView(entry: article, library: Library()) })
        case .feeds:
            window.contentViewController = NSHostingController(rootView: ManageFeedsView(store: store, library: Library()))
        }

        // CAPTURE_WIDTH=360 checks the narrow window for QA; store frames stay 1280x800.
        let width = ProcessInfo.processInfo.environment["CAPTURE_WIDTH"].flatMap(Double.init) ?? size.width
        window.setContentSize(NSSize(width: width, height: size.height))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()

        // Images and web content load asynchronously with no completion we can observe from
        // out here, so settle on a clock. Generous, because a frame missing its thumbnails is
        // worse than a slow capture.
        spin(seconds: state == .feeds ? 2 : 8)

        // CAPTURE_FRAME=1 grabs the whole window (title bar and toolbar tabs) for QA, not the store.
        let frame = ProcessInfo.processInfo.environment["CAPTURE_FRAME"] != nil
        guard let content = frame ? window.contentView?.superview : window.contentView else { fail("window has no content view") }
        // The reading view is a WKWebView, which renders out of process: `cacheDisplay` walks
        // straight past it and yields an empty frame. Its own `takeSnapshot` is the only thing
        // that returns those pixels.
        let rep: NSBitmapImageRep
        if let web = firstWebView(in: content) {
            rep = snapshot(web)
        } else {
            guard let cached = content.bitmapImageRepForCachingDisplay(in: content.bounds) else {
                fail("could not build a bitmap for the window")
            }
            content.cacheDisplay(in: content.bounds, to: cached)
            rep = cached
        }

        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(state.rawValue).png")
        guard let data = flattened(rep).representation(using: .png, properties: [:]) else {
            fail("could not encode PNG")
        }
        do { try data.write(to: out) } catch { fail("write failed: \(error)") }
        // stdout is the handoff to the capture script — path only, nothing else.
        print(out.path)
        exit(0)
    }

    /// Screenshots pull from a subset of the seed feeds rather than all seventeen. Every one of
    /// these ships in the app, so the frames stay representative — but the tabloid seeds lead
    /// with sportsbook promos often enough that one landed top-of-list on an early run, and a
    /// gambling ad in the first row of a first-time listing is a fight nobody needs.
    private static let listSources = [
        "Journal", "BBC", "NPR", "The Guardian", "CBC", "Wall Street Journal",
        "Global News", "Hacker News", "Daring Fireball",
    ]

    /// Feeds whose newest item is safe to freeze into a store listing. The list shot is live
    /// news because that is honestly what the app shows, but a single article blown up to full
    /// screen is different: one grim or graphic headline is what a reviewer sees. An early run
    /// of this tool picked a story about AI-generated child abuse imagery, which is exactly the
    /// failure this guards. Journal is Joshua's own blog; Daring Fireball is a tech column.
    private static let articleSources = ["Journal", "Daring Fireball"]

    private static func pickArticle(from entries: [JournalEntry]) -> JournalEntry? {
        for source in articleSources {
            if let match = entries.first(where: { $0.sourceTitle == source && $0.htmlContent.count > 400 }) {
                return match
            }
        }
        return nil
    }

    private static func firstWebView(in view: NSView) -> WKWebView? {
        if let web = view as? WKWebView { return web }
        for sub in view.subviews {
            if let found = firstWebView(in: sub) { return found }
        }
        return nil
    }

    @MainActor
    private static func snapshot(_ web: WKWebView) -> NSBitmapImageRep {
        var result: NSBitmapImageRep?
        var done = false
        web.takeSnapshot(with: nil) { image, _ in
            if let tiff = image?.tiffRepresentation { result = NSBitmapImageRep(data: tiff) }
            done = true
        }
        let deadline = Date().addingTimeInterval(15)
        while !done && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        guard let result else { fail("web view snapshot failed") }
        return result
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        // Pin the appearance so a run on a light-mode Mac still matches the rest of the set.
        window.appearance = NSAppearance(named: .darkAqua)
        return window
    }

    /// App Store rejects screenshots with an alpha channel, and a window capture always has
    /// one (rounded corners). Redrawing through a `noneSkipLast` CoreGraphics context is what
    /// actually drops the channel — `NSGraphicsContext(bitmapImageRep:)` returns nil for a
    /// 24bpp no-alpha rep, so the obvious AppKit spelling of this traps at runtime.
    private static func flattened(_ rep: NSBitmapImageRep) -> NSBitmapImageRep {
        let w = rep.pixelsWide, h = rep.pixelsHigh
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let source = rep.cgImage else {
            fail("could not allocate an opaque bitmap")
        }
        let bounds = CGRect(x: 0, y: 0, width: w, height: h)
        // Black to match the pinned dark appearance, so the corners blend instead of ringing.
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)
        ctx.draw(source, in: bounds)
        guard let flat = ctx.makeImage() else { fail("could not flatten the bitmap") }
        return NSBitmapImageRep(cgImage: flat)
    }

    /// Pump the run loop instead of sleeping — the views only lay out and load while it runs.
    private static func spin(seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }

    /// Run an async call to completion from this synchronous startup path.
    @MainActor
    private static func await_(_ operation: @escaping @MainActor () async -> Void) {
        var done = false
        Task { await operation(); done = true }
        let deadline = Date().addingTimeInterval(30)
        while !done && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(("capture: " + message + "\n").data(using: .utf8)!)
        exit(1)
    }
}
#endif
