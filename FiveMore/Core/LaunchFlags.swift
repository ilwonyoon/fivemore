import Foundation

/// Launch arguments used only by UI tests and screenshot runs.
///
/// Gathered here so the flags stay discoverable and can never be added without
/// their simulator guard. Nothing in this type is read on a real device.
enum LaunchFlags {
    /// Clears any leftover active timer so a UI test starts from Home.
    static var shouldResetState: Bool {
        has("-FiveMoreUITestResetState")
    }

#if targetEnvironment(simulator)
    /// Holds the camera screen instead of firing the shutter, so the
    /// hand-detection UI can be screenshotted.
    static var holdsCamera: Bool {
        has("-FiveMoreHoldCamera")
    }

    /// Renders a hand-detection reading without a camera.
    static var simulatedFingerCount: Int? {
        guard let raw = ProcessInfo.processInfo.arguments
            .drop(while: { $0 != "-FiveMoreSimulateFingers" })
            .dropFirst()
            .first
        else {
            return nil
        }

        return Int(raw)
    }
#endif

    private static func has(_ flag: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }
}
