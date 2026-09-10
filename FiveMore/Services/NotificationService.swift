import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermissionAndSchedule(momentID: UUID, endsAt: Date) async {
        let settings = await center.notificationSettings()
        let isAuthorized: Bool

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied, .ephemeral:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else { return }

        // iOS caps a notification sound at 30s and will not loop it, and true
        // alarm behaviour is reserved for Apple's Clock app. Scheduling a few
        // spaced-out notifications is the closest a third-party app can get to
        // an alert that keeps going until it is acknowledged.
        let baseInterval = max(1, endsAt.timeIntervalSinceNow)

        for index in 0..<Self.nudgeCount {
            let content = UNMutableNotificationContent()
            content.title = "Time’s up"
            content.body = "That’s five. Your moment is saved."
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: baseInterval + Double(index) * Self.nudgeSpacing,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.identifier(for: momentID, index: index),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    func cancel(momentID: UUID) {
        let identifiers = (0..<Self.nudgeCount).map {
            Self.identifier(for: momentID, index: $0)
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// How many spaced repeats to schedule for a completion the user has not
    /// come back to yet.
    private static let nudgeCount = 4
    private static let nudgeSpacing: TimeInterval = 12

    private static func identifier(for momentID: UUID, index: Int) -> String {
        "five-more.timer.\(momentID.uuidString).\(index)"
    }
}

