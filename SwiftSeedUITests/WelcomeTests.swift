import XCTest

@MainActor
final class WelcomeTests: XCTestCase {
    func testGivenInstalledAppWhenOpenedThenWelcomeIsVisible() {
        // Given: The user has installed the app.
        let app = XCUIApplication()

        // When: The user opens the app.
        app.launch()

        // Then: The user sees the app name, welcome message, and feature description in English.
        XCTAssertTrue(app.staticTexts["SwiftSeed"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your next app starts here"].exists)
        XCTAssertTrue(app.staticTexts[
            "A Swift app template for iPhone and iPad. Replace this screen to build your first feature."
        ].exists)
    }

    func testGivenLargestTextWhenOpenedInLandscapeThenWelcomeRemainsReadable() throws {
        // Given: The user needs the largest accessibility text size and uses landscape orientation.
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        // When: The user opens the screen and scrolls to read.
        app.launch()
        XCTAssertTrue(app.staticTexts["SwiftSeed"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.textClipped, .dynamicType])
        app.swipeUp()

        // Then: Text is not clipped and the feature description remains readable.
        XCTAssertTrue(app.staticTexts[
            "A Swift app template for iPhone and iPad. Replace this screen to build your first feature."
        ].isHittable)
    }
}
