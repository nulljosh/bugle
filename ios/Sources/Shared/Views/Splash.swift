import SwiftUI

/// The boot splash: the mascot pops up, blinks, and sounds its call, then Home fades up. About a second, while the
/// first feeds load underneath; Reduce Motion gets the mascot still and a fade.
struct Splash: View {
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation(paused: still)) { tl in
            let t = still ? 2 : tl.date.timeIntervalSince(start)
            let pop = min(1, t / 0.4)
            Mascot(blink: Self.pulse(t, at: 0.45, for: 0.16),
                   toot: Self.pulse(t, at: 0.62, for: 0.3),
                   waves: max(0, min(3, (t - 0.66) / 0.09)))
                .frame(width: 168, height: 168)
                .scaleEffect(0.6 + 0.4 * Self.overshoot(pop))
                .opacity(min(1, t / 0.15))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("LaunchBackground"))   // the launch screen's own color, so boot never jumps
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// 0 to 1 and back over `d` seconds from `a`.
    static func pulse(_ t: Double, at a: Double, for d: Double) -> Double { t < a || t > a + d ? 0 : sin((t - a) / d * .pi) }
    /// An ease out that overshoots a little, for the pop.
    static func overshoot(_ x: Double) -> Double { let c = 1.7; return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2) }
}
