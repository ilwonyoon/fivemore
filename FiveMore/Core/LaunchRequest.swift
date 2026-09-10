import Foundation
import Observation

/// Carries a request from outside the app — Siri, the Action Button, a Control
/// Center control — into the capture flow.
///
/// App Intents run before any view exists, so they park the request here and
/// the flow picks it up when it appears.
@MainActor
@Observable
final class LaunchRequest {
    static let shared = LaunchRequest()

    /// Set when something outside the app asked to start a moment. Cleared by
    /// the capture flow once it has acted on it.
    private(set) var pendingMinutes: Int?

    /// A token that changes on every request, so asking twice in a row still
    /// registers as two separate asks.
    private(set) var token = UUID()

    private init() {}

    /// Asks the capture flow to open the camera, optionally with a preset
    /// length. `nil` minutes means "let the fingers or the shutter decide".
    func requestMoment(minutes: Int?) {
        pendingMinutes = minutes
        token = UUID()
    }

    /// Called by the flow once the request has been handled.
    func clear() {
        pendingMinutes = nil
    }
}
