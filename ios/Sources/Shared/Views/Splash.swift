import SwiftUI

/// The boot splash: the mascot pops up, blinks, and sounds its call, then Home fades up. About a second, while the
/// first feeds load underneath; Reduce Motion gets the mascot still and a fade.
struct Splash: View {
    /// False from launch until the splash has gone (iOS only; true where there is no splash), so the first-run
    /// topic picker never opens over it.
    @MainActor static var finished = true

    @Environment(\.accessibilityReduceMotion) private var still
    @Environment(\.scenePhase) private var phase
    var done: () -> Void = {}
    /// When the first frame drew. A reference, so setting it from inside the timeline never redraws anything.
    @State private var clock = Clock()
    final class Clock { var start: Date? }

    var body: some View {
        TimelineView(.animation(paused: still)) { tl in
            // the clock starts at the first frame drawn once the app is active: before that iOS is still crossfading
            // from the launch screen, and a clock started earlier played half the animation behind it
            let first = clock.start ?? (phase == .active ? { clock.start = tl.date; return tl.date }() : nil)
            let t = still ? 2 : first.map { tl.date.timeIntervalSince($0) } ?? 0
            let pop = min(1, t / 0.4)
            Mascot(blink: Self.pulse(t, at: 0.45, for: 0.24),
                   toot: Self.pulse(t, at: 0.75, for: 0.36),
                   waves: max(0, min(3, (t - 0.8) / 0.1)))
                .frame(width: 196, height: 196)
                .scaleEffect(0.6 + 0.4 * Self.overshoot(pop))
                .opacity(min(1, t / 0.15))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("LaunchBackground"))   // the launch screen's own color, so boot never jumps
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task {   // done 1.35 s after the first frame, however late that frame came
            while clock.start == nil { try? await Task.sleep(for: .milliseconds(30)) }
            try? await Task.sleep(for: .seconds(still ? 0.5 : 1.35))
            for _ in 0..<30 where !JournalFeedService.ready { try? await Task.sleep(for: .milliseconds(50)) }   // Home whole, 1.5 s at most
            done()
            try? await Task.sleep(for: .seconds(0.45))   // the fade
            Self.finished = true
        }
    }

    /// 0 to 1 and back over `d` seconds from `a`.
    static func pulse(_ t: Double, at a: Double, for d: Double) -> Double { t < a || t > a + d ? 0 : sin((t - a) / d * .pi) }
    /// An ease out that overshoots a little, for the pop.
    static func overshoot(_ x: Double) -> Double { let c = 1.7; return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2) }
}
