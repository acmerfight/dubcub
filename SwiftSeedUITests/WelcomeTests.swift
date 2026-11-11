import XCTest

@MainActor
final class WelcomeTests: XCTestCase {
    func testGivenInstalledAppWhenOpenedThenWelcomeIsVisible() {
        // Given: 用户已安装 App。
        let app = XCUIApplication()

        // When: 用户打开 App。
        app.launch()

        // Then: 用户看到应用名称、欢迎信息与当前功能说明。
        XCTAssertTrue(app.staticTexts["SwiftSeed"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["从这里开始你的下一个 App"].exists)
        XCTAssertTrue(app.staticTexts["这是支持 iPhone 和 iPad 的 Swift 应用模板。替换此页面，开始你的第一个功能。"].exists)
    }

    func testGivenLargestTextWhenOpenedInLandscapeThenWelcomeRemainsReadable() throws {
        // Given: 用户需要最大的辅助字号，并横屏使用设备。
        let app = XCUIApplication()
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        // When: 用户打开页面，并向下阅读。
        app.launch()
        XCTAssertTrue(app.staticTexts["SwiftSeed"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.textClipped, .dynamicType])
        app.swipeUp()

        // Then: 文字不被裁切，功能说明仍能读到。
        XCTAssertTrue(app.staticTexts["这是支持 iPhone 和 iPad 的 Swift 应用模板。替换此页面，开始你的第一个功能。"].isHittable)
    }
}
