import XCTest

@MainActor
final class BobFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testAlarmSetupKeepsTimeDaysAndChallengeTogether() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        app.buttons["welcome.start"].tap()
        XCTAssertTrue(app.datePickers["alarm.time"].exists, "Use the native, locale-aware time picker.")
        let wheels = app.datePickers["alarm.time"].pickerWheels
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "6")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "30")
        let monday = app.buttons["alarm.weekday.2"]
        XCTAssertTrue(monday.isHittable, "Repeating days should be directly reachable on the alarm screen.")
        monday.tap()
        XCTAssertTrue(monday.isSelected)
        XCTAssertTrue(app.buttons["alarm.challenge.puzzle"].isHittable)
        capture(app, "alarm-setup-before-save")
        app.buttons["alarm.save"].tap()
        XCTAssertTrue(app.staticTexts["home.wakeTime"].waitForExistence(timeout: 5),
                      "Saving an alarm should show the saved alarm, not start another task.")
        XCTAssertFalse(app.buttons["plan.confirm"].exists)
        let savedTime = app.staticTexts["home.wakeTime"].value as? String ?? ""
        XCTAssertTrue(savedTime.contains("6:30") && savedTime.contains("AM"), savedTime)
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["alarm.weekday.2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["alarm.weekday.2"].isSelected)
    }

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
        XCTAssertTrue(app.datePickers["alarm.time"].exists)
        XCTAssertLessThanOrEqual(app.datePickers["alarm.time"].frame.width, app.frame.width)
        capture(app, "alarm-large-text")
        let picker = app.buttons["alarm.challenge.qr"]
        bringIntoView(picker, in: app)
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        capture(app, "qr-registration-required-large-text")
        XCTAssertFalse(app.buttons["alarm.save"].isEnabled)
        let puzzle = app.buttons["alarm.challenge.puzzle"]
        bringIntoView(puzzle, in: app)
        puzzle.tap()
        XCTAssertTrue(app.buttons["alarm.save"].isEnabled)
        app.buttons["alarm.save"].tap()
        XCTAssertTrue(app.buttons["home.prepare"].waitForExistence(timeout: 5))
        bringIntoView(app.buttons["home.prepare"], in: app)
        app.buttons["home.prepare"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "plan.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        bringIntoView(input, in: app)
        input.tap()
        input.typeText("Open my notebook")
        if app.buttons["Done typing"].exists { app.buttons["Done typing"].tap() }
        XCTAssertTrue(app.buttons["plan.done"].isHittable)
        XCTAssertTrue(app.buttons["plan.done"].isEnabled)
        capture(app, "plan-editor-large-text")
        app.buttons["plan.done"].tap()
        XCTAssertTrue(app.staticTexts["home.wakeTime"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Open my notebook")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "home-large-text")
        bringIntoView(app.buttons["home.prepare"], in: app)
        XCTAssertTrue(app.buttons["home.prepare"].isHittable)
    }

    func testNativeAlarmKitCanScheduleAndRemoveAnAlarm() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--real-alarms"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        app.buttons["welcome.start"].tap()
        app.buttons["alarm.repeat"].tap()
        app.buttons["Every day"].tap()
        for day in 1...7 { XCTAssertTrue(app.buttons["alarm.weekday.\(day)"].isSelected) }
        app.buttons["alarm.save"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if system.alerts.firstMatch.waitForExistence(timeout: 5) {
            let allow = system.alerts.buttons.matching(NSPredicate(format: "label CONTAINS 'Allow' AND NOT label CONTAINS 'Don'")).firstMatch
            XCTAssertTrue(allow.exists)
            allow.tap()
        }
        XCTAssertTrue(app.staticTexts["Next wake-up"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Every day'")).firstMatch.exists)
        capture(app, "native-alarm-ready")
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.switches["alarm.enabled"].waitForExistence(timeout: 10))
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
        let picker = app.buttons["alarm.challenge.pushups"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        capture(app, "alarm-settings-dark")
        picker.tap()
        app.buttons["alarm.save"].tap()
        XCTAssertTrue(app.staticTexts["home.wakeTime"].waitForExistence(timeout: 5))
        capture(app, "home-empty-dark")
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

    func testPushupChallengeStartsCameraWhenVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        app.buttons["welcome.start"].tap()
        XCTAssertTrue(app.buttons["alarm.challenge.pushups"].waitForExistence(timeout: 10))
        app.buttons["alarm.challenge.pushups"].tap()
        app.buttons["alarm.save"].tap()
        XCTAssertTrue(app.buttons["home.rehearsal"].waitForExistence(timeout: 5))
        app.buttons["home.rehearsal"].tap()
        let start = app.buttons["morning.start"]
        bringIntoView(start, in: app)
        start.tap()
        let cameraStarted = NSPredicate { _, _ in
            let feedback = app.staticTexts["camera.feedback"]
            return app.buttons["camera.settings"].exists
                || (feedback.exists && !feedback.label.isEmpty
                    && !feedback.label.contains("Starting camera")
                    && !feedback.label.contains("Camera is stopped"))
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: cameraStarted, object: nil)], timeout: 10), .completed,
                       "Starting pushups must start the visible camera surface or explain why access is unavailable.")
        capture(app, "pushup-camera-started")
        XCTAssertFalse(app.staticTexts["morning.completed"].exists)
    }

    private func bringIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            let frame = element.frame
            let top = app.frame.height * 0.22
            var bottom = app.frame.height - 50
            for id in ["alarm.save", "plan.done", "morning.silence"] {
                let pinned = app.buttons[id]
                if pinned.exists && !pinned.frame.isEmpty { bottom = min(bottom, pinned.frame.minY - 12) }
            }
            if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            // Scroll in the left content gutter, away from wheels, scrollbars and pinned actions.
            let above = !frame.isEmpty && frame.minY < top
            let startY = above ? 0.38 : min(0.64, max(0.28, (bottom - 24) / app.frame.height))
            let endY = above ? 0.64 : max(0.14, startY - 0.25)
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
    func testPlanIsOneStepEditableAndSurvivesRelaunchAndChallenge() throws {
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
        XCTAssertTrue(app.buttons["home.prepare"].waitForExistence(timeout: 5))
        app.buttons["home.prepare"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "plan.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5), "Planning should open directly to the goals editor.")
        XCTAssertFalse(app.buttons["plan.manual"].exists)
        XCTAssertFalse(app.buttons["plan.send"].exists)
        XCTAssertFalse(app.buttons["plan.confirm"].exists)
        input.tap()
        input.typeText("Draft the proposal introduction")
        if app.buttons["Done typing"].exists { app.buttons["Done typing"].tap() }
        XCTAssertEqual(app.buttons["plan.done"].label, "Done")
        app.buttons["plan.done"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Draft the proposal introduction")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.prepare"].exists, "Done should return directly home.")
        capture(app, "plan-saved-light")
        app.buttons["home.prepare"].tap()
        let reopened = app.descendants(matching: .any).matching(identifier: "plan.input").firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 5))
        XCTAssertEqual(reopened.value as? String, "Draft the proposal introduction")
        app.buttons["Close"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Draft the proposal introduction")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "home-light")
        try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion, .sufficientElementDescription])
        XCTAssertTrue(app.buttons["home.prepare"].isHittable)
        XCTAssertFalse(app.staticTexts["A little less\nto carry."].exists)
        XCTAssertFalse(app.staticTexts["Bob can hold the morning plan."].exists)
        XCTAssertFalse(app.staticTexts["A short plan. Then some quiet."].exists)
        app.terminate()
        app.launchArguments = ["--uitesting", "--dark-mode"]
        app.launch()
        XCTAssertTrue(app.staticTexts["home.wakeTime"].waitForExistence(timeout: 5))
        capture(app, "home-dark")
        try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion, .sufficientElementDescription])
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["home.rehearsal"].waitForExistence(timeout: 5))
        app.buttons["home.rehearsal"].tap()
        app.buttons["morning.start"].tap()
        let answer = app.textFields["morning.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        capture(app, "puzzle-light")
        answer.tap()
        answer.typeText("999")
        bringIntoView(app.buttons["morning.submit"], in: app)
        app.buttons["morning.submit"].tap()
        XCTAssertFalse(app.staticTexts["morning.completed"].exists)
        answer.tap()
        answer.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "13")
        bringIntoView(app.buttons["morning.submit"], in: app)
        app.buttons["morning.submit"].tap()
        XCTAssertTrue(app.staticTexts["morning.completed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Draft the proposal introduction")).firstMatch.exists)
        capture(app, "morning-completed-light")
    }
}
