import Foundation
import Testing
@testable import FiveMore

struct CountdownTests {
    @Test func roundsUpPartialSeconds() {
        let now = Date(timeIntervalSince1970: 1_000)
        let end = now.addingTimeInterval(4.1)
        #expect(Countdown.remainingSeconds(until: end, now: now) == 5)
    }

    @Test func neverReturnsNegativeTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(Countdown.remainingSeconds(until: now.addingTimeInterval(-10), now: now) == 0)
    }

    @Test func formatsMinutesAndSeconds() {
        #expect(Countdown.displayText(for: 300) == "5:00")
        #expect(Countdown.displayText(for: 59) == "0:59")
    }

    @Test func accessAllowsTrialOrPurchase() {
        #expect(AccessPolicy.canStartMoment(freeUsesRemaining: 1, isUnlocked: false))
        #expect(AccessPolicy.canStartMoment(freeUsesRemaining: 0, isUnlocked: true))
        #expect(!AccessPolicy.canStartMoment(freeUsesRemaining: 0, isUnlocked: false))
    }
}

