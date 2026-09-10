import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation for a running moment.
struct MomentLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MomentActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.985, green: 0.972, blue: 0.935))
                .activitySystemActionForegroundColor(Color(red: 0.12, green: 0.13, blue: 0.13))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(Color(red: 0.93, green: 0.57, blue: 0.42))
                        .font(.title2)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: range(context), countsDown: true)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(subtitle(context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Color(red: 0.93, green: 0.57, blue: 0.42))
            } compactTrailing: {
                Text(timerInterval: range(context), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Color(red: 0.93, green: 0.57, blue: 0.42))
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<MomentActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color(red: 0.93, green: 0.57, blue: 0.42))

            VStack(alignment: .leading, spacing: 2) {
                Text(timerInterval: range(context), countsDown: true)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .monospacedDigit()

                Text(subtitle(context))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func range(_ context: ActivityViewContext<MomentActivityAttributes>) -> ClosedRange<Date> {
        let start = context.attributes.startedAt
        let end = context.state.endsAt
        return start < end ? start...end : end...end.addingTimeInterval(1)
    }

    private func subtitle(_ context: ActivityViewContext<MomentActivityAttributes>) -> String {
        context.state.rounds > 1 ? "Round \(context.state.rounds)" : "Five more minutes"
    }
}
