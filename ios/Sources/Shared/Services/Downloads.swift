import CryptoKit
import Foundation

/// Podcasts offline: an episode's audio saved on the device, so it plays on a plane. The player prefers the saved file,
/// and an episode played to the end is removed, Apple Podcasts' default. Not backed up; it can always download again.
/// ponytail: a plain foreground download with a spinner, no background session; add one if long episodes on slow
/// networks need to finish with the app closed. The web streams only: a browser cannot slice a cross-site file for
/// the range requests audio makes.
@MainActor
final class Downloads: ObservableObject {
    static let shared = Downloads()
    /// Episodes downloading now, by id.
    @Published private(set) var busy: Set<String> = []

    private let dir: URL = {
        var d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("episodes", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        var v = URLResourceValues(); v.isExcludedFromBackup = true
        try? d.setResourceValues(v)
        return d
    }()

    /// The saved file, when there is one.
    func file(_ e: JournalEntry) -> URL? {
        guard e.audioURL != nil else { return nil }
        let f = path(e)
        return FileManager.default.fileExists(atPath: f.path) ? f : nil
    }

    func toggle(_ e: JournalEntry) {
        if file(e) != nil { remove(e) } else { Task { await download(e) } }
    }

    func download(_ e: JournalEntry) async {
        guard let url = e.audioURL, !busy.contains(e.id), file(e) == nil else { return }
        busy.insert(e.id)
        defer { busy.remove(e.id) }
        guard let (tmp, response) = try? await URLSession.shared.download(from: url),
              ((response as? HTTPURLResponse)?.statusCode ?? 200) < 400 else { return }
        try? FileManager.default.moveItem(at: tmp, to: path(e))
    }

    func remove(_ e: JournalEntry) {
        try? FileManager.default.removeItem(at: path(e))
        objectWillChange.send()
    }

    /// One file per episode, named by a hash of its id (its link or audio URL), keeping the audio's extension so the
    /// player knows the format.
    private func path(_ e: JournalEntry) -> URL {
        let name = SHA256.hash(data: Data(e.id.utf8)).map { String(format: "%02x", $0) }.joined().prefix(32)
        let ext = ["mp3", "m4a", "aac", "mp4", "wav"].contains(e.audioURL?.pathExtension.lowercased() ?? "") ? e.audioURL!.pathExtension.lowercased() : "mp3"
        return dir.appendingPathComponent(String(name)).appendingPathExtension(ext)
    }
}
