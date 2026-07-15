import XCTest

final class awradUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testReadyStoreLaunchSnapshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--awrad-seed-qa-state"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Ready four-tab shell"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
