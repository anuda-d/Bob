# Bob design mockups

These are image-generated concepts for discussion, not implemented SwiftUI screens.
Created with the built-in image-generation tool on September 15, 2026.

## Direction

A sharper native iPhone interface with an illustrated Bob influenced by polished early-2010s Flash character art.
Keep Bob's identity, familiar iPhone interactions, the existing muted green palette, and current app functions.
The design-taste skill informed the visual audit and exploration; its website layout rules do not apply to this native app.
The image-generation skill guided reference handling, character preservation, and separate concept variants.

## Interface options

- [A. Open](./a-open.png): typography, spacing, and thin dividers group content without cards.
- [B. Framed](./b-framed.png): one fine outline organizes the alarm, with Bob perched on its upper edge.
- [C. Green header](./c-green-header.png): a larger sage area gives the app a stronger visual identity.

Each board compares light and dark appearances of the same home screen.
The alarm and plan are sample content from the existing screenshots.
Generated controls and text remain illustrative; they have not been tested as functional UI.
The debug readiness text carried into option A is not intended for ordinary app usage.

## Character direction and feedback

[Original pose study](./bob-pose-study.png) shows Resting, Listening, and Pleased.
The user approved the exact Resting face on the left and asked to keep it unchanged.
This original sheet is preserved without alteration.
The middle Listening pose was too similar to Resting and is superseded by [Listening revision](./bob-listening-v2.png).
The revision uses a stronger lean, a raised ear, and visibly more attentive eyes.
The revised Listening pose is a separate image so it cannot alter the accepted Resting drawing.
C. Green header is the approved interface direction.
Use a sage header in light appearance and forest green in dark appearance, with Bob and the alarm as the focus.
The plan and challenge sit in open sections below, with crisp system typography and 8-point custom controls.
Remove the greeting, its supporting sentence, and the quiet-night footer from the home screen.
Retain functional dates, permissions, error messages, and the actual morning plan.

## References and generation

The existing home screenshot is `docs/screenshots/home-light.png`.
The original mascot is `Bob/Assets.xcassets/Bob.imageset/bob.png`.
See [generation prompts](./PROMPTS.md) for the exact requests and reference roles.
The original concept images remain unchanged as references for the SwiftUI implementation.

## Implementation progress

The green header, open sections, system typography, smaller control corners, and agreed copy cuts are implemented.
The four simulator flows and the home accessibility audits pass, and all 58 logic tests pass.
Simulator and unsigned iPhone builds, privacy checks, and repository checks pass.
One large-text setup tap timed out during an overlapping build.
It did not recur in an isolated rerun or two subsequent sequential full-suite runs; navigation logic was not changed.
Secondary text was measured at 3.37:1 against the new light background and strengthened to a dedicated token above 6:1.
The challenge icon column scales with Dynamic Type to keep enlarged symbols clear of the text.
The image-generation extraction attempt redrew Resting slightly and returned false transparency for two poses, so those outputs were rejected.
The user approved deterministic cutouts of the original drawings to preserve Resting's exact face.
All three transparent poses are now installed; the old-mascot fallback is removed.
Resting appears on home and welcome, Listening during preparation and active mornings, and Pleased after confirmation or challenge completion.

## Production assets

- [Resting](../../../Bob/Assets.xcassets/BobResting.imageset/bob.png)
- [Listening](../../../Bob/Assets.xcassets/BobListening.imageset/bob.png)
- [Pleased](../../../Bob/Assets.xcassets/BobPleased.imageset/bob.png)

These are direct crops from the original pose study and revised Listening drawing, not regenerated images.
The extraction removes the neutral background, ground shadow, caption, and one-pixel matte fringe.
The face and body colors are copied without resampling or repainting.
The original references and original 3D mascot asset remain unchanged.
No new generation prompt was used for the final assets.

Run `python3 scripts/prepare-bob-art.py --check` from the repository root to verify all pixels against the deterministic extraction.
The development-only utility requires Pillow 12.3 or later.
Use `--write` to rebuild the PNGs from their preserved sources.
The normal simulator and device build checks also require all three poses in the compiled asset catalog with transparency.
