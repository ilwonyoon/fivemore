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
/// The tone is the bundled `CompletionChime` asset when present, and falls back
/// to a system alert tone otherwise, so the flow works before custom audio is
/// added.
@MainActor
final class CompletionAlertService {
    static let shared = CompletionAlertService()

    /// Drop a short chime at `FiveMore/Resources/CompletionChime.caf` (or .m4a
    /// / .wav) and it is picked up automatically on the next build.
    private static let customSoundName = "CompletionChime"
    private static let customSoundExtensions = ["caf", "m4a", "wav", "mp3"]

    /// System "new mail" chime: short, clear, and not siren-like.
    private static let fallbackToneID: SystemSoundID = 1005

    private let repeatInterval: TimeInterval = 2.5
    private var repeatTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private let haptics = UINotificationFeedbackGenerator()

    private init() {
        player = Self.makePlayer()
    }

    var isPlaying: Bool {
        repeatTask != nil
    }

    /// True when a bundled chime was found, so callers can tell whether the
    /// fallback system tone is in use.
    var isUsingCustomSound: Bool {
        player != nil
    }

    /// Starts the repeating completion alert. Safe to call more than once.
    func start() {
        guard repeatTask == nil else { return }

        configureAudioSession()
        haptics.prepare()
        player?.prepareToPlay()

        repeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.playOnce()

                do {
                    try await Task.sleep(for: .seconds(self.repeatInterval))
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

    private static func makePlayer() -> AVAudioPlayer? {
        for ext in customSoundExtensions {
            guard let url = Bundle.main.url(forResource: customSoundName, withExtension: ext) else {
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 1
                return player
            } catch {
                return nil
            }
        }

        return nil
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
