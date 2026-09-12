import XCTest

@MainActor
final class BobFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLargeTextSetupRequiresQRRegistration() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--large-text"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["welcome.start"].isHittable)
        capture(app, "welcome-large-text")
        app.buttons["welcome.start"].tap()
        let settingsAppeared = app.buttons["alarm.save"].waitForExistence(timeout: 10)
        if !settingsAppeared { capture(app, "settings-did-not-open") }
        XCTAssertTrue(settingsAppeared)
        XCTAssertTrue(app.buttons["alarm.save"].isHittable)
        XCTAssertGreaterThan(app.staticTexts["Minute"].frame.minY, app.staticTexts["Hour"].frame.maxY,
                             "Accessibility text must reach the presented settings screen and stack its pickers.")
        capture(app, "alarm-large-text")
        let picker = app.buttons["alarm.challenge"]
        bringIntoView(picker, in: app)
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        app.buttons["QR code"].tap()
        capture(app, "qr-registration-required-large-text")
        XCTAssertFalse(app.buttons["alarm.save"].isEnabled)
        picker.tap()
        app.buttons["Puzzle"].tap()
        XCTAssertTrue(app.buttons["alarm.save"].isEnabled)
        app.buttons["alarm.save"].tap()
        XCTAssertTrue(app.buttons["plan.manual"].waitForExistence(timeout: 5))
        bringIntoView(app.buttons["plan.manual"], in: app)
        app.buttons["plan.manual"].tap()
        let steps = app.descendants(matching: .any).matching(identifier: "plan.steps").firstMatch
        bringIntoView(steps, in: app)
        steps.tap()
        steps.typeText("Open my notebook")
        if app.buttons["Done typing"].exists { app.buttons["Done typing"].tap() }
        XCTAssertTrue(app.buttons["plan.confirm"].isHittable)
        capture(app, "plan-editor-large-text")
        app.buttons["plan.confirm"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Open my notebook")).firstMatch.waitForExistence(timeout: 5))
    }

    func testNativeAlarmKitCanScheduleAndRemoveAnAlarm() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--real-alarms"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        app.buttons["welcome.start"].tap()
        app.buttons["alarm.repeat"].tap()
        for day in 1...7 {
            let weekday = app.switches["alarm.weekday.\(day)"]
            weekday.switches.firstMatch.tap()
            XCTAssertEqual(weekday.value as? String, "1", "Selected weekday \(day) must stay enabled")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Every day"].waitForExistence(timeout: 5))
        app.buttons["alarm.save"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if system.alerts.firstMatch.waitForExistence(timeout: 5) {
            let allow = system.alerts.buttons.matching(NSPredicate(format: "label CONTAINS 'Allow' AND NOT label CONTAINS 'Don'")).firstMatch
            XCTAssertTrue(allow.exists)
            allow.tap()
        }
        XCTAssertTrue(app.buttons["plan.manual"].waitForExistence(timeout: 15))
        app.buttons["Close"].tap()
        let ready = app.descendants(matching: .any).matching(identifier: "alarm.readiness").firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 10))
        XCTAssertTrue(ready.label.contains("Alarm ready"), ready.label)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Every day'")).firstMatch.exists)
        capture(app, "native-alarm-ready")
        app.buttons["home.settings"].tap()
        app.switches["alarm.enabled"].tap()
        app.buttons["alarm.save"].tap()
        XCTAssertTrue(app.staticTexts["Alarm is off"].waitForExistence(timeout: 10))
    }

    func testPushupFallbackCanBeCompletedWithoutOpeningCamera() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--dark-mode"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        capture(app, "welcome-dark")
        app.buttons["welcome.start"].tap()
        let picker = app.buttons["alarm.challenge"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Pushups"].tap()
        app.buttons["alarm.save"].tap()
        XCTAssertTrue(app.buttons["plan.manual"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        app.buttons["home.rehearsal"].tap()
        XCTAssertTrue(app.buttons["morning.silence"].waitForExistence(timeout: 5))
        app.buttons["morning.silence"].tap()
        XCTAssertFalse(app.staticTexts["morning.completed"].exists)
        capture(app, "pushup-morning-dark")
        app.buttons["morning.fallback"].tap()
        let answer = app.textFields["morning.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        answer.typeText("13")
        let doneTyping = app.buttons["Done typing"]
        XCTAssertTrue(doneTyping.waitForExistence(timeout: 5))
        doneTyping.tap()
        bringIntoView(app.buttons["morning.submit"], in: app)
        XCTAssertLessThan(app.buttons["morning.submit"].frame.maxY,
                          app.buttons["morning.silence"].frame.minY,
                          "The check-answer button must be visible above the pinned silence control.")
        app.buttons["morning.submit"].tap()
        XCTAssertTrue(app.staticTexts["morning.completed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["morning.completionMethod"].label.lowercased().contains("fallback"))
        capture(app, "fallback-completed-dark")
    }

    private func bringIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            let frame = element.frame
            let top = app.frame.height * 0.22
            var bottom = app.frame.height - 50
            for id in ["alarm.save", "plan.confirm", "morning.silence"] {
                let pinned = app.buttons[id]
                if pinned.exists && !pinned.frame.isEmpty { bottom = min(bottom, pinned.frame.minY - 12) }
            }
            if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            // Scroll in the left content gutter, away from wheels, scrollbars and pinned actions.
            let above = !frame.isEmpty && frame.minY < top
            let startY = above ? 0.38 : 0.64
            let endY = above ? 0.64 : 0.38
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: startY))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: endY)))
        }
        capture(app, "scroll-failure")
        XCTFail("Could not bring \(element.identifier) into the visible content area: \(element.frame). \(app.debugDescription)")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testManualPlanSurvivesRelaunchAndPuzzleCompletionKeepsPlan() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        capture(app, "welcome-light")
        app.buttons["welcome.start"].tap()
        let save = app.buttons["alarm.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        capture(app, "alarm-settings-light")
        save.tap()
        XCTAssertTrue(app.buttons["plan.manual"].waitForExistence(timeout: 5))
        app.buttons["plan.manual"].tap()
        let steps = app.descendants(matching: .any).matching(identifier: "plan.steps").firstMatch
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        steps.tap()
        steps.typeText("Draft the proposal introduction")
        if app.buttons["Done typing"].exists { app.buttons["Done typing"].tap() }
        app.buttons["plan.confirm"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Draft the proposal introduction")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "plan-confirmed-light")
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Draft the proposal introduction")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "home-light")
        app.buttons["home.rehearsal"].tap()
        app.buttons["morning.start"].tap()
        let answer = app.textFields["morning.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        capture(app, "puzzle-light")
        answer.tap()
        answer.typeText("999")
        app.buttons["morning.submit"].tap()
        XCTAssertFalse(app.staticTexts["morning.completed"].exists)
        answer.tap()
        answer.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "13")
        app.buttons["morning.submit"].tap()
        XCTAssertTrue(app.staticTexts["morning.completed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Draft the proposal introduction")).firstMatch.exists)
        capture(app, "morning-completed-light")
    }
}
