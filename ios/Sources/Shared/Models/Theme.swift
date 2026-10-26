import SwiftUI

extension Color {
    // Matches --accent in brand/tokens.css (#0059B3) so the brand color is the same everywhere.
    /// #0059B3 on light; on dark, Apple's dark system blue, since #0059B3 on black is under 3:1 for text.
    static let bugleAccent = Color(light: 0x0059B3, dark: 0x0A84FF)
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

/// The reader's page (Unread's and Feedly's themes): Auto follows the system, Light and Black pin it, Dusk is a soft gray
/// for reading in the dark. No sepia (the house palette has no beige) and no serif (sans serif only). Same as the web's
/// reader themes in reader.css.
enum ReaderTheme: String, CaseIterable, Identifiable {
    case auto, light, dusk, black
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self { case .auto: "Auto"; case .light: "Light"; case .dusk: "Dusk"; case .black: "Black" }
    }
    /// The page color behind the story, so the edges match it; clear follows the system.
    var page: Color {
        switch self {
        case .auto: .clear
        case .light: Color(light: 0xFFFFFF, dark: 0xFFFFFF)
        case .dusk: Color(light: 0x2C2C2E, dark: 0x2C2C2E)
        case .black: Color(light: 0x000000, dark: 0x000000)
        }
    }

    /// Page background, text, secondary text and links as CSS colors; nil follows the system.
    var colors: (bg: String, text: String, sub: String, link: String)? {
        switch self {
        case .auto: nil
        case .light: ("#ffffff", "#1d1d1f", "#6e6e73", "#0059b3")
        case .dusk: ("#2c2c2e", "#e5e5ea", "#aeaeb2", "#5aa9ff")
        case .black: ("#000000", "#f5f5f7", "#98989d", "#5aa9ff")
        }
    }
}
