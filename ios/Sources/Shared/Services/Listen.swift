import AVFoundation

/// Listen: the system voice reads the headline and the story, on device. Leaving the story stops it.
@MainActor
final class Listener: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speaking = false
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func toggle(_ entry: JournalEntry) {
        if speaking { stop(); return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        #endif
        synth.speak(AVSpeechUtterance(string: Headline.clean(entry.title, source: entry.sourceTitle) + ". " + entry.plainText))
        speaking = true
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
}
