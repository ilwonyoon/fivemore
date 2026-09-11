import AudioToolbox
import AVFoundation
import UIKit

/// Plays the completion alert while the app is in the foreground.
///
/// iOS reserves true alarm behaviour (audio that keeps playing until dismissed,
/// overriding silent mode) for Apple's own Clock app, so a third-party local
/// notification can only fire once for at most 30 seconds. To still get an
/// "until you turn it off" alert, the app repeats a short tone on a timer for
/// as long as the completion screen is showing.
///
/// The clip is the user's pick — own recording, bundled preset, or system
/// tone — resolved fresh on every start so a new choice takes effect
/// immediately. It loops for as long as the completion screen is showing:
///
/// - a short chime repeats every few seconds;
/// - a longer recording replays end to end with a breath between loops.
@MainActor
final class CompletionAlertService {
    static let shared = CompletionAlertService()

    /// System "new mail" chime: short, clear, and not siren-like.
    private static let fallbackToneID: SystemSoundID = 1005

    private let repeatInterval: TimeInterval = 2.5
    private var repeatTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private let haptics = UINotificationFeedbackGenerator()

    private init() {}

    var isPlaying: Bool {
        repeatTask != nil
    }

    /// True when a bundled chime was found, so callers can tell whether the
    /// fallback system tone is in use.
    var isUsingCustomSound: Bool {
        player != nil
    }

    /// Starts the repeating completion alert. Safe to call more than once.
    func start(audioFileName: String? = nil) {
        guard repeatTask == nil else { return }

        configureAudioSession()
        haptics.prepare()
        player = Self.makePlayer(momentVoiceFileName: audioFileName)
        player?.prepareToPlay()

        repeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.playOnce()

                // A long recording replays end to end; a short chime keeps
                // the classic few-seconds pulse.
                let gap = max(self.repeatInterval, (self.player?.duration ?? 0) + 1.0)
                do {
                    try await Task.sleep(for: .seconds(gap))
                } catch {
                    return
                }
            }
        }
    }

    /// Stops the alert. Called when the user acknowledges completion.
    func stop() {
        repeatTask?.cancel()
        repeatTask = nil
        player?.stop()
        player?.currentTime = 0
    }

    private func playOnce() {
        if let player {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(Self.fallbackToneID)
        }

        haptics.notificationOccurred(.success)
    }

    private static func makePlayer(momentVoiceFileName: String?) -> AVAudioPlayer? {
        let url: URL?
        if let momentVoiceFileName,
           FileManager.default.fileExists(atPath: MomentVoiceStore.url(for: momentVoiceFileName).path) {
            url = MomentVoiceStore.url(for: momentVoiceFileName)
        } else {
            switch AlarmSound.currentResolved() {
        case .recording(let fileName):
            let fileURL = AlarmSound.url(forRecording: fileName)
            url = FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        case .preset(let name):
            url = AlarmSound.bundledURL(forPreset: name)
        case .system:
            url = nil
            }
        }

        guard let url else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1
            return player
        } catch {
            return nil
        }
    }

    /// Uses the ambient category so the alert respects the ringer switch and
    /// never interrupts music the family already has playing.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            // A failed session still lets the fallback tone play through the
            // system route, so the alert degrades rather than failing.
        }
    }
}
