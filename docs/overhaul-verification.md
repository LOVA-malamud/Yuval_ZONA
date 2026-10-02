# Command and coordination overhaul acceptance

Branch: `feat/command-and-coordination-overhaul`; original reference: `707a51a` on `dardal_improvements`. Runtime evidence uses Godot 4.7.2 stable on native Linux. Earlier macOS/Godot 4.6.2 reports remain historical and do not verify this overhaul.

## Completed integration checks

`tests/artifacts/overhaul_final_gate/summary.json` passes source validation, matching English/Russian localization, Python scenario/selection checks, Godot import, the original runtime/navigation/settings/localization/onboarding/polish labs, fixed-step presentation parity, definition extensions, coordination and session lifecycle regressions.

Coverage includes FIFO resource contention, invalid actor/route/payload, purchase creation failure, cancellation, pause/resume/end/teardown, per-match registry ownership, persistent orders, human spending against AI reservations, Rally bonuses/exclusions/cooldown, temporary Regroup/replacement, alert suppression, spending/damage/tower attribution and the complete playable tutorial progression.

The original three-seed historical reference completed at 761.35 seconds, 1240.67 seconds and one 1800-second timeout. That small sample establishes provenance, not a pacing conclusion. Intermediate feature captures are retained locally but are not the final tuning evidence.

## Final measurements in progress

The completed current-game baseline, seeds 42–61, has median duration **1012.66 seconds (16.88 minutes)**, zero timeouts and zero technical failures. All twenty are Ember wins. The scripted human-slot commander is not a human playtest; this strong assignment bias prevents a competitive-balance claim. The remaining seven configurations are still running. Baseline meets the pacing criteria and has zero changed tuning values, so the selection rule will retain it if the complete experiment validates successfully.

- Rendered bilingual matrix: five sizes, battle/orders/rally/tutorial/result/settings, plus simulated cutouts, touch targets, native feature input and rendered 30/60 FPS parity. Final destination: `tests/artifacts/overhaul_final_desktop`.
- Paired pacing: 20 seeds (42–61), baseline and seven factorial candidates, grouping waits 3/6 seconds, troop speed 1/1.15, tower HP 432/480. Final destination: `tests/artifacts/overhaul_final_pacing`.
- Performance: three baseline/current capacity comparisons, corrected projectile phase, same machine without concurrent Godot load. Destination: `tests/artifacts/performance_overhaul`.
- Final replay JSON/HTML and browser checks, asymmetric assignment evidence and any selected balance changes remain pending.

Do not interpret a pending measurement as a pass. This file will record final selection, timing and native/rendered outcomes once those runs finish.

## Scope and limits

The overhaul preserves the King objective, two teams/four commanders, three lanes/roles, eight upgrade tracks, shared gold/wood and procedural assets. It adds local commander coordination rather than global army control. There is no multiplayer, metaprogression, crafting, new currency, shipped extra unit/map, or new platform package.

Automated AI matches measure system pacing; they do not establish human match duration or competitive balance. Rendered phone/tablet sizes and simulated cutouts are desktop evidence. Physical mobile touch comfort, audio feel and human tactical readability remain playtesting work.
