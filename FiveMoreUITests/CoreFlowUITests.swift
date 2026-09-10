import XCTest

@MainActor
final class CoreFlowUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += ["-FiveMoreUITestResetState"]
        app.launch()
    }

    func testHomeToCameraToTimerKeepsTheCoreFlowUsable() throws {
        let startButton = app.buttons["Take a photo to start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))

        attachScreenshot(named: "01-home")
        startButton.tap()

        XCTAssertTrue(app.buttons["Close camera"].waitForExistence(timeout: 3))
        attachScreenshot(named: "02-camera")

        let shutterButton = app.buttons["Take a photo to start"]
        XCTAssertTrue(shutterButton.waitForExistence(timeout: 2))
        shutterButton.tap()

        handleSystemPromptIfPresent()

        XCTAssertTrue(app.buttons["End early"].waitForExistence(timeout: 8))
        attachScreenshot(named: "03-timer")
    }

    private func handleSystemPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 2) {
            allowButton.tap()
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
