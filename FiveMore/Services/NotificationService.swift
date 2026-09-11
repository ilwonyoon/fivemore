import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermissionAndSchedule(momentID: UUID, endsAt: Date, audioFileName: String? = nil) async {
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
            content.sound = Self.alarmSound(momentVoiceFileName: audioFileName)
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

    /// The user's picked alarm as a notification sound. Presets ship in the
    /// bundle and the recording plays from Library/Sounds — the two places
    /// iOS looks. Anything missing falls back to the default tone.
    private static func alarmSound(momentVoiceFileName: String?) -> UNNotificationSound {
        if let momentVoiceFileName,
           FileManager.default.fileExists(atPath: MomentVoiceStore.url(for: momentVoiceFileName).path) {
            return UNNotificationSound(named: UNNotificationSoundName(momentVoiceFileName))
        }
        switch AlarmSound.currentResolved() {
        case .recording(let fileName):
            return UNNotificationSound(named: UNNotificationSoundName(fileName))
        case .preset(let name):
            guard let file = AlarmSound.bundledFileName(forPreset: name) else {
                return UNNotificationSound.default
            }
            return UNNotificationSound(named: UNNotificationSoundName(file))
        case .system:
            return UNNotificationSound.default
        }
    }

    /// How many spaced repeats to schedule for a completion the user has not
    /// come back to yet.
    private static let nudgeCount = 4
    private static let nudgeSpacing: TimeInterval = 12

    private static func identifier(for momentID: UUID, index: Int) -> String {
        "five-more.timer.\(momentID.uuidString).\(index)"
    }
}
