import ActivityKit
import Foundation

/// Runs the Lock Screen and Dynamic Island countdown for an active moment.
///
/// The system renders the countdown from an absolute end date, so the activity
/// stays correct without the app pushing updates.
///
/// Activities are looked up from `Activity.activities` rather than held in a
/// property: ActivityKit's `update` and `end` are nonisolated, so a stored
/// handle cannot be handed to them without tripping Swift 6's data-race checks.
enum LiveActivityService {

    /// Starts the activity for a running moment, or updates the one already
    /// showing. Silently does nothing when Live Activities are turned off.
    static func start(startedAt: Date, endsAt: Date, rounds: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = MomentActivityAttributes.ContentState(endsAt: endsAt, rounds: rounds)
        let content = ActivityContent(state: state, staleDate: endsAt)

        if let existing = Activity<MomentActivityAttributes>.activities.first {
            await existing.update(content)
            return
        }

        // A failed activity must never block the timer itself.
        _ = try? Activity.request(
            attributes: MomentActivityAttributes(startedAt: startedAt),
            content: content,
            pushType: nil
        )
    }

    /// Ends every activity when the moment finishes or the user leaves it.
    static func stop() async {
        for activity in Activity<MomentActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
