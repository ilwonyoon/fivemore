import Foundation

enum Countdown {
    static func remainingSeconds(until endDate: Date, now: Date = .now) -> Int {
        max(0, Int(ceil(endDate.timeIntervalSince(now))))
    }

    static func displayText(for seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

struct AccessPolicy {
    static func canStartMoment(freeUsesRemaining: Int, isUnlocked: Bool) -> Bool {
        isUnlocked || freeUsesRemaining > 0
    }
}

