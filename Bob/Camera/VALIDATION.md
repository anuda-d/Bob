# Camera behavior and validation

Completed locally on 2026-09-12 with Swift 6.3.3 and the installed iOS 26.5 simulator SDK, targeting iOS 26.0.
The agreed public verification seam is `PoseSample` and `PushupDetector`, imported through `BobMotion` by tests.
The iOS app compiles domain files directly, so neither adapter imports `BobMotion`.

## Integration API

`@MainActor @Observable CameraController` exposes `Mode.pushups`, `Mode.qr`, `session`, `feedback`, `permissionDenied`, `start() async`, and `stop()`.
Initialize it with `init(mode:onActivity:onCode:)`.
Both callbacks run on the main queue in delivery order.
`onActivity` supplies newly accepted seconds, never a repetition count or camera-open duration.
The caller must persist each delta in the current occurrence and enforce its 20-second target.
`onCode` supplies a decoded string for the caller to register or compare against the registered value.
It does not imply that the QR challenge succeeded.
`CameraPreview(session:)` renders the capture session.
The SwiftUI views manage Settings links, scene lifecycle, progress display, and fallback selection.

`PoseSample` contains a timestamp and shoulder, elbow, wrist, hip and ankle points from one side of one body.
Each point includes confidence.
Coordinates use image-height units: normalized Vision y and normalized Vision x multiplied by the rotated image width/height ratio.
`PushupDetector.consume(_:)` returns `creditedDuration` and `feedback`.
`acceptedDuration` is the monotonically accumulated accepted total for that detector instance.
`pause()` discards an unfinished segment and permits a new capture timestamp epoch without reducing accepted time.

## Detection contract

The prototype requires all five landmarks to have confidence at least 0.6, a shoulder-to-ankle span at least 0.25 image heights, body alignment at least 155 degrees, and body inclination at most 35 degrees from horizontal.
Each elbow phase runs from an extended angle of at least 150 degrees toward a flexed angle of at most 110 degrees, or in the reverse direction.
The detector credits moving intervals only after that phase is established.
It can therefore credit an ascent or descent independently and may show progress in short increments.
Stationary intervals are excluded even when a later movement qualifies.
Sub-degree motion is buffered through a two-degree jitter band so sampling rate does not dictate earned duration.
An eight-degree reversal, excessive angular speed, abrupt body displacement/scale change, a long hold, unclear tracking or a gap breaks pending continuity.
Small reversals do not subtract accepted duration.
Duplicate, reversed and nonfinite timestamps cannot add time.
These thresholds favor conservative acceptance and are not calibrated exercise standards.

## Repeatable checks

From the repository root:

```sh
swift test --filter BobMotionTests
node scripts/verify.mjs build
node scripts/verify.mjs privacy
```

The initial validation on 2026-09-12 passed 13 detector tests with Swift 6.3.3.
Coverage includes qualifying movement, static holds, invalid timestamps, low confidence, invalid posture, sudden elbow jumps, jitter, explicit pauses, body displacement, timestamp replay, interrupted movement, varying sampling rates, and tiny bodies.
Whole-app compilation checks the native camera adapter with Swift 6 strict concurrency.
The privacy source check rejects footage-writing and networking APIs.

The capture implementation handles permission recovery, cancellation, stale callbacks, session rollback, interruptions, rotation, aspect ratio, mirroring, and frame lifetime.
Queue confinement is documented alongside the delegate's `@unchecked Sendable` conformance.
The [Apple rotation coordinator API](https://developer.apple.com/documentation/AVFoundation/AVCaptureDevice/RotationCoordinator) supplies physical capture and preview rotation separately.
Only transient frames, landmarks, a pending motion segment, and a temporarily deduplicated QR string are retained.

## Physical validation still required

Synthetic geometry and compiler checks do not establish real exercise reliability.
Physical validation must cover different body proportions, movement speeds, clothing, lighting, occlusion, phone distances, camera tilt, portrait and both landscape placements, and stationary false positives.
It must also exercise initial denial, granting access in Settings, permission revocation, repeated start/stop, background/foreground, camera contention, media-service interruption and actual rear-camera QR acquisition.
The detector does not establish identity, perfect form, location or an unspoofable challenge.
Real recordings are neither needed by this implementation nor saved by it.
Record hardware observations using the [device checklist](../../docs/DEVICE_VALIDATION.md) before claiming practical camera reliability.
