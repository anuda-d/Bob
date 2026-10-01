# Local implementation review

The planning flow was simplified after this initial review.
The current app saves the user's exact text for the next alarm through one editor and no longer includes the AI planner or its tests.
The planner discussion below records the earlier prototype only.
The revised flow passed 37 Swift logic tests, six simulator UI tests, privacy verification, and unsigned simulator and iPhone builds on 2026-09-30.

The agreed local deliverable is a buildable native iPhone app with all simulator-testable flows exercised.
The user's iPhone installation and hardware testing are a later pass.
The original MVP is not declared complete by local test results.

## Four implementation passes

1. Implemented the occurrence and persistence domain, native framework adapters, and connected SwiftUI surfaces.
2. Reviewed intent preservation, conservative movement verification, occurrence independence, and background scheduling constraints.
3. Corrected duplicate retry identifiers after confirmation, retry identity drift as time passes, unintended daily rescheduling of a one-time alarm, slow movement credit rejection, and future retry duplication after a time-zone change.
4. Reviewed native screenshots, accessibility labels, pinned primary controls, camera visibility and interruption handling, and truthful readiness and recovery copy.

Logic tests use the public boundaries approved by the user.
The detector and planner have separate focused suites and native Swift 6 strict-concurrency checks.
Integrated XCTest flows exercise saved plans across relaunch, incorrect and correct puzzle answers, camera-free fallback, missing QR registration, accessibility text, and actual AlarmKit scheduling and removal.
The native service flow enables all seven weekdays, exercising the configured seven-day retry queue.
It does not establish physical alarm delivery or sound behavior.

## Design review

This is a native app using SwiftUI and Apple controls, so website-specific layout and dependency prescriptions from the design skill are outside scope.
The chosen direction uses rounded system type, native SF Symbols, one adaptive green accent, and consistent 20-point panels and 14-point controls.
Motion is limited to touch feedback and respects Reduce Motion.
Primary button contrast was independently calculated from the implemented sRGB values: 6.90:1 in light appearance and 8.17:1 in dark appearance.
The screen review includes light and dark appearances, confirmation and recovery states, and accessibility text with vertically stacked time pickers.
A test-fixture issue that failed to propagate large text into sheets was reproduced and corrected before acceptance.
Explicit content hit regions make the long forms scroll from their empty margins.
The native repeat test checks the actual switch controls, every selected weekday, and the persisted Every day label before accepting queue readiness.
Screenshots are retained under `docs/screenshots/`.

The final builds explicitly target iPhone at the app-target level, overriding XcodeGen's universal-app default.
The verifier checks the built bundle's device-family value and rejects compiler or validation warnings.

Repository preparation also checked the staged source from a clean export.
Sheet presentation is attached to the stable root view so the presenter survives welcome and home transitions.
UI automation waits for the settings sheet to appear before asserting reachability.
The fallback flow dismisses the keyboard and verifies that Check answer is above the pinned Silence alarm control before tapping it.
These explicit UI steps address missed taps without retrying failed tests or changing challenge rules.
The UI verifier boots its selected simulator and waits for boot completion before launching the tests.
The privacy source walk excludes generated build caches so its coverage is consistent between developer checkouts and CI.

## Boundaries retained

Camera tests use synthetic poses and cannot establish real-world detection accuracy.
Planning validation preserves source wording but uses a deliberately small extractive grammar; unsupported wording remains available for manual editing.
Actual on-device model responses have not been verified.
An exact 15-minute cutoff of an already sounding system alarm while Bob is suspended remains a known API gap.
All device scenarios, installation steps, and that requirement gap are retained in [DEVICE_VALIDATION.md](DEVICE_VALIDATION.md).
