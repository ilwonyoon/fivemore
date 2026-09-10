import Testing
@testable import FiveMore

struct HandPoseStabilizerTests {
    @Test func withholdsCountUntilItRepeats() {
        var stabilizer = HandPoseStabilizer()

        for _ in 0..<(HandPoseDetector.requiredStableFrames - 1) {
            #expect(stabilizer.accept(5) == nil)
        }

        #expect(stabilizer.accept(5) == 5)
    }

    @Test func changingCountRestartsTheStreak() {
        var stabilizer = HandPoseStabilizer()

        for _ in 0..<(HandPoseDetector.requiredStableFrames - 1) {
            _ = stabilizer.accept(5)
        }

        // A different reading must not inherit the previous streak.
        #expect(stabilizer.accept(10) == nil)
        #expect(stabilizer.progress < 1)
    }

    @Test func losingTheHandClearsProgress() {
        var stabilizer = HandPoseStabilizer()
        _ = stabilizer.accept(3)
        _ = stabilizer.accept(3)

        #expect(stabilizer.accept(nil) == nil)
        #expect(stabilizer.progress == 0)
        #expect(stabilizer.pendingCount == nil)
    }

    @Test func reportsProgressTowardStability() {
        var stabilizer = HandPoseStabilizer()
        _ = stabilizer.accept(5)

        let expected = 1.0 / Double(HandPoseDetector.requiredStableFrames)
        #expect(abs(stabilizer.progress - expected) < 0.0001)
    }

    @Test func keepsReportingWhileTheHandIsHeld() {
        var stabilizer = HandPoseStabilizer()

        for _ in 0..<HandPoseDetector.requiredStableFrames {
            _ = stabilizer.accept(2)
        }

        // Still stable on later frames, so the shutter guard is what prevents
        // a second capture rather than the reading disappearing.
        #expect(stabilizer.accept(2) == 2)
    }
}
