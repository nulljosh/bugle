import SwiftUI

@main
struct JournalApp: App {
    @Environment(\.scenePhase) private var phase

    init() {
        #if DEBUG
        // The self-checks were dead code until this call — nothing invoked them.
        feedParserDemo()
        readingTimeDemo()
        clockDemo()
        briefingDemo()
        fullTextDemo()
        hnDemo()
        hiResDemo()
        archiveDemo()
        inboxDemo()
        seedFeedsDemo()
        headlineDemo()
        previewImageDemo()
        relativeTimeDemo()
        coverageDemo()
        alertsDemo()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            BootView()
        }
        .onChange(of: phase) { if phase == .background { BackgroundRefresh.schedule() } }
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) { await BackgroundRefresh.run() }
    }
}

/// Home under the boot splash. The splash state lives in a view, not the App: a change to App state does not animate
/// the views, so the fade cut straight to Home.
struct BootView: View {
    @State private var splash = true
    /// Once per launch: the App rebuilds this view on every scene change, and only the first build has a splash.
    @MainActor private static var booted = false
    init() { if !Self.booted { Self.booted = true; Splash.finished = false } }

    var body: some View {
        ZStack {
            EntryListView().tint(.bugleAccent)
            // the call, then Home fades up; the feeds have been loading underneath the whole time
            if splash { Splash { splash = false }.transition(.opacity).zIndex(1) }
        }
        .animation(.easeOut(duration: 0.4), value: splash)
    }
}
