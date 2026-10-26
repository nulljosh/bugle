import SwiftUI

/// Bugle's mascot: the horn come alive, its coil a round smiling face. Drawn on a 240 grid, the same shapes as
/// web/mascot.svg. `blink` closes the eyes (0 open, 1 shut), `toot` swells the bell (0 to 1), `waves` (0 to 3) sends
/// that many sound waves out of it.
struct Mascot: View {
    var blink: Double = 0
    var toot: Double = 0
    var waves: Double = 0
    /// -1 leans back and squashes (the breath before the call), +1 leans forward and stretches (the call itself).
    var lean: Double = 0

    static let blue = Color(light: 0x0059B3, dark: 0x3D8BE0)
    static let ink = Color(red: 0.043, green: 0.145, blue: 0.271)   // #0B2545

    var body: some View {
        Canvas { ctx, size in
            // a 300 box, so the waves travelling out of the bell fit beside the mascot instead of being cut off
            let s = min(size.width, size.height) / 300
            ctx.translateBy(x: (size.width - 300 * s) / 2, y: (size.height - 300 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            ctx.translateBy(x: -3, y: 13)
            let blue = GraphicsContext.Shading.color(Self.blue), ink = GraphicsContext.Shading.color(Self.ink)
            // the tube from the mouthpiece, behind the face, into the bell
            ctx.fill(Path(roundedRect: CGRect(x: 22, y: 92, width: 160, height: 22), cornerRadius: 11), with: blue)
            ctx.fill(Path(roundedRect: CGRect(x: 10, y: 86, width: 22, height: 34), cornerRadius: 8), with: blue)
            var bell = ctx
            let swell = 1 + 0.2 * toot
            bell.translateBy(x: 170, y: 103); bell.scaleBy(x: swell, y: swell); bell.translateBy(x: -170, y: -103)
            var b = Path()
            b.move(to: CGPoint(x: 170, y: 92))
            b.addCurve(to: CGPoint(x: 226, y: 60), control1: CGPoint(x: 196, y: 90), control2: CGPoint(x: 214, y: 78))
            b.addLine(to: CGPoint(x: 226, y: 146))
            b.addCurve(to: CGPoint(x: 170, y: 114), control1: CGPoint(x: 214, y: 128), control2: CGPoint(x: 196, y: 116))
            b.closeSubpath()
            bell.fill(b, with: blue)
            // each wave leaves the bell at the same speed, one after another, so they stay evenly spaced, and fades as it goes
            for i in 0..<3 {
                let p = waves - Double(i)
                guard p > 0 else { continue }
                let alpha = p < 1 ? p : max(0, 1 - (p - 1) * 0.5)   // a slow fade, so the three ripple out together
                guard alpha > 0 else { continue }
                var arc = Path()
                arc.addArc(center: CGPoint(x: 226, y: 103), radius: CGFloat(18 + 22 * min(p, 2.2)), startAngle: .degrees(-38), endAngle: .degrees(38), clockwise: false)
                ctx.stroke(arc, with: .color(Self.blue.opacity(alpha)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            }
            // the coil is the face
            let face = Path(ellipseIn: CGRect(x: 34, y: 76, width: 132, height: 132))
            ctx.fill(face, with: .color(.white))
            ctx.stroke(face, with: blue, lineWidth: 14)
            let open = max(0.08, 1 - blink)
            for x in [80.0, 120.0] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - 9, y: 138 - 12 * open, width: 18, height: 24 * open)), with: ink)
                if open > 0.5 { ctx.fill(Path(ellipseIn: CGRect(x: x, y: 131, width: 6, height: 6)), with: .color(.white)) }
            }
            for x in [64.0, 136.0] { ctx.fill(Path(ellipseIn: CGRect(x: x - 9, y: 151, width: 18, height: 18)), with: .color(Color(red: 1, green: 0.56, blue: 0.64).opacity(0.7))) }
            var smile = Path()
            smile.move(to: CGPoint(x: 88, y: 162)); smile.addQuadCurve(to: CGPoint(x: 112, y: 162), control: CGPoint(x: 100, y: 174))
            ctx.stroke(smile, with: ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
        // the whole body breathes in and pushes the note out, from its feet
        .scaleEffect(x: 1 - 0.05 * lean, y: 1 + 0.06 * lean, anchor: .bottom)
        .rotationEffect(.degrees(3.5 * lean), anchor: .bottom)
        .accessibilityHidden(true)
    }

    /// The lean through one call: back over the 0.13 s before it, forward through it, settling after.
    static func lean(_ t: Double, call: Double) -> Double {
        let back = Splash.pulse(t, at: call - 0.15, for: 0.2), forward = Splash.pulse(t, at: call, for: 0.36)
        return forward - back
    }
}

/// The mascot on a loop, for waiting and empty screens: it toots every 1.6 s while `tooting` (loading), blinks every
/// few seconds, and bobs. Still under Reduce Motion.
struct MascotLoop: View {
    var tooting = true
    var size: CGFloat = 88
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        TimelineView(.animation(paused: still)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate, beat = t.truncatingRemainder(dividingBy: 1.6)
            Mascot(blink: Splash.pulse(t.truncatingRemainder(dividingBy: 3.8), at: 3.4, for: 0.24),
                   toot: tooting ? Splash.pulse(beat, at: 0.2, for: 0.36) : 0,
                   waves: tooting ? max(0, (beat - 0.25) / 0.12) : 0,
                   lean: tooting ? Mascot.lean(beat, call: 0.2) : 0)
                .frame(width: size, height: size)
                .offset(y: still ? 0 : sin(t * 2.2) * 2)
        }
    }
}
