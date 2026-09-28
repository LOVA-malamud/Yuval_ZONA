# Pre-playtest regression and independent code review

This review builds on the preserved strategic-overhaul baseline commit `8ca89f7`. It is separate from the lead's rendered matrix, MCP diagnostics, complete matches and exported-build verification.

## Scope and code review

- Confirmed no changes to the unit/upgrade/balance resources, AI strategy, Team economy, combat-unit decisions or human controller. The controller → commander body → team boundary remains intact.
- Reviewed new settings persistence, procedural audio, contextual help, HUD invalidation, minimap markers, effect budget, combat presentation and navigation changes. Runtime code contains no dependencies on test scripts or test assets.
- Found a locale-save path isolation defect together with the lead: default locale saves bypassed `GameSettings.storage_path`. The lead corrected default path delegation while preserving explicit paths and ordinary `user://settings.cfg` behavior. The tests exercise an isolated path and compare real settings bytes before/after.
- Reported the obsolete hidden controls-hint node left behind by onboarding. The lead removed the allocation and per-frame hide call, preserving the existing localization key.
- Reviewed the lead's fixes for King-alert priority over commander loss, live translation of an active resource-gain notice, failed guidance persistence feedback, and stopping prior-match cues on restart. Added behavior regressions for each.
- Immediate test shutdown could leave audio mixer playback references alive. The smoke, localization, onboarding, route, tactical and match harnesses now stop feedback and let the mixer drain for 0.1 seconds. This changes test teardown only.
- Complete-match reports now include wall-clock duration in JSON and print the final failure count after the stall assertion. Simulation order, time step and gameplay values are unchanged.

## Additional coverage

`tests/polish_regression.gd` checks ordinary effects under a 500-event burst, effect-budget release, essential crown destruction at budget saturation and through pause, alert priority, commander respawn feedback, live resource-gain translation, settings failure feedback, isolated locale persistence, shop invalidation, offscreen presentation, incoming traces, and clean restart. Rendered runs additionally observe actual CanvasItem draw signals to verify idle caching and damage/flash invalidation. A real audio mixer capture checks a simultaneous ordinary/critical cue burst at maximum Master and SFX volume.

`tests/live_playtest.gd` now sends real viewport mouse events for recruitment, tower construction/upgrades, route popup, Settings, Master/SFX sliders, onboarding preference, Reset to Defaults and help-page navigation. Popup keyboard events target the popup's native window. Escape pause/modal/resume and movement/attack/zoom remain covered. Preferences are stored in `user://live_polish_test.cfg`, with real settings verified unchanged. `-- display` enables actual native fullscreen/windowed checks; omit it for embedded MCP play. `-- finish` stops cleanly after verification; otherwise the harness leaves a fresh normal match running for MCP inspection.

## Reproduction

Use Godot 4.6.2 Standard after an editor import. Replace `godot` with the local executable path when necessary.

```sh
python3 tests/validate_project.py
python3 tests/validate_localization.py
godot --headless --path . --script tests/runtime_smoke.gd
godot --headless --path . --script tests/localization_regression.gd
godot --headless --path . --script tests/localization_launch.gd -- write
godot --headless --path . --script tests/localization_launch.gd
godot --headless --path . --script tests/settings_audio_regression.gd
godot --headless --path . --script tests/settings_audio_regression.gd -- write
godot --headless --path . --script tests/settings_audio_regression.gd -- read
godot --headless --path . --script tests/onboarding_regression.gd
godot --headless --path . --script tests/route_travel.gd
godot --headless --path . --script tests/tactical_regression.gd
godot --headless --path . --script tests/polish_regression.gd
godot --path . --script tests/polish_regression.gd
godot --path . tests/live_playtest.tscn -- finish display
```

The corrupt-settings fixture intentionally produces ConfigFile parse diagnostics, then asserts safe fallback. These are expected negative-test diagnostics and must be distinguished from a production parse/runtime error. Headless testing does not establish visual quality, audible character, GPU performance, or exported-build correctness. Automated input is not a substitute for subjective human playtesting.

## Results

