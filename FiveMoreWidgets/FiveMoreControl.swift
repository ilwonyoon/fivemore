import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center / Lock Screen button that opens the camera in one tap.
///
/// Works without unlocking the device to reach the control itself; the app
/// still requires an unlock to come forward, which is an iOS rule for any
/// foreground launch.
@available(iOS 18.0, *)
struct StartMomentControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.fivemore.app.control.start") {
            ControlWidgetButton(action: StartMomentIntent()) {
                Label("5 More", systemImage: "hand.raised.fill")
            }
        }
        .displayName("Start a moment")
        .description("Open the camera and start a 5 More timer.")
    }
}

@main
struct FiveMoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        MomentLiveActivity()

        if #available(iOS 18.0, *) {
            StartMomentControl()
        }
    }
}
