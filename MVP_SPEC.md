# Bob: MVP features and flows

## Status and purpose

This document records the original MVP agreed before implementation.
Proposed defaults, unresolved behavior, and ideas outside the current MVP are labeled separately.
The local prototype is implemented; the [README](README.md) and [implementation review](docs/IMPLEMENTATION_REVIEW.md) describe current behavior and resolved implementation decisions.
Physical iPhone acceptance remains pending, and the original exact 15-minute audible cutoff remains a known platform gap.

Bob is an iPhone alarm app that connects the period before sleep with the period after waking.
The user gives Bob tasks or goals at night.
Bob clarifies what is necessary, establishes a morning plan with the user, and then goes quiet.
In the morning, Bob returns with the alarm, carries forward the user's intentions, and presents a chosen wake-up challenge.
Completing the challenge ends that alarm occurrence and its pending retries.
App blocking has been removed from the MVP.

## Product principles

- Preserve the connection between the user's evening intentions and morning experience.
- Treat the user's words as the source of truth.
- Keep Bob useful, brief, and unbloated.
- Make the experience work for different mornings without requiring an elaborate daily setup.
- Provide firm accountability without claiming that cheating is impossible.
- Preserve earned challenge progress when a later movement or detection attempt fails.
- Avoid interpreting a difficult morning as a character flaw.

Bob's tone and interaction should respect mornings made difficult by insufficient sleep.
The MVP does not promise to diagnose or solve sleep problems.

## Target device and installation

The first validation target is an iPhone 17.
The exact installed iOS version must be checked during device setup.
TestFlight and App Store distribution are outside this MVP.

