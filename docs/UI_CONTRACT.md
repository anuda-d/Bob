# Native UI contract

Use `import BobCore` and SwiftUI.
The app driver implements `@MainActor @Observable final class AppModel` in the same app module.
Do not define a replacement AppModel.

## AppModel observable properties

```swift
var settings: AlarmSettings
var plan: MorningPlan?
var todayPlan: MorningPlan?
var planText: String
var occurrence: MorningOccurrence?
var setupComplete: Bool
var morningPresented: Bool
var alarmReady: Bool
var alarmStatus: String
var errorMessage: String?
var isBusy: Bool
```

Settings, plan, plan text, occurrence, and setup completion are read-only computed properties.
The plan property shows the next planned alarm or today's plan after the alarm rings.
The todayPlan property keeps a fired alarm's goals visible when the user has also saved goals for the next alarm.
The plan text property contains the editable words for the next future alarm.

## AppModel actions

```swift
func saveAlarm(_ value: AlarmSettings) async -> Bool
func requestAlarmPermission() async
func savePlan(_ text: String) async -> Bool
func refresh() async
func beginChallenge() async
func silence() async
func submitAnswer(_ answer: String) async -> Bool
func scanCode(_ code: String) async
func acceptActivity(_ seconds: TimeInterval) async
func useFallback() async
func dismissMorning()
func deleteAlarm() async
#if DEBUG
func startPreviewMorning() async
#endif
```

## Domain properties

AlarmSettings exposes `hour`, `minute`, `weekdays: Set<Int>` (Sunday=1), `enabled`, and `challenge`.
ChallengeConfiguration exposes `kind: ChallengeKind` (.pushups/.puzzle/.qr), `difficulty: PuzzleDifficulty` (.easy/.hard), `qrCode: String?`, and `fallback: PuzzleDifficulty?`.
MorningPlan exposes the saved goals in `originalIntent` and retains older fields for stored-data compatibility.
MorningOccurrence exposes `id`, `settings`, `plan`, `scheduledAt`, `verifiedSeconds`, `isComplete`, `completionMethod`, `usingFallback`, `effectiveChallenge`, `audibleDeadline`, and `puzzle: PuzzleProgress`.
PuzzleProgress exposes `currentProblem: MathProblem?`, `solvedCount: Int`, `problems: [MathProblem]`, and `isComplete: Bool`.
MathProblem exposes `prompt: String` (do not expose the answer in production UI).
CompletionMethod is a raw-string enum: pushups, puzzle, qr, fallbackEasy, fallbackHard.

## Camera interface

`@MainActor @Observable final class CameraController` has `enum Mode { case pushups, qr }`.
Initialize it with `init(mode: Mode, onActivity: @escaping (TimeInterval) -> Void, onCode: @escaping (String) -> Void)`.
It exposes `session: AVCaptureSession`, `feedback: String`, `permissionDenied: Bool`, `start() async`, and `stop()`.
`CameraPreview(session:)` is a UIViewRepresentable.
Call start when the capture surface is visible, stop on disappearance or background, and restart on foreground.
Only successful verification advances the challenge.

## Visual contract

Root entry point is `RootView(model: AppModel)`.
Create cohesive native screens: brief welcome, alarm settings with relevant challenge configuration, home with next alarm/readiness and saved goals, one-screen text planning, morning challenge and completed state.
Alarm setup uses a native locale-aware time picker, inline weekday buttons with repeat presets, and visible challenge choices.
Saving an alarm returns home; preparing a plan is a separate action.
Plan my morning opens directly to a multiline goals editor, with no preview or intermediate choices.
Done saves the exact entered text and returns directly to Home.
Opening planning again before the next alarm shows the saved text for editing.
Saving a plan never changes the alarm time and applies only to the next occurrence.
Use adaptive off-white/forest-charcoal surfaces, a muted green accent, standard system typography, and 8-point custom controls.
Home and welcome use a sage/forest header; home places the alarm beside Bob and stacks them at larger Dynamic Type sizes.
Group content with space and section rules, not rounded cards.
System controls and SF Symbols retain their native geometry and behavior.
No external dependencies, no hand-drawn icons, no website layouts.
BobPortrait uses held illustrated poses: Resting for home/welcome, Listening during preparation and active mornings, and Pleased after challenge completion.
Keep the approved Resting face and original concept sheet unchanged.
No idle loops, character morphing, or game-style interface elements.
Use lightweight button scale/opacity feedback only; respect reduced motion and Dynamic Type.
Remove decorative captions; retain functional instructions, dated plans, permission states, and recovery messages.
Make fallback immediately reachable without proof of camera failure.
Camera permission denied is recoverable using the fallback.
Alarm permission denied is a visible readiness failure.
Keep planning available offline.
Show the exact goals when the alarm rings and for the rest of that day after challenge completion.
Never mark broad plan steps completed by a challenge.
Do not show a previous day's plan as if it belongs to a later repeating alarm.
Include a small Debug-only “Try a morning” rehearsal control at the bottom right of Home for local user testing.

## UI testing identifiers

Use stable identifiers at the controls: `welcome.start`, `alarm.save`, `alarm.time`, `alarm.repeat`, `alarm.weekday.<1...7>`, `alarm.challenge.<puzzle|pushups|qr>`, `alarm.difficulty`, `alarm.fallback`, `home.prepare`, `home.settings`, `home.rehearsal`, `plan.input`, `plan.done`, `morning.silence`, `morning.start`, `morning.answer`, `morning.submit`, `morning.fallback`, `morning.done`, `morning.completed`.
Tests launch with `--uitesting` to isolate storage and avoid OS alarm requests.
The dedicated native service test also supplies `--real-alarms` to exercise actual AlarmKit scheduling and removes its alarms afterward.
`--dark-mode` and `--large-text` set deterministic appearance on each presented test surface.
Do not display testing internals in ordinary app usage.
