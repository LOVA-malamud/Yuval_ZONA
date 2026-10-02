# Gameplay rework implementation and verification

The integrated `main` implements the batch plan for GitHub issues #1–#8. These changes are ready for integrated verification and human playtests; this report does not claim the issues are closed.

## Implemented behavior

| Issue | Implementation |
| --- | --- |
| #1 Gradual base healing | Interaction starts a 60 HP/second channel inside the 180-unit base radius. Movement, damage, leaving the radius, or offensive action interrupts. A valid start consumes the 30-second cooldown; full-health interaction consumes nothing. AI persists through recovery. |
| #2 Finite wood | 28 finite trees per side, mirrored and placed clear of routes, terrain, bases, and build pads. Sixteen home trees carry 60 wood each, eight transition trees 300 each, and four forward trees 500 each: 5,360 wood per side. Workers skip inaccessible trees and retarget depleted stock. Gold deposits and passive income continue. |
| #3 AI lane distribution | One team history tracks the last 30 troop deployments, with tolerance two and seeded tie-breaking. Explicit orders and sensed base emergencies override normal balancing and are recorded in the same history. |
| #4 Commander abilities | Human and AI commanders share validated dash, guard, and heavy-strike commands, cooldowns, action state, interruption rules, and death/respawn handling. |
| #5 Movement combat | Collision-safe dash travels up to 150 units over 0.15 seconds without invulnerability, then has 0.2 seconds of recovery; five-second cooldown. |
| #6 Tactical encounters | Frontal guard, committed heavy strikes, brief stun, dash escape, seeded AI reaction delays, and reproducible duel measurements support positioning and counterplay. Human assessment of difficulty and enjoyment remains pending. |
| #7 Tower types | Guard, Splash, and Long-range definitions share construction/upgrade validation with UI and AI. Three levels, distinct silhouettes, splash friendly exclusion, and long-range minimum range are covered. |
| #8 Mobile HUD | Persistent combat essentials and minimap, collapsible purchasing drawers, contextual tower choice, independent mobile auto-attack, aimed multi-touch abilities, safe-area handling, and portrait pause/rotate notice. Physical phone acceptance remains pending. |

Commanders now have **360 HP**. Healing takes six seconds from empty. Guard lasts 0.6 seconds, reduces frontal damage by 70% within a 120-degree cone, slows movement to 35%, and prevents guarded heavy stun. Heavy strike has a 0.6-second wind-up, locked facing, 25% movement speed, 50-degree melee cone, 48 damage, seven-second cooldown, and 0.45-second recovery. A successful unguarded strike stuns commanders/troops for 0.5 seconds; 1.5 seconds of immunity follows recovery. Workers and structures take damage without stun.

| Tower | Gold / wood | HP | Damage / interval | Range | Specialization |
| --- | --- | --- | --- | --- | --- |
| Guard | 140 / 55 | 480 | 18 / 1.2 s | 245 | General defense; original upgrade progression |
| Splash | 180 / 80 | 420 | 12 / 1.6 s | 220 | 65-unit area impact |
| Long-range | 220 / 100 | 360 | 36 / 2.4 s | 380 | 100-unit minimum range |

Alternative towers upgrade for 100/65 then 200/130 gold/wood, adding 120 HP and 25% of base damage per level. Match-owned resources preserve authoring defaults. Explicit tower scenario fields override legacy Guard balance fields. Replay version 4 records new state and events while the viewer retains version 3 support.

## Measurement evidence

A fixed-60-Hz isolated economy scenario, with three starting workers per team and no enemies or upgrades, exhausted home wood in **280 seconds (4 minutes 40 seconds)**, within the 3–5-minute target. Initial 100-wood home trees lasted 480 seconds and were reduced to 60. Exposed supplies sustain later gathering; full-match pacing requires integrated match measurements.

The isolated duel lab ran the same 20 seeds per difficulty using real AI controllers, no armies or purchases, and a 360-HP candidate. Completed-fight median durations were **13.09 seconds easy**, **13.08 seconds standard**, and **12.335 seconds hard**, within the 12–20-second target. Outcomes included escape: 4/20 easy, 5/20 standard, and 12/20 hard. No run reached its 60-second cap; maximum duration was 22.92 seconds. Unguarded heavy strikes landed on 17/39 attempts easy, 25/53 standard, and 11/47 hard. Guarded impacts count separately from successful stun opportunities.