The MVP must support personal installation without a paid Apple Developer membership.
Use Xcode's free Personal Team installation workflow and validate the required alarm capabilities with that signing configuration early.
Do not introduce features that require a paid membership.
Apple's free provisioning profiles expire after seven days, after which the app must be rebuilt and reinstalled on the phone.
This installation constraint remains after removing app blocking.
See [Apple's account documentation](https://developer.apple.com/help/account/basics/about-your-developer-account).

## Local processing and storage

- Run Bob's features locally without a backend or paid AI service.
- Store plans, conversations, alarm settings, and challenge progress on the phone.
- Use Apple's on-device Foundation Models model to interpret intentions and generate brief replies.
- Check model availability before starting AI-assisted preparation.
- If the model is unavailable, let the user enter and confirm a plan manually.
- Process push-up activity and QR scans on the device without saving camera footage.
- Use ordinary application code for scheduling, puzzle generation and answer checking, progress tracking, and challenge completion.
- Keep the alarm, challenges, and saved morning plan usable without internet.

Apple Intelligence must be enabled and its on-device model downloaded before AI-assisted preparation can work offline.
Bob must not silently fall back to a cloud model.
The local model's ability to preserve the user's intent must be validated with representative conversations.
See [Apple's on-device model overview](https://developer.apple.com/videos/play/wwdc2025/286/) and [Apple Intelligence requirements](https://support.apple.com/en-us/121115).

## Bob's character

Bob is a cute, nonhuman little monster.
The reference for the general feeling is Rocky from Project Hail Mary.
Bob's exact appearance has not been designed.

His personality is slightly scruffy, sleepy, gently persistent, and occasionally silly, with dry humor.
He takes the user's intentions seriously and stays brief.
His personality should also come through appearance, movement, and reactions.

Bob helps with night preparation and reappears in the morning.
He is not meant to require a continuous conversation throughout the day.

### How Bob uses the user's input

- Accept tasks, goals, or a mixture of both in the user's own words.
- Ask only the questions needed to make the intended morning plan clear.
- Summarize and organize the plan while preserving the user's intent.
- Establish concrete commitments with the user instead of silently inventing them.
- Bring the user's reason and agreed plan back in the morning.
- Guide the first action without delivering a long motivational speech.

The exact boundary of Bob's interpretation still needs examples and refinement.
His personality must not become a reason to add unnecessary questions or commentary.

## Agreed MVP features

### 1. Alarm setup

- Set a wake-up time.
- Choose repeating days.
- Select one wake-up challenge for the alarm.
- Configure a puzzle fallback during setup when choosing pushups or a QR code.

The challenge choices are 20 seconds of pushups, an easy or hard puzzle, or a registered QR code.
The user chooses one challenge per alarm.
Completing all three is not required.

### 2. Night preparation

- Give Bob a set of tasks or goals directly.
- Answer any necessary clarification questions.
- Establish a clear morning plan together.
- Carry that plan and its original intent into the morning.
- End the interaction once the plan is clear.

The core interaction is: the user provides intentions, Bob clarifies, and Bob leaves.
The experience should not require a separate elaborate journaling ritual.

Text entry and written replies are the agreed input and output methods for the MVP.
Ask one short clarification question at a time, only when needed.
Present a compact morning plan for explicit confirmation.
Keep the primary interaction digestible rather than presenting paragraphs of dialogue.
Longer details may be available through an optional expansion.
Recorded messages and conversational voice are outside the MVP.

### 3. Morning return

- Sound the alarm at the scheduled wake-up time.
- Bring Bob back with the intentions and plan established the night before.
- Present the selected wake-up challenge clearly.
- Keep the interaction short and focused on starting the morning.

The morning message should feel like an echo of what the user meant the previous night.
It must remain grounded in that user's input.
It should not become unrelated generic encouragement.

### 4. Challenge: 20 seconds of pushups

- Use the camera to detect push-up activity.
- Accumulate 20 seconds of verified push-up activity.
- Advance the timer while qualifying activity is detected.
- Pause accumulation when the user pauses or tracking becomes unclear.
- Preserve time already earned, including across app restarts.
- Show progress and useful camera-positioning feedback.
- Complete the challenge when accumulated verified activity reaches 20 seconds.

This is an activity-duration target, not a fixed repetition target.
Leaving the camera open for 20 seconds is not sufficient.
A later rejected movement or tracking failure must not erase accepted activity.

The intended approach is on-device camera processing.
The activity-detection rules and real-world reliability must be established in a prototype.
The MVP does not claim perfect exercise-form assessment or proof that the user left the bedroom.

### 5. Challenge: puzzle

- Let the user select easy or hard difficulty.
- Present the configured puzzle challenge in the morning.
- Require a correct solution before completing the challenge.
- Keep the challenge incomplete after an incorrect answer.

Math problems are the proposed first puzzle type.
The exact puzzle format, number of problems, and difficulty rules are not finalized.

### 6. Challenge: QR code

- Register a specific QR code during setup.
- Require a scan of that registered code to complete the challenge.
- Keep the challenge incomplete when a different code is scanned.

The user may place the code somewhere useful, such as outside the bedroom.
QR codes are an optional challenge, not mandatory setup for everyone.
Matching the code does not prove the user's location or completion of another task.
The user accepted QR codes as a simple MVP option despite their limitations.

### 7. Alarm silence and retries

- Allow the alarm sound to be silenced without completing the challenge.
- Keep the challenge incomplete after silencing.
- Support sounding the alarm again when the morning commitment is abandoned or not started.
- Stop further retries when the challenge is complete.

The agreed starting defaults are:

- Re-ring after two minutes of inactivity.
- Give puzzles a longer thinking allowance.
- Avoid ringing during detected challenge activity.
- Stop audible retries after 15 minutes.

These timings are provisional and must be tested on the user's phone.
For implementation, measure the 15-minute retry window from the occurrence's scheduled wake-up time.
At that limit, end the occurrence's audible alerting and cancel remaining retries, leaving an unfinished challenge incomplete.
Reaching the time limit does not count as success.
The user can still complete the challenge afterward, and the next scheduled occurrence is independent.
The precise inactivity signals and puzzle thinking allowance remain implementation decisions.
Retry behavior must distinguish an active attempt from genuine abandonment and work within iOS background-execution constraints.

### 8. Failure recovery

- Let the user select a puzzle fallback during setup for a push-up or QR challenge.
- Make that fallback available during the morning if the original challenge is unusable.
- Require solving the fallback puzzle to complete the morning challenge through recovery.
- Record which challenge was actually completed rather than claiming the original exercise or QR verification succeeded.
- Preserve accepted challenge progress across pauses, tracking failures, and app restarts.
- Offer useful camera-positioning feedback before the user needs recovery.

Recovery must cover persistent push-up detection failures, an unavailable or unreadable QR code, and unavailable camera permission.
It must also let the user use the preselected fallback if they cannot reasonably perform the exercise that morning, such as with a sore wrist or illness.
Do not require the camera to prove that a failure occurred before making the fallback available.
False detection of movement is a detector-quality issue to fix and test, rather than a reason to erase earlier accepted progress.
Alarm permission failures must be surfaced as a readiness problem; completing a fallback puzzle cannot restore that permission.

### 9. Completion

- Mark the morning challenge complete after the selected challenge or preselected puzzle fallback is completed.
- Stop the active alarm and cancel further retries for that occurrence.
- Leave the agreed morning plan available.
- Let Bob get out of the user's way.

Broader tasks and goals are the plan Bob brings back.
Completing a challenge must not automatically mark those broader goals as accomplished.

## User flows

### First-time setup

1. Meet Bob and understand the night-to-morning concept.
2. Set a wake-up time and repeating days.
3. Choose one of the three wake-up challenges.
4. Configure that challenge, including difficulty or QR registration where applicable, and a puzzle fallback for pushups or QR.
5. Complete the permissions and readiness checks needed for the selected features.
6. Give Bob the first set of tasks or goals through text entry.
7. Resolve necessary clarification questions and confirm the compact morning plan.
8. Finish setup and let Bob go quiet.

The exact screen order is a design decision.
The user should only encounter setup relevant to their chosen challenge.

### Night preparation

1. The user opens Bob and types tasks or goals.
2. Bob identifies ambiguity that matters for the morning plan.
3. Bob asks the minimum necessary questions.
4. The user confirms a compact plan and the relevant alarm settings.
5. The app retains the plan and the user's underlying intent for the morning.
6. Bob leaves the interaction.

Illustrative input: "I want to exercise and work on my proposal tomorrow."
Bob clarifies the intended morning steps without treating an exercise challenge as proof that the proposal is finished.

### Morning: successful completion

1. The scheduled alarm sounds.
2. Bob returns with the previous night's intentions and agreed plan in brief text.
3. The user begins the selected challenge.
4. The app shows challenge progress while retaining any valid progress already earned.
5. The challenge reaches its completion condition.
6. The alarm and its pending retries stop.
7. The morning plan remains available for the user to follow.

### Morning: silence without completion

1. The user silences the alarm.
2. The selected challenge remains incomplete.
3. The retry rule determines when another alarm should sound, within the occurrence's retry window.
4. The user resumes the challenge with earned progress preserved where applicable.
5. Completing the challenge follows the normal completion flow.
6. If the retry window ends before completion, audible alerting stops and the challenge remains incomplete.

The finalized retry rule must distinguish genuine abandonment from an active attempt.

### Morning: unsuccessful verification

- An unclear push-up movement does not add verified time or remove time already earned.
- An incorrect puzzle answer does not complete the challenge.
- A scan of a different QR code does not complete the challenge.

### Morning: recovery through a fallback

1. The user cannot complete the configured push-up or QR challenge.
2. The user selects the puzzle fallback agreed during setup.
3. Bob presents that puzzle without requiring camera access or the registered QR code.
4. An incorrect answer leaves the morning challenge incomplete.
5. A correct solution completes the morning challenge through the fallback.
6. The alarm and remaining retries stop, and the plan remains available.

### Night preparation: local model unavailable

1. Bob detects that the on-device model is unavailable.
2. The user can enter and confirm a plan manually.
3. The plan is saved locally for the morning.
4. The alarm and challenges remain usable without AI generation.

## Accountability boundary

Bob supports accountability through the agreed morning plan, wake-up challenge, and bounded alarm retries.
Silencing the alarm or reaching the retry limit does not mark a challenge complete.
The user retains normal access to other apps throughout the experience.
The app does not prevent the user from abandoning the challenge.
Each challenge provides different evidence.

| Challenge | What completion establishes | What it does not establish |
| --- | --- | --- |
| Pushups | The camera detected the required amount of qualifying exercise activity. | Perfect form, identity, or departure from the bedroom. |
| Puzzle | The required problem was solved correctly. | Physical movement or completion of the broader morning plan. |
| QR code | The registered code was scanned. | An unspoofable location or completion of an associated real-world task. |
| Puzzle fallback | The preselected recovery puzzle was solved correctly. | Completion of the originally selected pushups or QR scan. |

Verifying that the user left the bedroom was explored as a desirable outcome.
It is not a guarantee of the current three-choice MVP.

## Discussed ideas outside the current committed scope

These ideas remain available for later consideration and should not silently expand the first build.

- A lighter routine chosen in advance for a short night.
- A bedtime display of the time remaining until the alarm.
- Physical routes with several checkpoints.
- Walking or step-count challenges.
- Camera recognition of a familiar room, object, or location.
- A recorded personal message and a later morning reply.
- Sleep-data integration or automatic routine adaptation.
- Recorded voice input, spoken replies, or conversational voice.

App blocking and staged app unlocking were explicitly removed from scope because the user does not want a paid Apple Developer membership.
Do not reintroduce Screen Time permissions or app-selection setup as part of this MVP.

## Open decisions before implementation is complete

1. How Bob clarifies and summarizes goals, including representative examples and the boundary of his interpretation.
2. The exact layout of the compact plan, confirmation control, and optional expanded details.
3. What Bob presents when the user skips night preparation or has no new plan.
4. The puzzle format, quantity, and definitions of easy and hard, including fallback configuration.
5. The camera rules for accumulating verified push-up activity and their real-world reliability.
6. Whether any challenge switching beyond the agreed preselected puzzle fallback is supported.
7. The exact inactivity signals and longer puzzle thinking allowance, with real-device validation of the two-minute and 15-minute starting defaults.
8. Permission-readiness screens and recovery behavior if alarm authorization is missing or revoked.
9. The installed iOS version and real-device validation of alarms and retries while Bob is not in the foreground, using free Personal Team provisioning.
10. Bob's final visual design, animations, and exact dialogue.
11. Whether multiple alarms are supported, how a plan is associated with an occurrence, and how edits or deletion affect an active occurrence.

These are implementation and interaction decisions to resolve without expanding the core loop.

## Definition of done for the MVP

- The app can be installed on the user's iPhone 17 with a free Personal Team and no paid entitlement requirement.
- A user can set an alarm, repeating days, one challenge, and a preselected puzzle fallback where applicable.
- A user can type tasks or goals, resolve Bob's necessary short questions, and confirm a compact plan.
- Bob ends the night interaction once the plan is established.
- The alarm works on the user's iPhone without requiring Bob to be open in the foreground, with required permissions granted and a valid installation.
- Bob brings the user's agreed intentions and plan into the morning through digestible text.
- Each of the three challenge types can be selected and completed through its own intended flow.
- Silencing the alarm alone does not complete the challenge.
- Invalid verification attempts do not complete the challenge.
- Earned push-up activity survives pauses, subsequent tracking failures, and app restarts.
- A user can complete the preselected puzzle fallback when pushups or a QR code are unusable, with the actual completion method recorded.
- Completing the selected or fallback challenge stops that alarm occurrence's active sound and remaining retries.
- Retry timing respects active attempts, starts from the agreed two-minute inactivity default with a longer puzzle allowance, and stops audible alerting after the 15-minute window.
- Reaching the retry limit leaves an unfinished challenge incomplete.
- AI-assisted preparation works offline when the on-device model is available, and manual plan confirmation remains available when it is not.
- Alarm operation, challenge verification, and the saved morning plan work without internet.
- Camera frames are processed locally without retaining footage, and Bob does not send plans or conversations to a cloud service.
- Completing the challenge does not falsely mark the user's broader tasks or goals complete.
- The experience remains brief, understandable, and faithful to the user's own intentions.
