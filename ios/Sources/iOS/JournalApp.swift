import SwiftUI

@main
struct JournalApp: App {
    @Environment(\.scenePhase) private var phase

    init() {
        #if DEBUG
        // The self-checks were dead code until this call — nothing invoked them.
        feedParserDemo()
        readingTimeDemo()
        fullTextDemo()
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
            EntryListView()
            .tint(.bugleAccent)
        }
        .onChange(of: phase) { if phase == .background { BackgroundRefresh.schedule() } }
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) { await BackgroundRefresh.run() }
    }
}
