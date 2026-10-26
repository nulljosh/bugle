import SwiftUI

/// Bugle's mascot: the horn come alive, its coil a round smiling face. Drawn on a 240 grid, the same shapes as
/// web/mascot.svg. `blink` closes the eyes (0 open, 1 shut), `toot` swells the bell (0 to 1), `waves` (0 to 3) sends
/// that many sound waves out of it.
struct Mascot: View {
    var blink: Double = 0
    var toot: Double = 0
    var waves: Double = 0

    static let blue = Color(light: 0x0059B3, dark: 0x3D8BE0)
    static let ink = Color(red: 0.043, green: 0.145, blue: 0.271)   // #0B2545

    var body: some View {
        Canvas { ctx, size in
            // a 280 box, so the waves out of the bell fit beside the mascot instead of being cut off
            let s = min(size.width, size.height) / 280
            ctx.translateBy(x: (size.width - 280 * s) / 2, y: (size.height - 280 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            ctx.translateBy(x: -5, y: 3)
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
            for i in 0..<3 where waves > Double(i) {
                var arc = Path()
                arc.addArc(center: CGPoint(x: 226, y: 103), radius: CGFloat(18 + i * 16), startAngle: .degrees(-38), endAngle: .degrees(38), clockwise: false)
                ctx.stroke(arc, with: .color(Self.blue.opacity(min(1, waves - Double(i)))), style: StrokeStyle(lineWidth: 7, lineCap: .round))
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
        .accessibilityHidden(true)
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
                   toot: tooting ? Splash.pulse(beat, at: 0, for: 0.36) : 0,
                   waves: tooting && beat < 0.9 ? min(3, beat / 0.1) : 0)
                .frame(width: size, height: size)
                .offset(y: still ? 0 : sin(t * 2.2) * 2)
        }
    }
}
