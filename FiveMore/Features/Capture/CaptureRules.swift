import Foundation

/// The four states the capture flow can be in.
enum CapturePhase: Equatable {
    case home
    case camera
    case timer
    case completion
}

/// The monetization and timing rules of the capture flow, expressed as pure
/// functions so they can be tested without a camera, a photo library or a view.
///
/// These encode PRD §6.2 (when a free use is consumed) and §5.4.2 (a repeat
/// extends the existing moment instead of starting a new one). They are the
/// rules where a mistake charges a parent for something they did not agree to,
/// so they are kept out of the view deliberately.
enum CaptureRules {
    /// The normal camera flow is always a five-minute moment.
    static let defaultMinutes = 5

    /// Automatic capture is intentionally narrower than "any detected
    /// fingers": only a verified, stable open palm can start a moment.
    /// This keeps a partial hand or a noisy Vision reading from surprising a
    /// parent with an unintended timer.
    static func shouldAutoCapture(stableFingerCount: Int?) -> Bool {
        stableFingerCount == defaultMinutes
    }

    /// A free use is consumed only when a photo was saved AND a timer started,
    /// and only while the unlock has not been purchased.
    ///
    /// Deliberately excludes: repeats, cancelled captures, failed saves, and
    /// anyone who already owns the unlock.
    static func shouldConsumeFreeUse(isUnlocked: Bool) -> Bool {
        !isUnlocked
    }

    /// A repeat never consumes a use — the moment was already paid for.
    static func shouldConsumeFreeUseOnRepeat() -> Bool {
        false
    }

    /// Whether the camera may be opened, or the paywall must be shown instead.
    static func canOpenCamera(freeUsesRemaining: Int, isUnlocked: Bool) -> Bool {
        AccessPolicy.canStartMoment(
            freeUsesRemaining: freeUsesRemaining,
            isUnlocked: isUnlocked
        )
    }

    /// The length a restored timer should report, recovered from the stored
    /// record so a ten minute moment does not come back as a five minute one.
    static func restoredMinutes(from record: ActiveTimerRecord) -> Int {
        let seconds = Int(record.endsAt.timeIntervalSince(record.startedAt).rounded())
        return max(1, seconds / 60)
    }

    /// The phase a restored session should land in.
    static func restoredPhase(for record: ActiveTimerRecord, now: Date) -> CapturePhase {
        Countdown.remainingSeconds(until: record.endsAt, now: now) == 0 ? .completion : .timer
    }
}
