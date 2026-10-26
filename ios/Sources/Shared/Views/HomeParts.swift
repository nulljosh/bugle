import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Followed topics as chips under the search: tap one to read only it, tap again for everything. Mirrors
/// renderTopics in web/reader.js.
struct TopicBar: View {
    @Binding var query: String
    @Binding var topics: String
    @Binding var muted: String
    let followable: Bool

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Blindspots first: stories only one side of the spectrum covered, like Ground News.
                let blind = q.caseInsensitiveCompare(Coverage.blindspots) == .orderedSame
                Button(LocalizedStringKey(Coverage.blindspots)) { query = blind ? "" : Coverage.blindspots }.buttonStyle(Chip(on: blind))
                    .accessibilityAddTraits(blind ? .isSelected : [])
                let pods = q.caseInsensitiveCompare(Coverage.podcasts) == .orderedSame
                Button(LocalizedStringKey(Coverage.podcasts)) { query = pods ? "" : Coverage.podcasts }.buttonStyle(Chip(on: pods))
                    .accessibilityAddTraits(pods ? .isSelected : [])
                if followable {
                    Button(Topics.has(q, in: topics) ? "Unfollow" : "+ Follow \u{201C}\(q)\u{201D}") { topics = Topics.toggled(q, in: topics) }
                        .buttonStyle(Chip(on: true))
                }
                if !q.isEmpty && !blind && !pods {   // mute anything you can search: an outlet or a word
                    let isMuted = Topics.has(q, in: muted)
                    Button(isMuted ? "Unmute" : "Mute") {
                        muted = Topics.toggled(q, in: muted)
                        if !isMuted { query = "" }
                    }.buttonStyle(Chip())
                }
                ForEach(Topics.list(topics), id: \.self) { t in
                    let on = t.caseInsensitiveCompare(q) == .orderedSame
                    Button(t) { query = on ? "" : t }.buttonStyle(Chip(on: on))
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
    }
}

/// A capsule like the web's `.chip`: gray, or tinted text on a pale tint when on. Liquid Glass on iOS 26 and macOS 26.
struct Chip: ButtonStyle {
    var on = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)   // grows with Dynamic Type instead of clipping
            .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .capsuleGlass(fill: on ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(Color.secondary.opacity(0.12)), on: on)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    /// A control's capsule: Liquid Glass on iOS 26 and macOS 26 (the fill only when on, so it reads as selected),
    /// the plain fill before.
    @ViewBuilder func capsuleGlass(fill: AnyShapeStyle, on: Bool = false) -> some View {
        if #available(iOS 26, macOS 26, *) {
            background(on ? fill : AnyShapeStyle(.clear), in: Capsule()).glassEffect(.regular.interactive(), in: Capsule())
        } else {
            background(fill, in: Capsule())
        }
    }
}

/// AsyncImage that reads the disk cache first and never revalidates, so a picture seen once (or a saved story's,
/// fetched on save) still shows with no connection. Same phases as AsyncImage.
struct CachedImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase).task(id: url) { phase = await Self.load(url) }
    }

    static func load(_ url: URL?) async -> AsyncImagePhase {
        guard let url else { return .empty }
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return .failure(URLError(.notConnectedToInternet)) }
        #if os(macOS)
        guard let img = NSImage(data: data) else { return .failure(URLError(.cannotDecodeContentData)) }
        return .success(Image(nsImage: img))
        #else
        guard let img = UIImage(data: data) else { return .failure(URLError(.cannotDecodeContentData)) }
        return .success(Image(uiImage: img))
        #endif
    }
}
