import SwiftUI

/// "BBC · 2h ago · 3 sources" above a headline: the outlet in its own color, a bookmark when saved. One line of
/// text, so at the largest Dynamic Type sizes it wraps instead of cutting every part short.
struct Kicker: View {
    let entry: JournalEntry
    let saved: Bool
    var sources = 1
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        let src = entry.sourceTitle, ago = RelativeTime.short(entry.date)
        let rest = [ago, entry.listenTime ?? "", sources > 1 ? "\(sources) sources" : "",
                    entry.audioURL != nil && Player.shared.isQueued(entry) ? String(localized: "Up Next") : ""].filter { !$0.isEmpty }
        let tail = rest.map { " · " + $0 }.joined()
        (Text(src).fontWeight(.semibold).foregroundStyle(Outlet.color(src))
            + Text(src.isEmpty ? String(tail.dropFirst(3)) : tail).foregroundStyle(.secondary)
            + (saved ? Text("  ") + Text(Image(systemName: "bookmark.fill")).foregroundStyle(Color.bugleAccent) : Text("")))
            .font(.caption)
            .lineLimit(size.isAccessibilitySize ? 3 : 1)
            .accessibilityLabel(([src] + rest + (saved ? ["Saved"] : [])).filter { !$0.isEmpty }.joined(separator: ", "))
    }
}

/// The top story, big, like an App Store Today card: the picture fills a 28 point card and the outlet and headline
/// sit on glass that rises out of the bottom of the photo, so the words belong to the picture instead of under it.
struct HeroRow: View {
    let entry: JournalEntry
    @ObservedObject var library: Library
    var story: Story? = nil

    /// The longest clean cut up to 90 characters, so even the hero ends on a whole phrase, never "…".
    static func headline(_ e: JournalEntry) -> String {
        let v = Headline.variants(e.title, source: e.sourceTitle)
        return v.first { $0.count <= 90 } ?? v.last ?? e.title
    }

    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        if size.isAccessibilitySize { large } else { card }
    }

    /// The largest text sizes: the photo, then the outlet and the whole headline under it, so nothing spills off the card.
    private var large: some View {
        RowLink(entry: entry) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear.aspectRatio(4 / 3, contentMode: .fit)
                    .overlay { CachedImage(url: entry.imageURL) { phase in
                        if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { Color(white: 0.11) }
                    } }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                Kicker(entry: entry, saved: library.isSaved(entry), sources: story?.publishers ?? 1)
                Text(Headline.clean(entry.title, source: entry.sourceTitle)).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(library.isRead(entry) ? .secondary : .primary)
            }
            .padding(.vertical, 8)
        }
    }

    private var card: some View {
        RowLink(entry: entry) {
            // 4:3 on a phone; a wide Mac window caps it at 480 points so the picture never fills the screen.
            Color.clear
                .aspectRatio(4 / 3, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 480)
                .overlay {
                    CachedImage(url: entry.imageURL) { phase in
                        if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { Color(white: 0.11) }   // dark while it loads, so white type reads
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker(entry: entry, saved: library.isSaved(entry), sources: story?.publishers ?? 1)
                        Text(Self.headline(entry))
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(.white.opacity(library.isRead(entry) ? 0.7 : 1))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 16)
                    .background {
                        // the glass: blur and a dark tint, faded in from the top so there is no edge on the photo
                        ZStack { Rectangle().fill(.ultraThinMaterial); Color.black.opacity(0.34) }
                            .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45)))
                    }
                    .environment(\.colorScheme, .dark)   // white type and each outlet's light-on-dark color, on any photo
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.vertical, 8)
        }
        .contextMenu {
            Button { library.toggleSave(entry) } label: { Label(library.isSaved(entry) ? "Remove from Saved" : "Save", systemImage: "bookmark") }
            if let url = URL(string: entry.url) { ShareLink(item: url) }
        }
    }
}
