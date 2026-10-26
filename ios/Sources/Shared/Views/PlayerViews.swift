import SwiftUI

/// The episode's controls under its show notes. Playing it: Apple Podcasts' player, the scrubber with elapsed and left,
/// then speed, back 15, play, forward 30. Not playing: Play (or Resume) and Up Next. Glass over the page, 48 point targets.
struct EpisodeBar: View {
    @ObservedObject var player: Player
    let entry: JournalEntry

    var body: some View {
        Group { if player.entry?.id == entry.id { controls } else { cue } }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
            .floatingGlass()
    }

    private var cue: some View {
        HStack(spacing: 12) {
            Button { player.start(entry) } label: {
                Label(Player.positions[entry.id] == nil ? "Play" : "Resume", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white).background(Color.bugleAccent, in: Capsule())
            }
            .keyboardShortcut("l")
            Button { player.toggleQueue(entry) } label: {
                Label(player.isQueued(entry) ? "In Up Next" : "Up Next", systemImage: player.isQueued(entry) ? "checkmark" : "text.line.first.and.arrowtriangle.forward")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.secondary.opacity(0.14), in: Capsule())
            }
            .accessibilityLabel(player.isQueued(entry) ? "Remove from Up Next" : "Add to Up Next")
        }
        .buttonStyle(.plain)
    }

    // Time runs left to right in every language (Apple keeps media controls unmirrored in Arabic and Hebrew).
    private var controls: some View {
        VStack(spacing: 4) {
            Slider(value: $player.elapsed, in: 0...max(player.duration, player.elapsed, 1)) { editing in
                player.scrubbing = editing
                if !editing { player.seek(to: player.elapsed) }
            }
            .accessibilityLabel("Position")
            .accessibilityValue(clock(player.elapsed))
            HStack {
                Text(clock(player.elapsed))
                Spacer()
                Text(player.duration > 0 ? "-" + clock(player.duration - player.elapsed) : "")
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack {
                Button { player.nextRate() } label: {
                    Text(String(format: "%g\u{00D7}", player.rate)).font(.subheadline.weight(.semibold))
                        .frame(width: 48, height: 48, alignment: .leading).contentShape(Rectangle())
                }
                .accessibilityLabel("Speed")
                .accessibilityValue(String(format: "%g", player.rate))
                Spacer()
                Button { player.skip(-15) } label: { Image(systemName: "gobackward.15").font(.title2) }
                    .accessibilityLabel("Back 15 seconds")
                Spacer()
                Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.largeTitle) }
                    .accessibilityLabel(player.playing ? "Pause" : "Play")
                    .keyboardShortcut("l")
                Spacer()
                Button { player.skip(30) } label: { Image(systemName: "goforward.30").font(.title2) }
                    .accessibilityLabel("Forward 30 seconds")
                Spacer()
                Menu {
                    Button("Off") { player.setSleep(nil) }
                    ForEach([5, 15, 30, 45, 60], id: \.self) { m in Button("\(m) min") { player.setSleep(.minutes(m)) } }
                    Button("End of Episode") { player.setSleep(.endOfEpisode) }
                } label: {
                    Image(systemName: player.sleep == nil ? "moon.zzz" : "moon.zzz.fill").font(.title3)
                        .foregroundStyle(player.sleep == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.bugleAccent))
                        .frame(width: 48, height: 48, alignment: .trailing).contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Sleep Timer")
                .accessibilityValue(player.sleep == nil ? String(localized: "Off") : player.sleep == .endOfEpisode ? String(localized: "End of Episode") : String(localized: "On"))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 48)
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Now playing, above the tab bar like Apple Podcasts: the art, the episode and its show, play and forward 30. Tap it
/// for Now Playing. On iOS 26.1 it is the tab bar's own accessory; elsewhere it floats over the bottom edge.
struct MiniPlayer: View {
    @ObservedObject var player: Player
    let open: (JournalEntry) -> Void

    var body: some View {
        if let e = player.entry {
            HStack(spacing: 4) {
                Button { open(e) } label: {
                    HStack(spacing: 12) {
                        CachedImage(url: e.imageURL) { phase in
                            if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) } else { Color.secondary.opacity(0.2) }
                        }
                        .frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(Headline.clean(e.title, source: e.sourceTitle)).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(e.sourceTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Now Playing, \(Headline.clean(e.title, source: e.sourceTitle))")
                Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.title3).frame(width: 44, height: 44) }
                    .accessibilityLabel(player.playing ? "Pause" : "Play")
                Button { player.skip(30) } label: { Image(systemName: "goforward.30").font(.title3).frame(width: 44, height: 44) }
                    .accessibilityLabel("Forward 30 seconds")
            }
            .buttonStyle(.plain)
            .padding(.leading, 12).padding(.trailing, 4)
        }
    }
}

extension View {
    /// Liquid Glass for controls that float over the page (the functional layer, never content): on iOS 26 and macOS 26
    /// the card's corners are concentric with the display's, earlier systems get the bar material.
    @ViewBuilder func floatingGlass() -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(.regular, in: ConcentricRectangle(corners: .concentric(minimum: 24), isUniform: true)).padding(.horizontal, 12).padding(.bottom, 8)
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous)).padding(.horizontal, 12).padding(.bottom, 8)
        }
    }

    @ViewBuilder func floatingGlass(in shape: some Shape) -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(.regular, in: shape).padding(.horizontal, 12).padding(.bottom, 8)
        } else {
            background(.regularMaterial, in: shape).padding(.horizontal, 12).padding(.bottom, 8)
        }
    }

    /// The tab bar recedes while you scroll down through stories and comes back on the way up (iOS 26).
    @ViewBuilder func minimizesTabBar() -> some View {
        #if os(iOS)
        if #available(iOS 26, *) { tabBarMinimizeBehavior(.onScrollDown) } else { self }
        #else
        self
        #endif
    }

    /// The mini player on the tab view: the tab bar accessory on iOS 26.1 and later, a floating capsule elsewhere.
    @ViewBuilder func miniPlayer(_ player: Player, hidden: Bool, open: @escaping (JournalEntry) -> Void) -> some View {
        #if os(iOS)
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: player.entry != nil && !hidden) { MiniPlayer(player: player, open: open) }
        } else { floatingMiniPlayer(player, hidden: hidden, open: open) }
        #else
        floatingMiniPlayer(player, hidden: hidden, open: open)
        #endif
    }

    private func floatingMiniPlayer(_ player: Player, hidden: Bool, open: @escaping (JournalEntry) -> Void) -> some View {
        safeAreaInset(edge: .bottom) {
            if player.entry != nil && !hidden {
                MiniPlayer(player: player, open: open).frame(height: 56)
                    .floatingGlass(in: Capsule())
            }
        }
    }
}
