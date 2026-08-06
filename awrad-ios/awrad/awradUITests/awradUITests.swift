import Network
import XCTest

final class awradUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingRestoresTheExactStep() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--awrad-reset-state"]
        app.launch()

        XCTAssertTrue(app.staticTexts["بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Welcome to Awrad"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your daily dhikr companion"].exists)

        let begin = app.buttons["Begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 3))
        begin.tap()
        XCTAssertTrue(app.staticTexts["Choose your language"].waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.staticTexts["Choose your language"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Begin"].exists)
    }

    @MainActor
    func testOnboardingCannotPassNotificationsWithoutPermission() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--awrad-reset-state", "--awrad-ui-force-notifications-undetermined"]
        app.launch()

        XCTAssertTrue(app.staticTexts["بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"].waitForExistence(timeout: 3))
        app.tap() // Match Android's tap-to-skip cinematic behavior.

        let begin = app.buttons["Begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 3))
        begin.tap()

        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()

        let guest = app.buttons["Continue as guest"]
        XCTAssertTrue(guest.waitForExistence(timeout: 3))
        guest.tap()

        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Onboarding QA")
        next.tap()

        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        skip.tap()

        XCTAssertTrue(app.buttons["Enable notifications"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Skip"].exists)
        XCTAssertTrue(next.exists)
        XCTAssertFalse(next.isEnabled)
    }

    @MainActor
    func testSeededShellExposesEveryParityRoot() throws {
        let app = launchSeededApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        for tab in ["Home", "Goals", "Library", "Community"] {
            XCTAssertTrue(tabBar.buttons[tab].exists, "Missing root tab: \(tab)")
        }

        openDeepLink("awrad://goals")
        XCTAssertTrue(app.staticTexts["My Goals"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Today"].exists)

        openDeepLink("awrad://library")
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Search dhikr"].exists)

        openCommunityRoot(in: app)
        XCTAssertTrue(app.navigationBars["Community"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Join the Community"].exists)
    }

    @MainActor
    func testGoalPortfolioOpensTheCurrentSinglePageCreator() throws {
        let app = launchSeededApp()
        openDeepLink("awrad://goals")

        let createGoal = app.buttons["Create goal"]
        XCTAssertTrue(createGoal.waitForExistence(timeout: 4))
        createGoal.tap()

        XCTAssertTrue(app.navigationBars["Choose Dhikr"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["Next"].exists, "The removed wizard must not return")
    }

    @MainActor
    func testLibraryDhikrHeaderShowsSearchAndCreateActions() throws {
        let app = launchSeededApp()
        openDeepLink("awrad://library")

        XCTAssertTrue(app.buttons["Search dhikr"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Create Dhikr"].waitForExistence(timeout: 4))

        let dhikrsTab = app.buttons["Dhikrs"]
        let wirdsTab = app.buttons["Wirds"]
        XCTAssertTrue(dhikrsTab.waitForExistence(timeout: 4))
        XCTAssertTrue(wirdsTab.exists)
        XCTAssertTrue(dhikrsTab.isSelected)
        wirdsTab.tap()
        XCTAssertTrue(app.staticTexts["Dalail al-Khayrat"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGoalsAndLibraryPagersTrackTapAndSwipeSelection() throws {
        let app = launchSeededApp()

        openDeepLink("awrad://goals")
        let activeTab = app.buttons["Active"]
        let historyTab = app.buttons["History"]
        XCTAssertTrue(activeTab.waitForExistence(timeout: 4))
        XCTAssertTrue(historyTab.exists)
        XCTAssertTrue(activeTab.isSelected)

        let goalsPager = app.descendants(matching: .any)["goals.pager"]
        XCTAssertTrue(goalsPager.waitForExistence(timeout: 3))
        goalsPager.swipeLeft()
        XCTAssertTrue(waitUntilSelected(historyTab, timeout: 3))
        goalsPager.swipeRight()
        XCTAssertTrue(waitUntilSelected(activeTab, timeout: 3))
        historyTab.tap()
        XCTAssertTrue(waitUntilSelected(historyTab, timeout: 3))

        openDeepLink("awrad://library")
        let dhikrsTab = app.buttons["Dhikrs"]
        let wirdsTab = app.buttons["Wirds"]
        XCTAssertTrue(dhikrsTab.waitForExistence(timeout: 4))
        XCTAssertTrue(wirdsTab.exists)
        XCTAssertTrue(dhikrsTab.isSelected)

        let libraryPager = app.descendants(matching: .any)["library.pager"]
        XCTAssertTrue(libraryPager.waitForExistence(timeout: 3))
        libraryPager.swipeLeft()
        XCTAssertTrue(waitUntilSelected(wirdsTab, timeout: 3))
        libraryPager.swipeRight()
        XCTAssertTrue(waitUntilSelected(dhikrsTab, timeout: 3))
        wirdsTab.tap()
        XCTAssertTrue(waitUntilSelected(wirdsTab, timeout: 3))
    }

    @MainActor
    func testQuranDhikrCreatesGoalAndKeepsCountingContextInReader() throws {
        let app = launchSeededApp()
        openDeepLink("awrad://library")

        app.buttons["Search dhikr"].tap()
        let search = app.textFields["Search dhikr"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.typeText("Surah Ikhlas")

        let openSurah = app.buttons["Open Surah Ikhlas"]
        XCTAssertTrue(openSurah.waitForExistence(timeout: 5))
        openSurah.tap()

        XCTAssertTrue(app.navigationBars["Surah Ikhlas"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Create Goal"].waitForExistence(timeout: 3))
        app.buttons["Create Goal"].tap()

        XCTAssertTrue(app.navigationBars["Create goal"].waitForExistence(timeout: 4))
        let createGoal = app.buttons["quick-goal-create-button"]
        XCTAssertTrue(createGoal.waitForExistence(timeout: 3))
        XCTAssertTrue(createGoal.isEnabled)
        createGoal.tap()

        XCTAssertTrue(app.navigationBars["Surah Ikhlas"].waitForExistence(timeout: 6))
        let openCounter = app.buttons["Open Counter"]
        XCTAssertTrue(openCounter.waitForExistence(timeout: 4))
        openCounter.tap()

        dismissCountingCoachIfNeeded(in: app)
        XCTAssertTrue(app.buttons["See full"].waitForExistence(timeout: 4))
        app.buttons["See full"].tap()

        XCTAssertTrue(app.navigationBars["Surah Ikhlas"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Text size"].exists)
        XCTAssertTrue(app.staticTexts["Line spacing"].exists)
        XCTAssertTrue(app.buttons["COUNT"].exists)

        app.buttons["COUNT"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "1 /")).firstMatch
                .waitForExistence(timeout: 3),
            "Reader must keep goal and slot identity when it increments"
        )
    }

    @MainActor
    func testGoalDetailEditorsAndCounterLifecycleRoutes() throws {
        let app = launchSeededApp()
        openDeepLink("awrad://goals")

        XCTAssertTrue(app.staticTexts["Swalath al Nariyya"].waitForExistence(timeout: 4))
        openGoalMenuRoute("Edit count rules", navigationTitle: "Edit count rules", in: app)
        openGoalMenuRoute("Edit schedule", navigationTitle: "Edit schedule", in: app)
        openGoalMenuRoute("Edit reminders", navigationTitle: "Edit reminders", in: app)

        app.staticTexts["Swalath al Nariyya"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Goal details"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Overview"].exists)
        XCTAssertTrue(app.staticTexts["Sessions"].exists)

        let beginCounting = app.buttons["Begin counting"]
        XCTAssertTrue(beginCounting.waitForExistence(timeout: 4))
        beginCounting.tap()

        dismissCountingCoachIfNeeded(in: app)
        XCTAssertTrue(app.buttons["Count"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["View history"].exists)
        XCTAssertTrue(app.buttons["Set session target"].exists)
        app.buttons["Count"].tap()

        app.buttons["View history"].tap()
        XCTAssertTrue(app.navigationBars["Count History"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testWirdListDetailReaderAndCreateRoutes() throws {
        let app = launchSeededApp()
        openDeepLink("awrad://library")

        let wirdsTab = app.buttons["Wirds"]
        XCTAssertTrue(wirdsTab.waitForExistence(timeout: 4))
        wirdsTab.tap()

        XCTAssertTrue(app.staticTexts["Dalail al-Khayrat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create wird"].exists)
        app.buttons["Create wird"].tap()

        XCTAssertTrue(app.navigationBars["Create Wird"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.textFields["Name (English)"].exists)
        XCTAssertTrue(app.staticTexts["Schedule"].exists)
        XCTAssertTrue(app.staticTexts["Sections"].exists)
        XCTAssertFalse(app.buttons["Create wird"].isEnabled, "A custom wird needs a countable section")
        tapBack(in: app)

        let collection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Dalail al-Khayrat")
        ).firstMatch
        if collection.waitForExistence(timeout: 2) {
            collection.tap()
        } else {
            app.staticTexts["Dalail al-Khayrat"].firstMatch.tap()
        }

        XCTAssertTrue(app.navigationBars["Dalail al-Khayrat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["8"].exists)
        XCTAssertTrue(app.buttons["Begin recitation"].waitForExistence(timeout: 3))
        app.buttons["Begin recitation"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["wird.reader.surface"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Reading mode"].exists)
        XCTAssertTrue(
            app.buttons["Previous section"].exists || app.buttons["Next section"].exists,
            "The canonical eight-part reader must expose adjacent-part navigation"
        )
    }

    @MainActor
    func testWirdReaderSmokeInLightDarkAndArabicRTL() throws {
        let configurations: [(name: String, arguments: [String], isRTL: Bool)] = [
            ("Light", ["--awrad-ui-force-light-theme"], false),
            ("Dark", ["--awrad-ui-force-dark-theme"], false),
            ("Arabic RTL", ["--awrad-ui-force-light-theme", "--awrad-ui-force-arabic"], true)
        ]

        for configuration in configurations {
            let app = openSeededWirdReader(additionalArguments: configuration.arguments)
            let surface = app.descendants(matching: .any)["wird.reader.surface"]
            XCTAssertTrue(surface.waitForExistence(timeout: 5), "Missing reader surface in \(configuration.name)")

            let activeLine = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "wird.reader.active.")
            ).firstMatch
            XCTAssertTrue(activeLine.waitForExistence(timeout: 3), "Missing active line in \(configuration.name)")

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Wird Reader - \(configuration.name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            if configuration.isRTL {
                let close = app.buttons["wird.reader.close"]
                XCTAssertTrue(close.waitForExistence(timeout: 2))
                XCTAssertGreaterThan(close.frame.midX, app.frame.midX, "Close control should mirror in RTL")
            }
            app.terminate()
        }
    }

    @MainActor
    func testWirdReaderActiveLineAndProgressAdvanceWhenScrolling() throws {
        let app = openSeededWirdReader(additionalArguments: ["--awrad-ui-force-light-theme"])
        let surface = app.descendants(matching: .any)["wird.reader.surface"]
        let position = app.staticTexts["wird.reader.position"]
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        XCTAssertTrue(position.waitForExistence(timeout: 3))

        let initialActive = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wird.reader.active.")
        ).firstMatch
        XCTAssertTrue(initialActive.waitForExistence(timeout: 3))
        let initialIdentifier = initialActive.identifier
        let initialPosition = position.label

        let advancedActive = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier != %@",
                "wird.reader.active.",
                initialIdentifier
            )
        ).firstMatch
        for _ in 0..<8 where !advancedActive.exists {
            surface.swipeUp()
        }

        XCTAssertTrue(
            advancedActive.waitForExistence(timeout: 3),
            "Expected the active Wird segment to change after scrolling from \(initialIdentifier)"
        )
        XCTAssertNotEqual(position.label, initialPosition, "Expected the reader position to advance")
    }

    @MainActor
    func testFinalWirdSegmentCompletesAtTopTenPercent() throws {
        let app = openSeededWirdReader(additionalArguments: ["--awrad-ui-wird-final-segment"])
        let surface = app.descendants(matching: .any)["wird.reader.surface"]
        let finish = app.buttons["wird.reader.finish"]
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 / 2"].waitForExistence(timeout: 3))
        XCTAssertFalse(finish.exists)

        for _ in 0..<4 where !finish.exists {
            surface.swipeUp()
        }

        XCTAssertTrue(
            finish.waitForExistence(timeout: 3),
            "Expected the final ordinary dhikr to complete at the top-ten-percent threshold"
        )
    }

    @MainActor
    func testSettingsSectionsRemainInAndroidParityOrder() throws {
        let app = launchSeededApp()
        openDeepLink("awrad://settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 4))

        let expectedOrder = [
            "Profile",
            "Appearance",
            "Counting Preferences",
            "Date & Calendar",
            "Notifications",
            "Prayer Times",
            "Audio Library",
            "Language",
            "Data Management",
            "About"
        ]
        assertTextsAppearInScrollOrder(expectedOrder, in: app)
    }

    @MainActor
    func testAuthNavigationPasswordValidationAndForgotPasswordSuccess() throws {
        let server = try LoopbackAuthServer()
        try server.start()
        defer { server.stop() }

        let app = launchSeededApp(additionalArguments: [
            "--awrad-ui-testing",
            "--awrad-auth-base-url",
            server.baseURL.absoluteString
        ])
        openCommunityRoot(in: app)
        ensureGuestCommunity(in: app)

        XCTAssertTrue(app.buttons["Sign Up"].waitForExistence(timeout: 4))
        app.buttons["Sign Up"].tap()
        XCTAssertTrue(app.navigationBars["Sign Up"].waitForExistence(timeout: 4))

        let signupEmail = app.textFields["Email"]
        let signupPassword = app.secureTextFields["Password"]
        signupEmail.tap()
        signupEmail.typeText("ui@example.test")
        signupPassword.tap()
        typeSecureText("alllowercase", into: signupPassword)
        XCTAssertFalse(app.buttons["Sign Up"].isEnabled)

        for _ in "alllowercase" {
            signupPassword.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        typeSecureText("StrongPassword1", into: signupPassword)
        signupEmail.tap()
        XCTAssertTrue(
            waitUntilEnabled(app.buttons["Sign Up"].firstMatch, timeout: 3),
            "Expected valid signup values to enable submission; email=\(String(describing: signupEmail.value)), password=\(String(describing: signupPassword.value))"
        )

        app.buttons["Already have an account? Log In"].tap()
        XCTAssertTrue(app.navigationBars["Log In"].waitForExistence(timeout: 4))
        dismissPasswordManagerPromptIfNeeded(in: app)
        let forgotPassword = app.buttons["Forgot Password"]
        XCTAssertTrue(forgotPassword.exists)
        for _ in 0..<2 where !forgotPassword.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(forgotPassword.isHittable)
        forgotPassword.tap()

        XCTAssertTrue(app.navigationBars["Forgot Password"].waitForExistence(timeout: 4))
        let forgotEmail = app.textFields["Email"]
        forgotEmail.tap()
        forgotEmail.typeText("ui@example.test")
        let sendReset = app.buttons["Send Reset Link"]
        XCTAssertTrue(sendReset.isEnabled)
        sendReset.tap()

        XCTAssertTrue(app.staticTexts["Check your email"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["We sent a password reset link to your email."].exists)
        XCTAssertTrue(app.buttons["Back to Log In"].exists)
    }

    @MainActor
    func testAuthDeepLinksAndStaleDhikrLinkHaveRecoverableDestinations() throws {
        let app = launchSeededApp()

        openDeepLink("awrad://reset-password?token=ui-test-token")
        XCTAssertTrue(app.navigationBars["Reset Password"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.secureTextFields["New password"].exists)
        XCTAssertTrue(app.secureTextFields["Confirm new password"].exists)
        XCTAssertFalse(app.buttons["Reset Password"].isEnabled)

        openDeepLink("awrad://verify-email?token=ui-verification-token")
        XCTAssertTrue(app.navigationBars["Verify Email"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Verifying and signing you in…"].waitForExistence(timeout: 4))

        openDeepLink("awrad://counting?dhikr=removed-from-library")
        XCTAssertTrue(app.staticTexts["Dhikr not found"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["The requested dhikr is not available in this library."].exists)

        openDeepLink("awrad://library")
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    @MainActor
    func testHomeGoalAndWirdCatalogCardsUseCompactContent() throws {
        let app = launchSeededApp()

        let continueGoal = app.buttons["home.continueGoal"]
        XCTAssertTrue(continueGoal.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Continue ")
        ).firstMatch.exists)

        openDeepLink("awrad://wirds")
        let wirdCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wird.collection.")
        ).firstMatch
        XCTAssertTrue(wirdCard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Salawat"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "8 sections")
        ).firstMatch.exists)
        XCTAssertFalse(app.staticTexts[
            "A complete Arabic wird of prayers and blessings upon the Prophet Muhammad ﷺ, compiled by Imam Muhammad ibn Sulayman al-Jazuli."
        ].exists)
    }

    @MainActor
    func testProgressSyncAcrossRealIOSAndAndroidClients() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["AWRAD_SYNC_QA_EMAIL"],
              let password = environment["AWRAD_SYNC_QA_PASSWORD"],
              let markerPath = environment["AWRAD_SYNC_QA_ANDROID_DONE_FILE"] else {
            throw XCTSkip("Real progress-sync QA credentials and marker path were not supplied")
        }

        let markerURL = URL(fileURLWithPath: markerPath)
        try? FileManager.default.removeItem(at: markerURL)

        let app = launchSeededApp()
        openCommunityRoot(in: app)
        ensureGuestCommunity(in: app)

        let login = app.buttons["Log In"]
        XCTAssertTrue(login.waitForExistence(timeout: 4))
        login.tap()
        XCTAssertTrue(app.navigationBars["Log In"].waitForExistence(timeout: 4))

        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        emailField.tap()
        emailField.typeText(email)
        passwordField.tap()
        typeSecureText(password, into: passwordField)

        let submit = app.buttons["Log In"].firstMatch
        XCTAssertTrue(waitUntilEnabled(submit, timeout: 3))
        submit.tap()
        XCTAssertTrue(app.buttons["Account menu"].waitForExistence(timeout: 8))

        openDeepLink("awrad://goals")
        let goalTitle = app.staticTexts["Swalath al Nariyya"].firstMatch
        XCTAssertTrue(goalTitle.waitForExistence(timeout: 12))
        goalTitle.tap()
        let beginCounting = app.buttons["Begin counting"]
        let countButton = app.buttons["Count"]
        if !countButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(beginCounting.waitForExistence(timeout: 4))
            beginCounting.tap()
        }
        dismissCountingCoachIfNeeded(in: app)

        XCTAssertTrue(countButton.waitForExistence(timeout: 4))
        countButton.tap()
        XCTAssertTrue(
            waitForAccessibilityValue(countButton, prefix: "1 ", timeout: 5),
            "The iOS contribution must be visible before Android joins the same account"
        )

        let marker = ProgressSyncQAMarker(url: markerURL)
        let androidFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: marker
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [androidFinished], timeout: 180),
            .completed,
            "Android did not finish its same-account contribution in time"
        )

        app.terminate()
        app.launchArguments = []
        app.launch()
        openDeepLink("awrad://goals")
        XCTAssertTrue(goalTitle.waitForExistence(timeout: 12))
        goalTitle.tap()
        if !countButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(beginCounting.waitForExistence(timeout: 4))
            beginCounting.tap()
        }
        dismissCountingCoachIfNeeded(in: app)

        XCTAssertTrue(
            waitForAccessibilityValue(countButton, prefix: "2 ", timeout: 15),
            "iOS must pull the merged canonical count after Android contributes"
        )
    }

    @MainActor
    func testProgressSyncPullsExistingAndroidContribution() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AWRAD_SYNC_QA_VERIFY_EXISTING"] == "1",
              let email = environment["AWRAD_SYNC_QA_EMAIL"],
              let password = environment["AWRAD_SYNC_QA_PASSWORD"] else {
            throw XCTSkip("Existing cross-device progress-sync verification credentials were not supplied")
        }

        let app = launchSeededApp()
        openCommunityRoot(in: app)
        ensureGuestCommunity(in: app)

        let login = app.buttons["Log In"]
        XCTAssertTrue(login.waitForExistence(timeout: 4))
        login.tap()
        XCTAssertTrue(app.navigationBars["Log In"].waitForExistence(timeout: 4))

        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        emailField.tap()
        emailField.typeText(email)
        passwordField.tap()
        typeSecureText(password, into: passwordField)

        let submit = app.buttons["Log In"].firstMatch
        XCTAssertTrue(waitUntilEnabled(submit, timeout: 3))
        submit.tap()
        XCTAssertTrue(app.buttons["Account menu"].waitForExistence(timeout: 8))

        openDeepLink("awrad://goals")
        let syncedGoal = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Swalath al Nariyya, 2,")
        ).firstMatch
        XCTAssertTrue(
            syncedGoal.waitForExistence(timeout: 20),
            "The goals list must expose Android's canonical count before opening the counter"
        )
        syncedGoal.tap()

        let beginCounting = app.buttons["Begin counting"]
        let countButton = app.buttons["Count"]
        if !countButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(beginCounting.waitForExistence(timeout: 4))
            beginCounting.tap()
        }
        dismissCountingCoachIfNeeded(in: app)

        XCTAssertTrue(
            waitForAccessibilityValue(countButton, prefix: "2 ", timeout: 20),
            "iOS must pull Android's accepted contribution and display canonical count 2"
        )
    }

    @MainActor
    func testLaunchPerformanceForReadyStore() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["--awrad-seed-qa-state"]
            app.launch()
        }
    }

    @MainActor
    private func launchSeededApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--awrad-seed-qa-state"] + additionalArguments
        app.launch()
        if !app.tabBars.firstMatch.waitForExistence(timeout: 10) {
            openDeepLink("awrad://home")
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        openDeepLink("awrad://home")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
        return app
    }

    private func waitForAccessibilityValue(
        _ element: XCUIElement,
        prefix: String,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "value BEGINSWITH %@", prefix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func openSeededWirdReader(additionalArguments: [String]) -> XCUIApplication {
        let app = launchSeededApp(additionalArguments: additionalArguments)
        openDeepLink("awrad://wirds")

        let collection = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "wird.collection.")
        ).firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 5))
        collection.tap()

        let begin = app.buttons["wird.detail.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()
        return app
    }

    @MainActor
    private func openDeepLink(_ rawURL: String) {
        guard let url = URL(string: rawURL) else {
            XCTFail("Invalid test deep link: \(rawURL)")
            return
        }
        XCUIDevice.shared.system.open(url)
    }

    @MainActor
    private func tapBack(in app: XCUIApplication) {
        let back = app.navigationBars.firstMatch.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 3), "Expected a navigation back button")
        back.tap()
    }

    @MainActor
    private func openCommunityRoot(in app: XCUIApplication) {
        openDeepLink("awrad://home")
        let community = app.tabBars.buttons["Community"]
        XCTAssertTrue(community.waitForExistence(timeout: 3))
        community.tap()

        for _ in 0..<8 {
            if app.navigationBars["Community"].exists { break }
            let back = app.navigationBars.firstMatch.buttons.firstMatch
            guard back.exists else { break }
            back.tap()
        }
        XCTAssertTrue(app.navigationBars["Community"].waitForExistence(timeout: 4))
    }

    @MainActor
    private func openGoalMenuRoute(_ route: String, navigationTitle: String, in app: XCUIApplication) {
        let menu = app.buttons["Goal actions"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        XCTAssertTrue(app.buttons[route].waitForExistence(timeout: 2))
        app.buttons[route].tap()
        XCTAssertTrue(app.navigationBars[navigationTitle].waitForExistence(timeout: 4))
        tapBack(in: app)
        XCTAssertTrue(app.staticTexts["Swalath al Nariyya"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func dismissCountingCoachIfNeeded(in app: XCUIApplication) {
        let skip = app.buttons["counting-coach-skip"]
        if skip.waitForExistence(timeout: 2) {
            skip.tap()
            XCTAssertTrue(skip.waitForNonExistence(timeout: 3))
        }
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitUntilSelected(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func typeSecureText(_ text: String, into field: XCUIElement) {
        // iOS 26's new-password AutoFill field collapses an atomic XCTest
        // typeText payload to one secure token. Individual key events exercise
        // the same binding reliably without disabling password AutoFill in-app.
        for character in text {
            field.typeText(String(character))
        }
    }

    @MainActor
    private func dismissPasswordManagerPromptIfNeeded(in app: XCUIApplication) {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 2) {
            notNow.tap()
        }
    }

    @MainActor
    private func ensureGuestCommunity(in app: XCUIApplication) {
        guard !app.buttons["Sign Up"].waitForExistence(timeout: 2) else { return }
        let accountMenu = app.buttons["Account menu"]
        XCTAssertTrue(accountMenu.waitForExistence(timeout: 3), "Community must expose guest or account actions")
        accountMenu.tap()
        XCTAssertTrue(app.buttons["Log Out"].waitForExistence(timeout: 2))
        app.buttons["Log Out"].tap()
        XCTAssertTrue(app.buttons["Sign Up"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertTextsAppearInScrollOrder(_ labels: [String], in app: XCUIApplication) {
        let container: XCUIElement
        if app.collectionViews.firstMatch.exists {
            container = app.collectionViews.firstMatch
        } else if app.tables.firstMatch.exists {
            container = app.tables.firstMatch
        } else {
            container = app.scrollViews.firstMatch
        }

        var swipeCount = 0
        var previous: (swipes: Int, y: CGFloat)?

        for label in labels {
            let element = app.staticTexts[label].firstMatch
            var attempts = 0
            while attempts < 10, !(element.exists && element.isHittable) {
                container.swipeUp(velocity: .slow)
                swipeCount += 1
                attempts += 1
            }
            XCTAssertTrue(element.exists && element.isHittable, "Missing Settings section in order: \(label)")

            let current = (swipes: swipeCount, y: element.frame.minY)
            if let previous, previous.swipes == current.swipes {
                XCTAssertGreaterThanOrEqual(
                    current.y,
                    previous.y,
                    "Settings section \(label) appeared before its Android predecessor"
                )
            }
            previous = current
        }
    }
}

private final class ProgressSyncQAMarker: NSObject {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    @objc dynamic var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

private final class LoopbackAuthServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "app.awrad.ui-tests.auth-server")
    private let ready = DispatchSemaphore(value: 0)
    private var startupError: Error?

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    var baseURL: URL {
        guard let port = listener.port,
              let url = URL(string: "http://127.0.0.1:\(port.rawValue)/") else {
            preconditionFailure("Loopback auth server URL requested before the listener was ready")
        }
        return url
    }

    func start() throws {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                startupError = error
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.receiveRequest(on: connection, accumulated: Data())
        }
        listener.start(queue: queue)

        guard ready.wait(timeout: .now() + 3) == .success else {
            throw LoopbackAuthServerError.startTimedOut
        }
        if let startupError { throw startupError }
    }

    func stop() {
        listener.cancel()
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.start(queue: queue)
        receiveMore(on: connection, accumulated: accumulated)
    }

    private func receiveMore(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var request = accumulated
            if let data { request.append(data) }

            if request.range(of: Data("\r\n\r\n".utf8)) != nil || isComplete || error != nil {
                respond(to: request, on: connection)
            } else {
                receiveMore(on: connection, accumulated: request)
            }
        }
    }

    private func respond(to request: Data, on connection: NWConnection) {
        let requestLine = String(decoding: request, as: UTF8.self)
        // URLSession may use either origin-form or absolute-form request targets
        // against a loopback listener. Match the reviewed route in either form.
        let firstLine = requestLine.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let isForgotPassword = firstLine.hasPrefix("POST ") &&
            firstLine.contains("/api/auth/forgot-password")
        let status = isForgotPassword ? "200 OK" : "404 Not Found"
        let body = isForgotPassword
            ? #"{"message":"Password reset instructions sent"}"#
            : #"{"error":"Not found"}"#
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private enum LoopbackAuthServerError: Error {
    case startTimedOut
}
