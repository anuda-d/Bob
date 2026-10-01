# Working on Bob

Bob is an early native iPhone prototype.
Read the [README](README.md), [product specification](MVP_SPEC.md), and [device validation limits](docs/DEVICE_VALIDATION.md) before changing product behavior.
Licensing remains undecided; discuss external contributions with the maintainer before submitting code or artwork.

## Set up

Use the toolchain and commands in the [README](README.md#build-locally).
The verification scripts need Node.js 22 or later; `.nvmrc` selects Node 24 for CI and version managers.
They use only Node's standard library, so no npm install is needed.

`project.yml` is the source of truth for Xcode targets, capabilities, bundle identifiers, and generated Info.plist content.
Run `xcodegen generate` after changing it.
`Bob.xcodeproj` and `Bob/Info.plist` are generated locally and excluded from Git.
Personal signing selections in Xcode are local and may be reset by regeneration.
Do not commit certificates, provisioning profiles, team credentials, build output, or personal app data.

## Make changes

Keep alarm state and persistence rules in `Sources/BobCore` and camera geometry in `Bob/Camera/Domain`.
Keep framework adapters and SwiftUI views separate from these deterministic rules.
The app has no external runtime dependencies.
Adding a service, collecting data, or changing the alarm contract requires an explicit product decision.

For logic changes, reproduce the behavior through a public interface with a failing test before implementing the fix.
For product bugs, also reproduce the closest available end-to-end flow.
Do not weaken checks, add automatic test retries, or substitute synthetic evidence for physical-device behavior.
For UI changes, inspect light and dark appearance, large Dynamic Type, VoiceOver labels, and recovery states.

Use the existing formatting in Swift files and the repository's `.editorconfig` for new files.
Write each complete sentence on its own line in longer Markdown documents.
Keep pull requests focused on the final behavior and include the checks actually run.

## Verify

```sh
swift test
node scripts/verify.mjs build
node scripts/verify.mjs privacy
node scripts/verify.mjs device-build
node scripts/verify.mjs ui
```

For illustrated mascot fidelity, install Pillow 12.3 or later in a development Python environment, then run:

```sh
python3 scripts/prepare-bob-art.py --check
```

This checks the bundled cutouts against the approved drawings without modifying them.
The standard build commands also verify that all three transparent poses are present in the compiled app.

For repository hygiene, documentation links, workflow syntax, and secret scanning:

```sh
brew install actionlint gitleaks
actionlint
node scripts/verify-repository.mjs
git diff --check
git diff --cached --check
```

The repository check scans tracked and non-ignored untracked files, checks local Markdown links, and runs Gitleaks against a temporary copy of that candidate file set.
It also verifies that a synthetic token is detected before trusting a clean scan.
CI separately scans Git history, runs the same build and test commands, and retains diagnostic artifacts for seven days.
UI checks use a fresh iPhone 17 simulator running iOS 26.5.
Its macOS 26 runner and explicit Xcode 26.6 selection match the [published runner toolchain](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md).
GitHub-hosted execution still needs to be observed after the first push.

## Report problems

For ordinary bugs, include the iOS version, device or simulator, challenge type, permission state, reproduction steps, expected result, and actual result.
For alarms, state whether Bob was foregrounded, backgrounded, force-quit, or running with the screen locked.
Remove personal plans, conversations, QR contents, and device identifiers from screenshots and logs before sharing.
Report vulnerabilities privately to the repository owner rather than including sensitive details in a public issue.
