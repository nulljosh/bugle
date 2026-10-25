import SwiftUI

@main
struct BugleMacApp: App {
    init() {
        // `--capture <state>` renders one App Store frame offscreen, prints its path and
        // exits before any real window opens. DEBUG-only; the shipped binary has no such path.
        #if DEBUG
        if MainActor.assumeIsolated({ ScreenshotCapture.runIfRequested() }) { return }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            EntryListView()
                .frame(minWidth: 360, minHeight: 480)
                .tint(.bugleAccent)
        }
        .defaultSize(width: 1280, height: 800)
    }
}
