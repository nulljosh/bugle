import AVKit
import SwiftUI

/// Now Playing, from the mini player, like Apple Podcasts' player sheet: the episode (tap it to open its story), Up Next
/// to drag into order or swipe away, then the scrubber and controls, with AirPlay up top.
struct NowPlayingView: View {
    @ObservedObject var player: Player
    let open: (JournalEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let e = player.entry {
                    Section {
                        Button { dismiss(); open(e) } label: { EpisodeLine(entry: e, art: 64, bold: true) }
                            .buttonStyle(.plain)
                            .listRowBackground(Rectangle().fill(.thinMaterial))
                            .accessibilityHint("Opens the episode")
                    }
                }
                Section {
                    ForEach(player.queue) { EpisodeLine(entry: $0, art: 44, bold: false).listRowBackground(Rectangle().fill(.thinMaterial)) }
                        .onMove { player.moveQueue(from: $0, to: $1) }
                        .onDelete { player.removeQueue(at: $0) }
                    if player.queue.isEmpty {
                        Text("Nothing in Up Next. Press and hold an episode to add it.").foregroundStyle(.secondary).listRowBackground(Rectangle().fill(.thinMaterial))
                    }
                } header: {
                    HStack {
                        Text("Up Next")
                        // the whole queue's length, "2 hr, 10 min", like Pocket Casts
                        let total = player.queue.compactMap(\.audioSeconds).reduce(0, +)
                        if total > 0 { Text(Duration.seconds(total).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))).foregroundStyle(.secondary).textCase(nil) }
                        Spacer()
                        if !player.queue.isEmpty { Button("Clear") { player.clearQueue() }.textCase(nil) }
                    }
                }
            }
            .scrollContentBackground(.hidden)   // the cover shows through; rows keep a standard material
            .safeAreaInset(edge: .bottom, spacing: 0) { if let e = player.entry { EpisodeBar(player: player, entry: e) } }
            .environment(\.colorScheme, .dark)   // light type on the dimmed cover
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .navigationTitle("Now Playing")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { RoutePicker().frame(width: 32, height: 32).accessibilityLabel("AirPlay") }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: player.entry == nil) { if player.entry == nil { dismiss() } }   // the last episode ended
        }
        .presentationBackground { CoverSheetBackground(url: player.entry?.imageURL) }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
    }
}

/// An episode in Now Playing: its art, title and show with its length.
private struct EpisodeLine: View {
    let entry: JournalEntry
    let art: CGFloat
    let bold: Bool

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(url: entry.imageURL) { phase in
                if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { Color.secondary.opacity(0.2) }
            }
            .frame(width: art, height: art).clipShape(RoundedRectangle(cornerRadius: art / 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(Headline.clean(entry.title, source: entry.sourceTitle)).font(bold ? .headline : .body).lineLimit(2)
                Text([entry.sourceTitle, entry.listenTime ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The system AirPlay button.
#if os(iOS)
private struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.activeTintColor = UIColor(Color.bugleAccent)
        return v
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
#else
private struct RoutePicker: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.isRoutePickerButtonBordered = false
        return v
    }
    func updateNSView(_ view: AVRoutePickerView, context: Context) {}
}
#endif
