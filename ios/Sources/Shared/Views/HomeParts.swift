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
                if followable {
                    Button(Topics.has(q, in: topics) ? "Unfollow" : "+ Follow \u{201C}\(q)\u{201D}") { topics = Topics.toggled(q, in: topics) }
                        .buttonStyle(Chip(on: true))
                }
                if !q.isEmpty {   // mute anything you can search: an outlet or a word
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

/// A capsule like the web's `.chip`: gray, or tinted text on a pale tint when on.
struct Chip: ButtonStyle {
    var on = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .background(on ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(Color.secondary.opacity(0.12)), in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
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
