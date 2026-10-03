# Facing abilities and minimap scouting — issues #9 and #11

Implemented on `feat/pixel-art-action-overhaul` following the preserved pixel-art work. GitHub issue states are unchanged. Verified on Linux with Godot 4.7.2, October 3, 2026.

## Behavior and interfaces

All commanders retain their last movement facing when stationary. Human movement updates facing before a same-tick ability; AI goal movement updates it too. AI chooses a seeded ability intent, turns through movement, and activates on a later simulation tick after checking target, cooldown and action state. Basic attacks can temporarily face their victims visually without changing retained movement facing. Idle sprites and committed abilities use the gameplay facing.

`MatchCommand.Action.ABILITY` now needs only `ability_id`. A legacy `direction` field is ignored. `activate_ability(ability_id)` and the human controller's `request_ability(ability_id)` no longer take direction. Activation events continue recording the actual gameplay direction.

Touch abilities activate on release inside the button. Outside release or interrupted touch cancels; re-entry before release restores eligibility. Releasing movement no longer discards another finger's queued action.

Minimap mouse/touch presses start camera scouting immediately. Dragging outside clamps to map edges. Camera bounds use viewport dimensions and zoom; oversized views center the affected axis. The held camera target remains fixed while the commander moves. Release restores smooth player following. Pause, focus loss, touch cancellation, layout changes, hiding, death and match lifecycle transitions reset scouting. One scouting pointer is independent of movement and action fingers; its events cannot select world targets. The existing minimap viewport indicator uses the actual camera position. English/Russian instructions and minimap guidance describe the new controls.

## Verification

Production SHA-256: `ec2429a58e1fe2f9ce8fa0e61eb74e4f86f6a33b14c0c756624ae133aa073688`.

| Command | Result |
| --- | --- |
| `python3 tests/verify.py --suite native` | PASS, 26 checks: source/localization/Python, import, all fast fixtures, and native input. |
| `python3 tests/verify.py --suite native --fixture facing_scouting_regression` | PASS, 6 checks; expanded native fixture includes real keyboard dash/guard/heavy with opposite cursor and real minimap scouting/release, 53 native assertions total. |
| `python3 tests/verify.py --suite render --fixture facing_scouting_regression` | PASS, 7 checks: headless control fixture, rendered 30/60 FPS gameplay parity and the same scouting fixture with the actual renderer. |

The new fixture covers same-tick and stationary facing, legacy direction overrides, AI turn-before-activation, idle visual alignment, touch/mouse ownership, three simultaneous fingers, bounds at 0.7/0.9/1.1 zoom, movement during scouting, release outside, lifecycle cancellation and oversized views. It checks map-coordinate mapping and translated guidance at 960×540, 1600×720 and 1280×800 with simulated safe areas in English and Russian. The rendered run checks the actual viewport center and saves six scouting screenshots; the 960×540 Russian and 1280×800 English captures were visually inspected.

Ignored local evidence is under `tests/artifacts/issues_9_11/`. Reproduce the commands above to obtain reports on another checkout. The verification runner stages an isolated source copy and preferences; real developer settings remain unchanged.

Physical phone touch comfort and performance remain unverified. No balance acceptance or new platform package is claimed.