Verified on 2026-09-28 with Godot **4.6.2 stable official `71f334935`** on the development Mac. The actual rendered runs used **Compatibility / OpenGL 4.1 / AMD Radeon Pro 5300M**. Every final engine command exited with status 0. Raw logs use the `review_` prefix in ignored `tests/artifacts/` to distinguish this independent review from earlier milestone runs.

| Check | Final result | Evidence log |
| --- | --- | --- |
| Project validation | 65 Godot files, 72 resource paths, scene/node IDs, seven input actions and upgrade keys pass | Validator stdout |
| Localization validation | 170 bilingual keys, formatting placeholders and literal references pass | Validator stdout |
| Runtime smoke | 90 assertions, zero failures | `review_runtime_smoke.log` |
| Localization | 14 assertions, zero failures; all used Cyrillic glyphs present | `review_localization_regression.log` |
| Separate-process locale persistence | Write and independent read both pass | `review_locale_write.log`, `review_locale_read.log` |
| Settings/audio | 40 assertions, zero failures | `review_settings_audio_regression.log` |
| Separate-process settings persistence | One write assertion and two read assertions pass | `review_settings_write.log`, `review_settings_read.log` |
| Onboarding | 24 assertions, zero failures | `review_onboarding_regression.log` |
| Route travel | All 18 unit/lane/direction cases and the worker detour pass | `review_routes.log` |
| Tactical/crowd | 12 assertions, zero failures | `review_tactical.log` |
| Polish, headless | 23 assertions, zero failures | `review_polish_regression.log` |
| Polish, actual renderer | 26 assertions, zero failures; damage and flash-expiry redraws asserted separately | `review_polish_rendered_final.log` |
| Real input and native display | 32 assertions, zero failures | `review_live_playtest_retry.log` |
| Whitespace review | `git diff --check` passes | Command stdout |

The route times remain **41.4–59.0 seconds**, matching the strategic-overhaul baseline. The 60-unit, 30-simulated-second crowd fixture again ended with **38 survivors, 15 damaged survivors, zero severe overlap pairs, and zero terrain violations**. No combat or navigation regression was found.

The audio test generated **304,966 bytes** of cached PCM and retained exactly **12 player nodes**. One measured startup synthesized the cues in **124,599 microseconds**; this is initialization cost, not per-frame work. A real dense 12-cue mix at **100% Master / 100% SFX** peaked at **0.874965 headlessly**, **0.873844 in the initial rendered run**, and **0.825375 in the final rendered run**, below clipping. Mixer timing and controlled pitch variation can change the combined peak. These measurements establish waveform/mixer behavior, not subjective sound quality.

The live display test clicked the actual fullscreen control, observed native mode **3 (fullscreen)** at **3584×2240**, clicked it again, and observed mode **0 (windowed)** at **1280×800**. It also verified real slider changes against the audio bus gain, shared preference persistence, reset to English/defaults, guide navigation, pause/resume and restart. The real preference file was unchanged byte-for-byte after every isolation check.

The first expanded input attempt exposed three harness assumptions: the route popup can begin without a focused item; a build card needs its container reflow rendered before a second click; and the macOS fullscreen animation had not completed after 0.5 seconds. The harness now navigates until the target route is focused, allows 0.2 seconds for the changed build card, and allows one second for each native display transition. The subsequent complete run passed all 32 checks. These were fixture corrections, not changes to gameplay or display behavior. The original diagnostic attempt remains in `review_live_playtest.log` for traceability.

Individually inspected `review_live_en.png` and `review_live_ru.png`, both actual **1280×800** viewport captures. The pause menu, objective/respawn explanation and four actions fit cleanly; no clipping, broken Cyrillic or alignment problem was found. These captures supplement the lead's three-resolution visual matrix and do not claim separate 720p/1080p visual coverage from this workstream.

Final logs contain **no engine leak warnings or unexpected parse/runtime errors**. The settings/audio negative fixture produces exactly **two expected ConfigFile parse diagnostics**, one from each settings/locale loader reading the deliberately corrupt isolated file; all fallback assertions pass. Complete simulated matches, Godot MCP diagnostics and the distributable build are recorded in the lead's consolidated verification report.
