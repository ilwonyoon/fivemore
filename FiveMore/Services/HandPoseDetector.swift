import CoreGraphics
import Vision

/// Counts extended fingers in a camera frame using Vision's hand pose model.
///
/// The count drives both the shutter and the timer length: showing five fingers
/// starts a five minute moment, ten fingers starts ten.
struct HandPoseDetector: Sendable {
    /// Fingers must stay at the same count for this many consecutive frames
    /// before the reading is trusted, which keeps a hand moving into position
    /// from firing the shutter early.
    static let requiredStableFrames = 8

    /// Vision reports low-confidence joints for partially visible hands, so
    /// joints below this are treated as missing rather than folded.
    private static let minimumJointConfidence: Float = 0.3

    /// Returns the number of extended fingers across every detected hand,
    /// or nil when no hand is visible.
    func fingerCount(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Int? {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }

        let total = observations.reduce(0) { partial, observation in
            partial + Self.extendedFingerCount(in: observation)
        }

        return total > 0 ? total : nil
    }

    /// A finger is extended when its tip sits farther from the wrist than the
    /// joint below it, which holds regardless of hand rotation or distance.
    private static func extendedFingerCount(in observation: VNHumanHandPoseObservation) -> Int {
        guard let wrist = try? observation.recognizedPoint(.wrist),
              wrist.confidence >= minimumJointConfidence else {
            return 0
        }

        let fingers: [(tip: VNHumanHandPoseObservation.JointName, pip: VNHumanHandPoseObservation.JointName)] = [
            (.thumbTip, .thumbIP),
            (.indexTip, .indexPIP),
            (.middleTip, .middlePIP),
            (.ringTip, .ringPIP),
            (.littleTip, .littlePIP)
        ]

        return fingers.reduce(0) { count, finger in
            guard let tip = try? observation.recognizedPoint(finger.tip),
                  let pip = try? observation.recognizedPoint(finger.pip),
                  tip.confidence >= minimumJointConfidence,
                  pip.confidence >= minimumJointConfidence else {
                return count
            }

            let tipDistance = distance(from: wrist.location, to: tip.location)
            let pipDistance = distance(from: wrist.location, to: pip.location)

            return tipDistance > pipDistance ? count + 1 : count
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
