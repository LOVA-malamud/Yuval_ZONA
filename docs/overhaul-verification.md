# Command and coordination overhaul acceptance

Branch: `feat/command-and-coordination-overhaul`; original reference: `707a51a` on `dardal_improvements`. Runtime evidence uses Godot 4.7.2 stable on native Linux. Earlier macOS/Godot 4.6.2 reports remain historical and do not verify this overhaul.

## Completed integration checks

`tests/artifacts/overhaul_battle_parity_fixed/summary.json` passes source validation (90 Godot files, 99 resource paths), matching English/Russian localization (224 keys), nine Python scenario/selection checks, Godot import, the original runtime/navigation/settings/localization/onboarding/polish labs, fixed-step presentation parity, definition extensions, equal-stat difficulty behavior, coordination and session lifecycle regressions.

Coverage includes FIFO resource contention, invalid actor/route/payload, purchase creation failure, cancellation, pause/resume/end/teardown, per-match registry ownership, persistent orders, human spending against AI reservations, Rally bonuses/exclusions/cooldown, temporary Regroup/replacement, alert suppression, spending/damage/tower attribution and the complete playable tutorial progression. Targeted follow-up coverage checks terrain/freed focus targets and actions completed before their tutorial lesson.

| Render/input check | Evidence |
| --- | --- |
| Initial complete bilingual matrix | `overhaul_rendered`: all 60 exact-size captures and native input pass |
| Final rendered matrix | `overhaul_final_desktop`: 60 captures, two cutout captures and rendered 30/60 FPS trace pass |
| Corrected touch layout | `overhaul_touch_targets`: 12 bilingual phone/cutout captures, bounds and 48-pixel button/tab checks pass |
| Actual native Linux feature input | `overhaul_native_display`: 47/47 checks pass, including commands, focus, difficulty persistence/next-match application and tutorial start/restart/skip |
| Asymmetric version-1 compatibility | `overhaul_assignments`: seeds 42/43 with baseline, normal four-worker team and swapped four-worker team; JSON and browser pass |
| Actual version-3 and old replay views | Baseline-20 and assignment HTML pass Chromium playback, final stop, seek, event jumps, tooltips, responsive layout, old views and technical-failure display |

Native Hyprland resized the window to **922×1030**; the native capture records that actual size. Rendered layout captures use explicit SubViewports at **1280×720, 1280×800, 1920×1080, 1600×720 and 1280×960**, rather than treating requested native window dimensions as actual pixels.

The final desktop composite initially failed because its native fixture used the wrong class for the system-Back notification constant. Its rendering checks passed; the corrected native/touch runs above supersede that failed input check. The composite’s failed summary remains preserved rather than rewritten as a pass.

The original three-seed historical reference completed at 761.35 seconds, 1240.67 seconds and one 1800-second timeout. That small sample establishes provenance, not a pacing conclusion. Intermediate feature captures are retained locally but are not the final tuning evidence.

## Final measurements in progress

The previous baseline and partial factorial sweep are superseded. A new battle-trace regression reproduced a frame-rate-dependent Rally at tick 53: AI counted dead troops awaiting render-frame deletion. AI now counts living actors in the match registry, and the same death/projectile trace passes at both 30 and 60 FPS. Earlier pacing data is archived under `tests/artifacts/overhaul_pacing_before_registry_fix`; it must not determine final tuning.

The final experiment reruns all 160 comparisons on the corrected source: seeds 42–61, baseline and seven factorial candidates, grouping waits 3/6 seconds, troop speed 1/1.15, tower HP 432/480. Selection requires a median of 720–1080 seconds and at most two timeouts, preferring the fewest changed values, then closest to 900 seconds. If no candidate qualifies, select the closest target without increasing baseline timeouts and document the unmet target.

Three sequential headless capacity comparisons include projectile updates and all 115 actors. Registry caching and avoiding hidden command-panel refreshes reduced the observed regression; the current median p95 is 5.891 ms versus 5.031 ms, a 17.1% increase (0.860 ms). This remains a measured CPU cost. Rendered comparison p50 improved from 3.887 ms to 3.445 ms; p95 increased from 9.145 ms to 10.100 ms (+10.4%), and median per-run maximum increased from 15.132 ms to 17.735 ms (+17.2%). Reports and exact 1280×720 images are in `tests/artifacts/performance_overhaul_rendered`. Both stress comparisons exceed the investigation threshold. The fixed session performs command validation, coordination and two spatial refreshes each authoritative tick; actor-list caching and hidden-panel throttling reduce allocations, but do not remove this cost. The frame distribution also changes with the fixed clock, so improved median frame time does not establish uniformly better performance. The first rendered attempt exposed a baseline fixture dimension assertion that compared its SubViewport image to the compositor-resized root window. The fixture now compares against the requested render surface.

Final pacing selection and final-source full-match verification remain pending. Do not interpret a pending measurement as a pass.

## Scope and limits

The overhaul preserves the King objective, two teams/four commanders, three lanes/roles, eight upgrade tracks, shared gold/wood and procedural assets. It adds local commander coordination rather than global army control. There is no multiplayer, metaprogression, crafting, new currency, shipped extra unit/map, or new platform package.

Automated AI matches measure system pacing; they do not establish human match duration or competitive balance. Rendered phone/tablet sizes and simulated cutouts are desktop evidence. Physical mobile touch comfort, audio feel and human tactical readability remain playtesting work.
