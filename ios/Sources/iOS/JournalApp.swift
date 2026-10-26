import SwiftUI

@main
struct JournalApp: App {
    @Environment(\.scenePhase) private var phase
    @State private var splash = true

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
            EntryListView()
            .tint(.bugleAccent)
            .overlay { if splash { Splash().transition(.opacity) } }
            .task {   // the call, then Home fades up; the feeds have been loading underneath the whole time
                try? await Task.sleep(for: .seconds(1.1))
                withAnimation(.easeOut(duration: 0.35)) { splash = false }
            }
        }
        .onChange(of: phase) { if phase == .background { BackgroundRefresh.schedule() } }
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) { await BackgroundRefresh.run() }
    }
}
