import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// One story in a list: thumbnail, a title cut to fit, the outlet and how long ago. Swipe left or press and hold
/// to save, share or copy the link. A story you have opened dims, like a read mail. Used by Home, Saved and History.
struct EntryRow: View {
    let entry: JournalEntry
    @ObservedObject var library: Library
    var story: Story? = nil

    var body: some View {
        let read = library.isRead(entry)
        RowLink(entry: entry) {
            // News-app convention (Mobbin: Yahoo, Artifact, USA Today, NYT, Guardian): the outlet above the
            // headline, text on the left so every title starts on the same edge, the picture on the right.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Kicker(entry: entry, saved: library.isSaved(entry), sources: story?.publishers ?? 1)
                    FittedTitle(variants: Headline.variants(entry.title, source: entry.sourceTitle))
                        .foregroundStyle(read ? .secondary : .primary)
                }
                Spacer(minLength: 0)
                EntryThumbnail(url: entry.imageURL, page: entry.url, source: entry.sourceTitle)
                    .opacity(read ? 0.6 : 1)
            }
            .padding(.vertical, 6)
        }
        .swipeActions(edge: .trailing) {
            Button { library.toggleSave(entry) } label: {
                Label(library.isSaved(entry) ? "Unsave" : "Save", systemImage: library.isSaved(entry) ? "bookmark.slash" : "bookmark")
            }
            .tint(.green)
        }
        .contextMenu {
            Button { library.toggleSave(entry) } label: {
                Label(library.isSaved(entry) ? "Remove from Saved" : "Save", systemImage: library.isSaved(entry) ? "bookmark.slash" : "bookmark")
            }
            if entry.audioURL != nil {
                Button { Player.shared.start(entry) } label: { Label("Play", systemImage: "play") }
                Button { Player.shared.toggleQueue(entry) } label: {
                    Label(Player.shared.isQueued(entry) ? "Remove from Up Next" : "Add to Up Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button { Downloads.shared.toggle(entry) } label: {
                    Label(Downloads.shared.file(entry) != nil ? "Remove Download" : "Download", systemImage: "arrow.down.circle")
                }
            }
            if let url = URL(string: entry.url) {
                ShareLink(item: url)
                Button { Pasteboard.copy(entry.url) } label: { Label("Copy Link", systemImage: "link") }
                Link(destination: url) { Label("Open in Browser", systemImage: "safari") }
            }
        }
    }
}



/// A navigation link without the disclosure arrow: news apps don't draw one, the whole row is the target.
struct RowLink<Content: View>: View {
    let entry: JournalEntry
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            NavigationLink(value: entry) { EmptyView() }.opacity(0)
            content
        }
        .accessibilityElement(children: .combine)   // VoiceOver reads one row as one story: outlet, time, headline
    }
}

/// A capsule search field with a leading magnifier and a clear button, 44 points tall (house Apple rules).
struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Search stories and outlets", text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                #if os(iOS)
                .submitLabel(.search)
                #endif
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .accessibilityLabel("Clear search")
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.secondary.opacity(0.12), in: Capsule())   // content layer: a fill, not glass
    }
}

enum Pasteboard {
    static func copy(_ s: String) {
        #if os(iOS)
        UIPasteboard.general.string = s
        #else
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string)
        #endif
    }
}

/// The longest headline variant that fits in two lines, so titles end on a word, not "…" (one line cut them to
/// three words on a phone; Apple News allows two). The last child is the shortest variant, allowed to truncate.
private struct FittedTitle: View {
    let variants: [String]
    #if os(macOS)
    private let twoLines: CGFloat = 34
    #else
    @ScaledMetric(relativeTo: .headline) private var twoLines: CGFloat = 44
    #endif

    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        if size.isAccessibilitySize {   // the largest sizes: the whole headline, as many lines as it takes
            Text(variants.first ?? "").font(.headline).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ViewThatFits(in: .vertical) {
                ForEach(variants, id: \.self) { Text($0).font(.headline).fixedSize(horizontal: false, vertical: true) }
                Text(variants.last ?? "").font(.headline).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: twoLines, maxHeight: twoLines, alignment: .topLeading)
        }
    }
}

/// Every row gets the same square, so the list lines up: the story's image when it has one, otherwise the outlet's
/// initials on a blue tile (Joshua 2026-10-25: a mix of rows with and without thumbnails looked funny).
private struct EntryThumbnail: View {
    let url: URL?
    let page: String
    let source: String
    @State private var preview: URL?
    private let side: CGFloat = 56

    var body: some View {
        Group {
            if let url = url ?? preview {
                CachedImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { outlet }
                }
            } else {
                outlet
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        // no image in the feed: ask the article page for its preview image before settling on initials
        .task(id: page) { if url == nil { preview = await PreviewImage.lookup(page) } }
    }

    /// The outlet's own icon from its site (apple-touch-icon, then favicon), else its initials.
    private var outlet: some View {
        let host = URL(string: page)?.host
        return ZStack {
            Outlet.color(source).opacity(0.12)
            if let host, let touch = URL(string: "https://\(host)/apple-touch-icon.png"), let fav = URL(string: "https://\(host)/favicon.ico") {
                AsyncImage(url: touch) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        AsyncImage(url: fav) { p in
                            if case .success(let icon) = p { icon.resizable().interpolation(.high).scaledToFit().frame(width: 28, height: 28) } else { monogram }
                        }
                    default: monogram
                    }
                }
            } else {
                monogram
            }
        }
    }

    private var monogram: some View {
        Text(Self.initials(source)).font(.system(size: 17, weight: .bold)).foregroundStyle(Outlet.color(source))
            .accessibilityHidden(true)   // a stand-in picture; the outlet is already read out
    }

    /// "BBC" stays BBC; "Hacker News" is HN; "The Province" is P. Mirrors `initials` in web/read.html.
    static func initials(_ source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 4, trimmed == trimmed.uppercased(), !trimmed.isEmpty { return trimmed }
        let words = trimmed.split(separator: " ").filter { $0.lowercased() != "the" }
        let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "C" : letters
    }
}
