import AVFoundation
import MediaPlayer
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Podcasts: one player for the whole app, so an episode keeps playing while you read on. A mini player rides above the
/// tab bar, Up Next plays in order when an episode ends, the lock screen has the controls, and every episode picks up
/// where you left off. Back 15, forward 30 and 1x to 2x, like Apple Podcasts. Same rules as web/player.js.
@MainActor
final class Player: ObservableObject {
    static let shared = Player()

    /// The episode loaded, playing or paused; nil hides the mini player.
    @Published private(set) var entry: JournalEntry?
    @Published private(set) var playing = false
    @Published private(set) var duration: Double = 0
    @Published var elapsed: Double = 0
    @Published private(set) var rate: Float = 1
    /// Up Next, in order. Kept across launches.
    @Published private(set) var queue: [JournalEntry] = Player.saved("queue") ?? [] { didSet { Self.save(queue, "queue") } }
    /// While the slider is held the clock stops moving it.
    var scrubbing = false
    /// Sleep timer: pause after some minutes, or stop at the end of this episode. nil is off.
    @Published private(set) var sleep: Sleep?
    enum Sleep: Equatable { case minutes(Int), endOfEpisode }
    private var sleepTask: Task<Void, Never>?

    private var player: AVPlayer?
    private var tick: Any?
    private var ended: NSObjectProtocol?
    static let rates: [Float] = [1, 1.25, 1.5, 2]

    private init() {
        // the last episode comes back paused where you left it, so the mini player is still there after a relaunch
        if let last: JournalEntry = Self.saved("nowPlaying") { load(last) }
    }

    /// Play this episode now. The one playing stops where it is, and its place is kept.
    func start(_ e: JournalEntry) {
        if e.id != entry?.id { load(e) }
        queue.removeAll { $0.id == e.id }
        play()
    }

    func isQueued(_ e: JournalEntry) -> Bool { queue.contains { $0.id == e.id } }

    /// Add to the end of Up Next, or take it out.
    func toggleQueue(_ e: JournalEntry) {
        if isQueued(e) { queue.removeAll { $0.id == e.id } } else if e.id != entry?.id { queue.append(e) }
    }

