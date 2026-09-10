import ActivityKit
import Foundation

/// Describes the running-timer Live Activity shown on the Lock Screen and in
/// the Dynamic Island.
///
/// Keeps the parent from reopening the app just to see how long is left, which
/// is the whole reason the timer exists.
struct MomentActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Absolute end time, so the system renders the countdown itself and
        /// stays correct without updates.
        var endsAt: Date

        /// Which round this is; shown only when a moment has been repeated.
        var rounds: Int
    }

    /// When the current round started, for the progress range.
    var startedAt: Date
}
