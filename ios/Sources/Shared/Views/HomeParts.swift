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
    /// The Briefing chip; nil where Home has it in the toolbar instead.
    var briefing: (() -> Void)? = nil

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // The Briefing first: today's five, numbered, to read or hear (Ground News's The Last 24).
                if let briefing { Button { briefing() } label: { Label("Briefing", systemImage: "list.number") }.buttonStyle(Chip(on: false)) }
                let unread = q.caseInsensitiveCompare(Coverage.unread) == .orderedSame
                Button(LocalizedStringKey(Coverage.unread)) { query = unread ? "" : Coverage.unread }.buttonStyle(Chip(on: unread))
                    .accessibilityAddTraits(unread ? .isSelected : [])
                // Ground News's collections: blindspots, what one side covers most, what both sides covered.
                ForEach(Coverage.collections, id: \.name) { c in
                    let on = c.name.caseInsensitiveCompare(q) == .orderedSame
                    Button(LocalizedStringKey(c.name)) { query = on ? "" : c.name }.buttonStyle(Chip(on: on))
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
                let blind = Coverage.isCollection(q)
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

/// A capsule like the web's `.chip`: gray, or tinted text on a pale tint when on. Plain fills, not Liquid Glass: chips
/// scroll with the stories, and Apple keeps glass out of the content layer.
struct Chip: ButtonStyle {
    var on = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)   // grows with Dynamic Type instead of clipping
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

/// Your shows, Apple Podcasts' shelf: one tile per podcast you follow, its art and name; a tap lists its episodes.
struct ShowsRow: View {
    let episodes: [JournalEntry]
    let open: (String) -> Void

    var body: some View {
        // one tile per show, in the order its newest episode came in, with that episode's (the show's) art
        let shows = episodes.reduce(into: [JournalEntry]()) { all, e in if !all.contains(where: { $0.sourceTitle == e.sourceTitle }) { all.append(e) } }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(shows, id: \.sourceTitle) { e in
                    Button { open(e.sourceTitle) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            CachedImage(url: e.imageURL) { phase in
                                if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { Color.secondary.opacity(0.15) }
                            }
                            .frame(width: 112, height: 112).clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(e.sourceTitle).font(.footnote.weight(.semibold)).lineLimit(2).frame(width: 112, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(e.sourceTitle)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
        .listRowSeparator(.hidden)
    }
}
