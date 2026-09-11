import CoreGraphics
import Vision

/// Counts extended fingers in a camera frame using Vision's hand pose model.
///
/// A stable five-finger reading drives the automatic shutter. The normal camera
/// flow always starts one five-minute moment.
struct HandPoseDetector: Sendable {
    /// An open palm has to remain visible for roughly half a second before it
    /// is trusted. This is deliberately conservative because a false capture
    /// is more disruptive than asking the child to hold their hand still.
    static let requiredStableFrames = 12

    /// Vision reports low-confidence joints for partially visible hands, so
    /// joints below this are treated as missing rather than folded.
    private static let minimumJointConfidence: Float = 0.55

    /// Returns five only for one confident, fully open palm. Partial hands and
    /// uncertain frames return nil; they must never map to a timer duration.
    func fingerCount(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Int? {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else {
            return nil
        }

        return Self.isOpenPalm(observation) ? CaptureRules.defaultMinutes : nil
    }

    /// A finger is extended when its tip sits farther from the wrist than the
    /// joint below it, which holds regardless of hand rotation or distance.
    private static func isOpenPalm(_ observation: VNHumanHandPoseObservation) -> Bool {
        guard let wrist = try? observation.recognizedPoint(.wrist),
              wrist.confidence >= minimumJointConfidence else {
            return false
        }

        // The thumb swings more sideways than the other fingers, so it gets a
        // slightly gentler distance threshold. Every finger still has to be
        // longer than its joint below it, with a safety margin for jitter.
        let fingers: [(tip: VNHumanHandPoseObservation.JointName, pip: VNHumanHandPoseObservation.JointName, extensionRatio: CGFloat)] = [
            (.thumbTip, .thumbIP, 1.04),
            (.indexTip, .indexPIP, 1.13),
            (.middleTip, .middlePIP, 1.13),
            (.ringTip, .ringPIP, 1.13),
            (.littleTip, .littlePIP, 1.13)
        ]

        return fingers.allSatisfy { finger in
            guard let tip = try? observation.recognizedPoint(finger.tip),
                  let pip = try? observation.recognizedPoint(finger.pip),
                  tip.confidence >= minimumJointConfidence,
                  pip.confidence >= minimumJointConfidence else {
                return false
            }

            let tipDistance = distance(from: wrist.location, to: tip.location)
            let pipDistance = distance(from: wrist.location, to: pip.location)

            return tipDistance > pipDistance * finger.extensionRatio
        }
    }

    private static func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Smooths per-frame readings into a single trusted count.
///
/// Vision occasionally drops or miscounts a frame, so a reading only becomes
/// stable after it repeats. Callers reset this when leaving the camera.
struct HandPoseStabilizer {
    private var candidate: Int?
    private var streak = 0

    /// Feeds one frame's reading in and returns the count once it is stable.
    mutating func accept(_ count: Int?) -> Int? {
        guard let count else {
            candidate = nil
            streak = 0
            return nil
        }

        if count == candidate {
            streak += 1
        } else {
            candidate = count
            streak = 1
        }

        return streak >= HandPoseDetector.requiredStableFrames ? count : nil
    }

    /// Progress toward a stable reading, for the on-screen countdown ring.
    var progress: Double {
        guard candidate != nil else { return 0 }
        return min(1, Double(streak) / Double(HandPoseDetector.requiredStableFrames))
    }

    var pendingCount: Int? {
        candidate
    }

    mutating func reset() {
        candidate = nil
        streak = 0
    }
}
