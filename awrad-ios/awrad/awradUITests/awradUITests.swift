//
//  awradUITests.swift
//  awradUITests
//
//  Created by FAO on 30/05/26.
//

import XCTest

final class awradUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testCreateGoalQuickCreateSurface() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--awrad-seed-qa-state"]
        app.launch()

        let goalsTab = app.tabBars.buttons["Goals"]
        XCTAssertTrue(goalsTab.waitForExistence(timeout: 8))
        goalsTab.tap()

        let createGoalButton = app.buttons["Create goal"]
        XCTAssertTrue(createGoalButton.waitForExistence(timeout: 4))
        createGoalButton.tap()

        let firstDhikr = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Asthaghfirullahil Azeem")).firstMatch
        XCTAssertTrue(firstDhikr.waitForExistence(timeout: 5))
        firstDhikr.tap()

        XCTAssertTrue(app.staticTexts["Choose goal type"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quick-goal-option-daily"].exists)
        XCTAssertTrue(app.buttons["quick-goal-option-oneTime"].exists)
        XCTAssertTrue(app.buttons["quick-goal-option-tracker"].exists)
        XCTAssertTrue(app.buttons["quick-goal-option-advanced"].exists)
        XCTAssertTrue(app.staticTexts["When will you count?"].exists)
        XCTAssertTrue(app.staticTexts["Configure slots"].exists)
        XCTAssertTrue(app.staticTexts["Anytime target"].exists)
        XCTAssertTrue(app.buttons["100"].exists)

        let timeSlotsButton = app.buttons["Time slots"]
        if !timeSlotsButton.waitForExistence(timeout: 1) {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(timeSlotsButton.waitForExistence(timeout: 2))
        timeSlotsButton.tap()
        XCTAssertTrue(app.staticTexts["Slot 1 target"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Add Time Slot"].exists)

        let prayerSlotsButton = app.buttons["Prayer slots"]
        if !prayerSlotsButton.waitForExistence(timeout: 1) {
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(prayerSlotsButton.waitForExistence(timeout: 2))
        prayerSlotsButton.tap()
        XCTAssertTrue(app.staticTexts["After Fajr target"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["After Maghrib target"].exists)

        let oneTimeButton = app.buttons["quick-goal-option-oneTime"]
        if !oneTimeButton.waitForExistence(timeout: 1) {
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(oneTimeButton.waitForExistence(timeout: 2))
        oneTimeButton.tap()
        XCTAssertTrue(app.staticTexts["Total target count"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["1,000"].exists)
        XCTAssertFalse(app.staticTexts["When will you count?"].exists)
        XCTAssertFalse(app.staticTexts["Configure slots"].exists)
        XCTAssertTrue(app.buttons["Create Target"].exists)

        app.buttons["quick-goal-option-tracker"].tap()
        XCTAssertTrue(app.staticTexts["Tracker"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["This tracker has no target. Every count is recorded without a denominator."].exists)
        XCTAssertFalse(app.staticTexts["When will you count?"].exists)
        XCTAssertFalse(app.staticTexts["Configure slots"].exists)
        XCTAssertTrue(app.buttons["Create Tracker"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Create Goal Quick Create"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCreateGoalAdvancedFlowSurface() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--awrad-seed-qa-state"]
        app.launch()

        let goalsTab = app.tabBars.buttons["Goals"]
        XCTAssertTrue(goalsTab.waitForExistence(timeout: 8))
        goalsTab.tap()

        let createGoalButton = app.buttons["Create goal"]
        XCTAssertTrue(createGoalButton.waitForExistence(timeout: 4))
        createGoalButton.tap()

        let firstDhikr = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Asthaghfirullahil Azeem")).firstMatch
        XCTAssertTrue(firstDhikr.waitForExistence(timeout: 5))
        firstDhikr.tap()

        app.buttons["quick-goal-option-advanced"].tap()
        XCTAssertTrue(app.staticTexts["Select schedule"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Schedule"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Repeat")).firstMatch.exists)

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Choose timing"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Morning/evening"].exists)
        XCTAssertTrue(app.buttons["Custom slots"].exists)

        app.buttons["Morning/evening"].tap()
        XCTAssertTrue(app.staticTexts["Morning"].waitForExistence(timeout: 2))

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Set targets"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.switches["Same target for all slots"].exists)

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Preview goal"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Slots"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "05:00-11:00")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Create Goal"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Create Goal Advanced Flow"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
