# Physical iPhone validation

Local building and simulator testing are complete; iPhone installation and hardware validation remain pending.
This document retains the unverified MVP acceptance requirements rather than treating simulator checks as device evidence.

## Current platform limitation

The exact 15-minute audible cutoff cannot be guaranteed by the current AlarmKit public API when iOS suspends or terminates Bob.
Bob queues no new retry after the deadline, cancels retries on completion, and stops current alerts at the deadline when the process is executing.
An already sounding system alert may continue past the deadline when Bob cannot execute.
The interface must not claim otherwise.
This is a known gap against the original MVP, not merely a camera or simulator limitation.
Device testing may establish observed system behavior but cannot create a missing execution guarantee.
Resolving the full original requirement needs either an applicable Apple API change or an explicit product decision to accept a bounded retry schedule with system-managed alert duration.
No background audio, location, push notification, Screen Time, or paid entitlement workaround is used.

Primary references: [AlarmKit introduction](https://developer.apple.com/videos/play/wwdc2025/230/) and [Apple's background execution limits](https://developer.apple.com/forums/thread/685525).
The installed iOS 26.5 SDK AlarmKit interface offers schedule, stop, cancel, pause, and resume methods, but no alert-expiration parameter.

## Install using a free Personal Team

1. Connect the iPhone 17 to this Mac and trust the connection on both devices.
2. Record the phone's installed iOS version; Bob requires iOS 26 or later.
3. Run `xcodegen generate` from the repository root, then open `Bob.xcodeproj` in Xcode.
4. In Xcode Settings > Accounts, sign in with the Apple account used for personal development.
5. Choose the Bob target, Signing & Capabilities, and the free Personal Team.
6. If necessary, change the bundle identifier to a unique personal identifier in `project.yml`, run `xcodegen generate`, and select the team again.
7. Enable Developer Mode on the phone if Xcode requests it, then select the physical iPhone as the run destination.
8. Build and run; approve the locally installed developer app in iPhone Settings if required.
9. Verify alarm authorization can be granted and an actual alarm can be scheduled without adding entitlements.
10. Rebuild and reinstall before the free seven-day provisioning profile expires.

Do not purchase a membership or add a fabricated `com.apple.developer.alarmkit` entitlement.
Apple's documented AlarmKit setup uses `NSAlarmKitUsageDescription` and runtime authorization.
Actual free-team signing still needs to be validated with this account and phone.
See [Apple account documentation](https://developer.apple.com/help/account/basics/about-your-developer-account).

## Alarm and retry scenarios

Record phone model, OS version, installation date, authorization state, scheduled time, actual ring time, silence time, challenge activity, and final outcome for every scenario.

| Scenario | Required observation | Status |
| --- | --- | --- |
| App foreground | Main alarm sounds at selected time | Pending |
| App background and phone locked | Main alarm sounds without Bob executing in foreground | Pending |
| App force-quit | OS alarm and prequeued retries remain available | Pending |
| Focus and silent mode | Authorized system alarm behaves as documented | Pending |
| Stop button and hardware dismissal | Sound stops, challenge stays incomplete, retries remain bounded | Pending |
| Open Bob action | Correct occurrence and original plan open | Pending |
| No challenge attempt | Retry at two minutes, then remaining bounded retry schedule | Pending |
| Puzzle started | Four-minute initial thinking allowance, no renewal merely from screen visibility | Pending |
| Pushup activity | Accepted activity suppresses imminent retries | Pending |
| Completion | Active sound stops and all retries for that occurrence are removed | Pending |
| Deadline in foreground | Sound ends, challenge remains incomplete and can still be solved | Pending |
| Deadline while suspended | Record ongoing system alert behavior; known exact-cutoff gap remains | Pending |
| Next repeated morning | Independent occurrence with its own challenge progress | Pending |
| Permission revoked | Readiness failure appears on next activation | Pending |
| Device restart | Saved plan, progress and scheduled OS alarms are retained | Pending |
| Time zone or daylight-saving change | Verify primary alarm and retry alignment after reopening Bob | Pending |
| Seven-day retry queue | Verify the device accepts the full queue and provisioning remains valid | Pending |

The primary wake alarm uses an AlarmKit relative weekly schedule when repeating days are selected.
Retry schedules are fixed dates for the next seven days and are refreshed on launch.
If Bob is not opened beyond that horizon, the primary repeating alarm remains in AlarmKit but further retries have not been queued.
Free provisioning expiry is a separate and earlier operational constraint in ordinary use.

## Camera and challenge checks

- Register a real QR code, scan a different code, then scan the registered code.
- Test QR capture in low light and with a damaged or unavailable code.
- Deny camera permission and complete the preselected fallback immediately.
- Choose fallback without opening the camera, as someone with a sore wrist could do.
- Perform pushups at slow, moderate, and faster comfortable paces from multiple side-camera placements.
- Try a static plank, standing arm movements, camera shake, walking across frame, partial body visibility, and a second person entering frame.
- Record false positives and false negatives separately; no real-world accuracy claim is justified yet.
- Verify accepted seconds survive a pause, tracking loss, application restart, and a later rejected movement.
- Confirm a slow accepted movement segment is retained in full.
- Verify no frames or footage appear in Photos or the app's persisted files.

The detector is a conservative joint-angle and posture heuristic, not proof of perfect form, identity, or location.
Synthetic pose tests establish deterministic behavior only.
See [camera validation](../Bob/Camera/VALIDATION.md) for thresholds and their rationale.

## Offline planning and intent fidelity

Enable Apple Intelligence, allow the on-device model to download, then enable airplane mode.
The Foundation Models availability check should succeed only when the device is ready.
When unavailable, manual plan entry and explicit confirmation must remain usable.

| Input | Expected behavior |
| --- | --- |
| I want to exercise and work on my proposal tomorrow. | Clarify the first action only if needed; preserve both intentions |
| Draft the introduction first. | Carry the answer into an editable compact plan without marking the entire proposal complete |
| I want to walk if my wrist feels okay. | Retain the condition; do not turn it into an unconditional commitment |
| I do not want to run. | Do not propose running |
| Actually, skip the workout and read instead. | Preserve the correction and require user confirmation of the resulting plan |
| Read two pages, not twenty. | Do not invent or reverse quantities |
| I slept badly. Just breakfast. | Keep the plan modest and avoid shame or health claims |
| No input this evening | Existing plan remains dated; a missing plan does not block the alarm |

Record the full original input, clarification, suggested plan, edited plan, and confirmation for each example.
Code-level grounding tests do not prove actual model quality on the phone.
