import CoreImage
import SwiftUI

/// An episode's cover worked into the interface, Apple Music style: the art blurred behind the page and the glass tinted
/// with its color. Glass over rich media follows Apple's rule: a dimming layer so text stays legible.
enum ArtColor {
    @MainActor private static var cache: [URL: Color] = [:]

    /// The art's average color, a little deepened so a tint never washes out; nil if it will not load.
    @MainActor static func of(_ url: URL) async -> Color? {
        if let hit = cache[url] { return hit }
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        let rgb: (Double, Double, Double)? = await Task.detached {
            guard let image = CIImage(data: data),
                  let avg = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: image.extent)])?.outputImage
            else { return nil }
            var px = [UInt8](repeating: 0, count: 4)
            CIContext(options: [.workingColorSpace: NSNull()]).render(avg, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
            return (Double(px[0]) / 255, Double(px[1]) / 255, Double(px[2]) / 255)
        }.value
        guard let (r, g, b) = rgb else { return nil }
        let c = Color(red: r * 0.85, green: g * 0.85, blue: b * 0.85)
        cache[url] = c
        return c
    }
}

/// The cover, blurred and soft, washing the top of the episode page and fading into it.
struct CoverBackdrop: View {
    let url: URL?
    var height: CGFloat = 460

    var body: some View {
        CachedImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity).frame(height: height).clipped()
                    .saturation(1.6).blur(radius: 60).opacity(0.8)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Now Playing's background: the whole cover blurred, dimmed 35 percent so the rows on it read (Apple's figure for
/// clear glass over bright media).
struct CoverSheetBackground: View {
    let url: URL?

    var body: some View {
        ZStack {
            Color(white: 0.11)
            CachedImage(url: url) { phase in
                if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill).blur(radius: 70).opacity(0.9) }
            }
            Color.black.opacity(0.35)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
