import Foundation
import Testing
@testable import FiveMore

/// Covers the monetization contract from PRD §6.2 and the repeat rules from
/// §5.4.2 — the places where a bug charges a parent wrongly.
struct CaptureRulesTests {

    // MARK: - Automatic capture safety

    @Test func onlyAStableOpenPalmCanAutoCapture() {
        #expect(!CaptureRules.shouldAutoCapture(stableFingerCount: nil))
        #expect(!CaptureRules.shouldAutoCapture(stableFingerCount: 1))
        #expect(!CaptureRules.shouldAutoCapture(stableFingerCount: 3))
        #expect(CaptureRules.shouldAutoCapture(stableFingerCount: 5))
    }

    // MARK: - Free use consumption

    @Test func consumesAFreeUseWhenNotUnlocked() {
        #expect(CaptureRules.shouldConsumeFreeUse(isUnlocked: false))
    }

    @Test func neverConsumesAFreeUseOnceUnlocked() {
        #expect(!CaptureRules.shouldConsumeFreeUse(isUnlocked: true))
    }

    @Test func repeatNeverConsumesAFreeUse() {
        // PRD §5.4.2: the moment was already paid for.
        #expect(!CaptureRules.shouldConsumeFreeUseOnRepeat())
    }

    // MARK: - Access gating

    @Test func opensCameraWhileFreeUsesRemain() {
        #expect(CaptureRules.canOpenCamera(freeUsesRemaining: 1, isUnlocked: false))
    }

    @Test func opensCameraWhenUnlockedWithNoFreeUses() {
        #expect(CaptureRules.canOpenCamera(freeUsesRemaining: 0, isUnlocked: true))
    }

    @Test func blocksCameraWhenExhaustedAndNotUnlocked() {
        #expect(!CaptureRules.canOpenCamera(freeUsesRemaining: 0, isUnlocked: false))
    }

    // MARK: - Restore

    @Test func restoresTheOriginalLength() {
        let started = Date(timeIntervalSince1970: 1_000)
        let record = ActiveTimerRecord(
            momentID: UUID(),
            photoLocalIdentifier: "x",
            startedAt: started,
            endsAt: started.addingTimeInterval(10 * 60)
        )

        #expect(CaptureRules.restoredMinutes(from: record) == 10)
    }

    @Test func neverRestoresAZeroLengthTimer() {
        let started = Date(timeIntervalSince1970: 1_000)
        let record = ActiveTimerRecord(
            momentID: UUID(),
            photoLocalIdentifier: "x",
            startedAt: started,
            endsAt: started.addingTimeInterval(20)
        )

        #expect(CaptureRules.restoredMinutes(from: record) == 1)
    }

    @Test func restoresIntoTheTimerWhileTimeRemains() {
        let now = Date(timeIntervalSince1970: 1_000)
        let record = ActiveTimerRecord(
            momentID: UUID(),
            photoLocalIdentifier: "x",
            startedAt: now,
            endsAt: now.addingTimeInterval(120)
        )

        #expect(CaptureRules.restoredPhase(for: record, now: now) == .timer)
    }

    @Test func restoresIntoCompletionWhenTheTimerAlreadyEnded() {
        let started = Date(timeIntervalSince1970: 1_000)
        let record = ActiveTimerRecord(
            momentID: UUID(),
            photoLocalIdentifier: "x",
            startedAt: started,
            endsAt: started.addingTimeInterval(300)
        )

        // Relaunching well after the timer should have finished.
        let now = started.addingTimeInterval(600)
        #expect(CaptureRules.restoredPhase(for: record, now: now) == .completion)
    }

}
