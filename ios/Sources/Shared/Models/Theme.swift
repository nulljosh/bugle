import SwiftUI

extension Color {
    // Matches --accent in brand/tokens.css (#0059B3) so the brand color is the same everywhere.
    static let bugleAccent = Color(red: 0.0, green: 0.349, blue: 0.702)
}

extension Color {
    /// One color per appearance, from 0xRRGGBB values (outlet colors in Outlet.brand).
    init(light: UInt32, dark: UInt32) {
        func rgb(_ v: UInt32) -> (CGFloat, CGFloat, CGFloat) { (CGFloat(v >> 16 & 0xFF) / 255, CGFloat(v >> 8 & 0xFF) / 255, CGFloat(v & 0xFF) / 255) }
        let (l, d) = (rgb(light), rgb(dark))
        #if os(watchOS)
        self.init(red: d.0, green: d.1, blue: d.2)   // the watch is always dark
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { a in
            let c = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        self.init(uiColor: UIColor { t in
            let c = t.userInterfaceStyle == .dark ? d : l
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }
}