These observations informed the 360-HP production default and 60-HP/second healing rate. They establish reproducible AI pacing, not human play quality.

## Automated verification

Focused checks cover finite harvest conservation, mirrored accessible tree placement, tapered stock, worker recovery, all tower profiles/upgrades, long-range dead zones, splash enemy damage and friendly exclusion, legacy scenario compatibility, custom grove application, and resource isolation. Existing movement, runtime, tactical, definition, and coordination fixtures were run during implementation. The tower fixture stops audio and allows playback cleanup before exit; standard-engine verbose verification reports zero assertion failures and no ObjectDB leaks.

Final staged engine, integrated match, performance, layout and Android export results remain pending. Engine/platform diagnostics must be distinguished from gameplay assertion failures in those results.

Useful commands:

```sh
python3 tests/verify.py --godot /path/to/Godot --suite fast
/path/to/Godot --headless --path . --script tests/economy_pacing_lab.gd
/path/to/Godot --headless --path . --script tests/commander_duel_lab.gd -- --report=/absolute/path/duels.json
```

## Pending human checkpoints

1. Combat playtest: test whether heavy strike is difficult to land yet readable, whether guard/dash counterplay feels fair, and whether recovery leaves meaningful openings. Assess duel duration, retreat cost, and feedback in crowded combat.
2. Landscape Android playtest: record the device model; test both orientations, cutouts, thumb reach, simultaneous movement/action touches, gesture cancellation, portrait recovery, drawers, and access to every action.
3. Integrated match playtest: assess the 10–15-minute match target, transition from safe to exposed wood, lane distribution, tower counters, and the ability to keep recruiting after wood exhaustion.

Keep #6 and #8 open until their human checkpoints pass. Close other issues only after their integrated acceptance checks pass and evidence is attached.

## Verification stopped at the user's request

The user prohibited launching Godot, including headless runs and exports, to avoid interfering with their work. No further engine checks should run without a new explicit instruction. Earlier completed fixture and duel measurements above remain historical evidence for their tested snapshots; subsequent static fixes have not received a final engine gate.

All eight issues have source implementations. The full integrated match sweep, uncontended performance comparison, final staged regression gate, and physical Android/combat acceptance remain incomplete. An Android APK has **not** been built. The performance comparison helper supports a preserved baseline directory and revision `7179af9`, and avoids adding a duplicate projectile phase to a session-based baseline; it has been prepared without launching Godot.

## Final static checks

After the engine stop and integration fixes, project/resource validation passed for 103 Godot files and 123 resource references. Localization validation passed for 250 bilingual keys and matching placeholders. All 13 Python tests passed, including production Android staging without running Godot. `git diff --check` passed.

The final static-only fixes include valid mobile Interact commands, shared rally movement speed, scrollable centered mobile drawers, exclusive context surfaces, grove override replacement and placement failure reporting, and bounded/logged Android build steps. Final engine parsing, final drawer screenshots, the APK, and integrated pacing/performance verification remain pending. The interruption left no completed rework full match; see [balance results](rework-balance-results.md) for exact evidence.

Android packaging is prepared in `tests/build_android.py` and the Android export preset. It stages production directories only and preserves the desktop template. When engine execution is explicitly authorized again, provide a matching official `android_debug.apk` template and run the build helper. It writes import/export diagnostics, checks the resulting APK signature, and produces a SHA-256 file. No installable APK exists for this rework yet.

## Branch integration — October 3, 2026

The fetched rework at `078b942` is combined with local fixes through `8c28682`, including resource validation, registry caching, living-actor Rally counts, and the death/projectile presentation trace. Both source histories and the pre-existing local documentation edits are preserved. See [integration record](branch-integration.md).

Combined-source static validation passes: 104 Godot files and 125 resource references, 250 matching English/Russian keys, and all 13 Python tests. These counts include restored match-rule validation. An initial check of the pre-merge local snapshot failed at Godot import because the sandbox denied the TCP socket; it is not an engine pass or a gameplay failure. After discovering the recorded engine-stop request above, no further engine executions were performed. Combined-source engine parsing, runtime, rendered layout, full-match pacing and performance remain unverified.
