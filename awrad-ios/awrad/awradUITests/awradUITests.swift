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
    func testLibraryDetailCustomDhikrAndEditRoutes() throws {
        let app = launchSeededApp()
        openDeepLink("awrad://library")

        XCTAssertTrue(app.buttons["Create Dhikr"].waitForExistence(timeout: 4))
        app.buttons["Create Dhikr"].tap()
        XCTAssertTrue(app.navigationBars["Create Dhikr"].waitForExistence(timeout: 4))

        let arabic = app.descendants(matching: .any)["dhikr-input-Arabic text"].firstMatch
        XCTAssertTrue(arabic.waitForExistence(timeout: 3))
        arabic.tap()
        arabic.typeText("Subhanallah")

        let title = app.descendants(matching: .any)["dhikr-input-Title"].firstMatch
        title.tap()
        title.typeText("Parity custom dhikr")

        let toolbarSave = app.navigationBars["Create Dhikr"].buttons["Create Dhikr"]
        XCTAssertTrue(toolbarSave.waitForExistence(timeout: 3))
        XCTAssertTrue(toolbarSave.isEnabled)
        toolbarSave.tap()

        XCTAssertTrue(app.navigationBars["Parity custom dhikr"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Parity custom dhikr"].exists)
        XCTAssertTrue(app.buttons["Dhikr actions"].exists)

        app.buttons["Dhikr actions"].tap()
        XCTAssertTrue(app.buttons["Edit Dhikr"].waitForExistence(timeout: 2))
        app.buttons["Edit Dhikr"].tap()

        XCTAssertTrue(app.navigationBars["Edit Dhikr"].waitForExistence(timeout: 4))
        XCTAssertEqual(
            app.descendants(matching: .any)["dhikr-input-Title"].firstMatch.value as? String,
            "Parity custom dhikr"
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["dhikr-input-Arabic text"].firstMatch.value as? String,
            "Subhanallah"
        )
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

        let wirdsSegment = app.segmentedControls.buttons["Wirds"]
        XCTAssertTrue(wirdsSegment.waitForExistence(timeout: 4))
        wirdsSegment.tap()

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

        XCTAssertTrue(app.buttons["Reading mode"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["Previous section"].exists || app.buttons["Next section"].exists,
            "The canonical eight-part reader must expose adjacent-part navigation"
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
        XCTAssertEqual(app.textFields["Verification token"].value as? String, "ui-verification-token")

        openDeepLink("awrad://counting?dhikr=removed-from-library")
        XCTAssertTrue(app.staticTexts["Dhikr not found"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["The requested dhikr is not available in this library."].exists)

        openDeepLink("awrad://library")
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.tabBars.firstMatch.exists)
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
