import AppIntents

/// Starts a 5 More moment from outside the app.
///
/// One intent serves every fast entry point: Siri, Spotlight, the Action
/// Button, Control Center and the Lock Screen control. Opening the app is
/// required because the moment begins with a photo, and capture needs the
/// screen.
struct StartMomentIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a 5 More moment"

    static let description = IntentDescription(
        "Opens the camera so you can take a photo and start the timer.",
        categoryName: "Timer"
    )

    /// The photo is the start of a moment, so the app has to come forward.
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Minutes",
        description: "How long the moment should run. Leave empty to use five minutes.",
        inclusiveRange: (1, 60)
    )
    var minutes: Int?

    @MainActor
    func perform() async throws -> some IntentResult {
        LaunchRequest.shared.requestMoment(minutes: minutes ?? 5)
        return .result()
    }
}

/// The phrases Siri and Spotlight recognise out of the box.
///
/// Apple requires the app name inside every phrase, so these are starting
/// points rather than the final wording. People can add their own trigger in
/// the Shortcuts app, and `StartMomentIntent` is exposed there for exactly that
/// reason.
struct FiveMoreShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMomentIntent(),
            phrases: [
                "\(.applicationName)",
                "Start \(.applicationName)",
                "\(.applicationName) 시작",
                "\(.applicationName) 더"
            ],
            shortTitle: "Five more minutes",
            systemImageName: "hand.raised.fill"
        )
    }
}
