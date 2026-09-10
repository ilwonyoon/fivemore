import Foundation
import SwiftData

enum MomentEndReason: String, Codable {
    case completed
    case endedEarly
    case interrupted
}

@Model
final class Moment {
    @Attribute(.unique) var id: UUID
    var photoLocalIdentifier: String
    var capturedAt: Date
    var plannedDurationSeconds: Int
    var endedAt: Date?
    var endReasonRawValue: String?

    /// How many five-more rounds this moment ran. A repeat extends the same
    /// moment rather than creating a new one, so this is the honest record of
    /// how the negotiation actually went.
    var rounds: Int = 1

    var endReason: MomentEndReason? {
        get {
            endReasonRawValue.flatMap(MomentEndReason.init(rawValue:))
        }
        set {
            endReasonRawValue = newValue?.rawValue
        }
    }

    var actualDurationSeconds: Int {
        guard let endedAt else { return plannedDurationSeconds }
        return max(0, Int(endedAt.timeIntervalSince(capturedAt)))
    }

    init(
        id: UUID = UUID(),
        photoLocalIdentifier: String,
        capturedAt: Date = .now,
        plannedDurationSeconds: Int = 300,
        endedAt: Date? = nil,
        endReason: MomentEndReason? = nil,
        rounds: Int = 1
    ) {
        self.id = id
        self.photoLocalIdentifier = photoLocalIdentifier
        self.capturedAt = capturedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.endedAt = endedAt
        self.endReasonRawValue = endReason?.rawValue
        self.rounds = rounds
    }
}