    private func load(_ entry: JournalEntry) {
        guard let url = Downloads.shared.file(entry) ?? entry.audioURL else { return }   // the saved file plays offline
        unload()
        self.entry = entry
        Self.save(entry, "nowPlaying")
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        player = p
        elapsed = Self.positions[entry.id] ?? 0
        duration = Double(entry.audioSeconds ?? 0)
        if elapsed > 0 { p.seek(to: CMTime(seconds: elapsed, preferredTimescale: 600)) }
        Task { if let d = try? await item.asset.load(.duration).seconds, d.isFinite, d > 0, self.entry?.id == entry.id { duration = d } }
        tick = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self, !self.scrubbing else { return }
                self.elapsed = t.seconds
                if Int(t.seconds) % 5 == 0 { self.remember() }
            }
        }
        ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
    }

    func toggle() { playing ? pause() : play() }

    func play() {
        guard let player else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        player.playImmediately(atRate: rate)
        playing = true
        takeRemote()
        nowPlaying()
    }

    func pause() {
        player?.pause()
        playing = false
        remember()
        nowPlaying()
    }

    func skip(_ by: Double) { seek(to: elapsed + by) }

    func seek(to seconds: Double) {
        let t = min(max(0, seconds), duration > 0 ? duration : .greatestFiniteMagnitude)
        elapsed = t
        player?.seek(to: CMTime(seconds: t, preferredTimescale: 600))
        remember()
        nowPlaying()
    }

    /// 1x, 1.25x, 1.5x, 2x, then back to 1x.
    func nextRate() {
        rate = Self.rates[((Self.rates.firstIndex(of: rate) ?? 0) + 1) % Self.rates.count]
        if playing { player?.rate = rate }
        nowPlaying()
    }

    func setSleep(_ s: Sleep?) {
        sleepTask?.cancel()
        sleep = s
        guard case .minutes(let m) = s else { return }
        sleepTask = Task {
            try? await Task.sleep(for: .seconds(m * 60))
            guard !Task.isCancelled else { return }
            pause()
            sleep = nil
        }
    }

    private func unload() {
        guard let player else { return }
        remember()
        player.pause()
        if let tick { player.removeTimeObserver(tick) }
        if let ended { NotificationCenter.default.removeObserver(ended) }
        tick = nil; ended = nil
        self.player = nil; playing = false
        artwork = nil; artFor = nil
    }

    /// The end of an episode: the next in Up Next plays, or the player clears and the mini player goes.
    private func finish() {
        if let entry { Self.positions[entry.id] = nil; Downloads.shared.remove(entry) }   // played downloads go
        // the sleep timer set to the end of the episode stops here; Up Next waits
        if sleep == .endOfEpisode { sleep = nil } else if let next = queue.first { start(next); return }
        unload()
        entry = nil
        Self.save(JournalEntry?.none, "nowPlaying")
        let center = MPRemoteCommandCenter.shared()
        [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand, center.skipBackwardCommand,
         center.skipForwardCommand, center.changePlaybackPositionCommand].forEach { $0.removeTarget(nil) }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private static func saved<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        UserDefaults.standard.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }

    // MARK: where you left off

    /// Seconds into each episode, by its id. Nearly done counts as done.
    static var positions: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: "positions") as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "positions") }
    }

    private func remember() {
        guard let entry, player != nil else { return }
        Self.positions[entry.id] = elapsed > 5 && (duration == 0 || elapsed < duration - 30) ? elapsed : nil
    }

    // MARK: lock screen and Control Center

    private func takeRemote() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.removeTarget(nil)   // one story's player at a time
        c.playCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.play() }; return .success }
        c.pauseCommand.removeTarget(nil)
        c.pauseCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.pause() }; return .success }
        c.togglePlayPauseCommand.removeTarget(nil)
        c.togglePlayPauseCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.toggle() }; return .success }
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.removeTarget(nil)
        c.skipBackwardCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.skip(-15) }; return .success }
        c.skipForwardCommand.preferredIntervals = [30]
        c.skipForwardCommand.removeTarget(nil)
        c.skipForwardCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.skip(30) }; return .success }
        c.changePlaybackPositionCommand.removeTarget(nil)
        c.changePlaybackPositionCommand.addTarget { [weak self] e in
            guard let e = e as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            MainActor.assumeIsolated { self?.seek(to: e.positionTime) }
            return .success
        }
    }

    private func nowPlaying() {
        guard let entry, player != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: Headline.clean(entry.title, source: entry.sourceTitle),
            MPMediaItemPropertyArtist: entry.sourceTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? Double(rate) : 0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let art = artwork { info[MPMediaItemPropertyArtwork] = art }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
        #endif
        if artwork == nil, let url = entry.imageURL, artFor != url { loadArt(url) }
    }

    private var artwork: MPMediaItemArtwork?
    private var artFor: URL?

    private func loadArt(_ url: URL) {
        artFor = url
        Task {
            let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
            #if os(macOS)
            guard let img = NSImage(data: data) else { return }
            #else
            guard let img = UIImage(data: data) else { return }
            #endif
            artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            nowPlaying()
        }
    }
}

/// "4:20" or "1:02:03".
func clock(_ seconds: Double) -> String {
    let s = Int(max(0, seconds.isFinite ? seconds : 0))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}

#if DEBUG
func clockDemo() {
    assert(clock(260) == "4:20" && clock(3723) == "1:02:03" && clock(.nan) == "0:00", "player clock")
    assert(FeedParser.seconds("1:02:03") == 3723 && FeedParser.seconds("16:40") == 1000 && FeedParser.seconds("600") == 600, "itunes:duration")
    assert(FeedParser.seconds("") == nil && FeedParser.seconds("abc") == nil, "no duration")
}
#endif
