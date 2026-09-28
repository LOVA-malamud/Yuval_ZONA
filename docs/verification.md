# Pre-playtest final polish verification

Published milestone: `pre-playtest-final-polish`, based on preserved strategic-overhaul commit `8ca89f7`. Historical results remain in [strategic-verification.md](strategic-verification.md). Prices/stats, King HP, passive income, upgrade costs, tower strength and AI decisions were not retuned.

Environment: Godot **4.6.2 stable**, macOS **26.5.2**, Intel Core i7 2.6 GHz, 16 GB RAM, AMD Radeon Pro 5300M, OpenGL Compatibility renderer. Final integration verification: September 28, 2026, following the initial September 25 audit and implementation.

## Changes and review

- Original procedural art retained: clearer human marker, commander rings, team emblems, siege hammer, tower level pips, quiet map labels, fewer healthy-unit health bars and strategic minimap markers. Existing approach offsets, ranged retreat and lightweight separation remain intact.
- Short attack motion, hit flashes and build/upgrade/deposit/impact/rubble effects; ordinary effects capped at 48, with King destruction exempt. King warnings outrank commander/purchase notices. King destruction/result transitions continue through pause.
- Nineteen original generated PCM cues, a reusable 12-player pool, cooldowns, distance attenuation and critical-event priority. About 305 KB of cached audio; no downloaded audio, music or empty music setting.
- Immediate Master/SFX volume, fullscreen/windowed, English/Russian, guidance preference and Reset to Defaults. Validated shared atomic persistence preserves the existing user-data location. Fresh installations start in English independently of OS locale.
- Nonmodal opening tips and a dismissible six-topic bilingual guide. HUD owns pause, panels own presentation, and GameSettings owns persistence. No forced tutorial match or additional gameplay state machine.
- Batched immutable grass geometry, cached/visibility-aware actor drawing, shop invalidation and conservative navigation broad rejection. The controller → commander body → team architecture and exact navigation intersection behavior are preserved.
- Production-only macOS staging excludes tests and editor integration. The published source also omits the local MCP addon and its project registration.

The lead reviewed runtime changes and subagent deliverables. Independent work covered performance/code audit, original audio/settings, Russian editorial/onboarding, final regression/code review and native export. See [initial audit](pre-playtest-audit.md), [regression review](regression-polish.md), [localization review](localization-polish.md), [performance report](performance-polish.md) and [export report](export-polish.md).

## Regression evidence

| Check | Final result |
| --- | --- |
| Project validation | 67 Godot files, 75 paths, scene/node references, seven inputs and upgrade keys pass |
| Localization validation | 170 matching bilingual keys; placeholders/references pass |
| Runtime smoke | 90/90 |
| Localization/glyph/live-switch regression | 14/14 |
| Settings/audio regression | 40/40 |
| Onboarding regression | 24/24 |
| New polish behavior regression | 23/23 headless; 26/26 rendered |
| Separate-process locale persistence | Write/read pass |
| Separate-process audio/display/guidance/locale persistence | Write/read pass |
| Route travel | All 18 unit/lane/direction cases plus worker detour; unchanged 41.4–59.0 s |
| Tactical regression | 12/12 |
| Crowd stress | 60 initial troops; 38 survive, 15 damaged; zero severe overlap pairs/terrain violations |
| Standalone real-input review | 32/32, including fullscreen/windowed, mouse sliders/popups, construction/upgrade, help, reset, restart |
| Normal opening minute | 10/10; 60.20 match seconds in 60.31 wall seconds |

The rendered audio test captured actual mixer output at maximum Master/SFX with twelve simultaneous ordinary/critical cues. The final rendered peak amplitude was **0.825375**, below clipping. The cache contains **304,966 bytes**, and the voice pool remains exactly **12 players**. This establishes technical playback/mixing evidence, not human listening approval.

Clean-install tests cover absent/corrupt settings, unsupported locale, invalid types, nonfinite/out-of-range volumes, defaults, unrelated-section preservation, failed saves and separate-launch persistence. Isolated paths protect the developer's real settings. Two ConfigFile parser messages are intentional corrupt-file diagnostics; positive-test runs have no unexpected errors or leak warnings.

The normal opening used ordinary resources, four real controllers and real input. It recruited a worker and infantry, walked to the Gate pad, observed carrying/deposits, built a tower with earned resources and ran the full first minute with both armies developing. No free resources or forced enemies were used. Captures: `opening_first.png`, `opening_tower.png`, `opening_minute.png`.

## Final integration evidence

- **Rendered layouts:** the core English/Russian matrix covered 1280×720, 1280×800 and 1920×1080 with zero final layout failures. The six-page help guide added 36 bilingual/resolution captures; all capture assertions passed and the images were inspected for clipping, overflow, wrapping, alignment and Cyrillic rendering.
- **Performance:** the matched 115-actor, three-battle stress fixture improved from 5.20–5.34 FPS to 39.22–41.78 FPS across the three resolutions. The 60-second 720p soak averaged 37.99 FPS with 274–283 nodes, 3–12 live effects and 101.427–101.808 MiB sampled static memory. Headless simulation remained effectively unchanged at 5.697 versus 5.705 ms per tick; navigation parity covered 15,500 cases and improved from 168.035 to 47.816 ms.
- **Complete matches:** seed 42 ended at 678.6 simulated seconds, seed 7 at 994.1, and seed 19 at 598.1 using the 10 Hz fixture. A 60 Hz seed-19 run ended at 1276.80 seconds. Ember won all four samples; every run completed without a stall or assertion failure. These samples demonstrate completion and tactical variation, not competitive balance.
- **Godot/editor integration:** the final MCP-driven input run passed 30/30 with zero runtime parse errors or diagnostics. The normal main scene was restored and launched cleanly afterwards. MCP tooling was used only for development verification and is excluded from the published repository and release package.
- **Native macOS build:** the real exported x86_64 application passed 22/22 first-launch checks and 8/8 restart/persistence checks. An untouched application copy launched and exited cleanly. The universal binary contains x86_64 and arm64 slices, but only x86_64 was run. Strict ad-hoc code-sign verification passed after extraction outside the synced workspace.
- **Package contents:** the production PCK contains 104 resources and both locales, with no tests, documentation or editor integration. The finalized ZIP also contains `GODOT-LICENSES.txt` and `CROWNFRONT-ASSETS.txt`; generated builds remain outside source control.

## Problems found and fixed

- Default locale saves bypassed an overridden GameSettings path. They now delegate to the shared store while explicit paths remain supported.
- Purchases/commander death could overwrite King danger. Notice priorities now protect the objective alert.
- Active resource-gain text could retain its former language. It now refreshes on language change.
- Guidance dismissal did not report failed persistence. Localized failure feedback now preserves the current-session choice.
- Restart could retain previous-match sounds. All voices now stop before reload.
- Obsolete hidden instruction UI remained after onboarding. Removed the unused node and hide call.
- Headless imports could interfere with MCP autoload ownership. Bridge activation/cleanup now respect execution mode and ownership.
- Immediate test shutdown could race mixer teardown. Tests stop voices and allow a short drain interval.
- The initial performance fixture coupled role and battle lane, and its old headless report contained no samples. Final measurements use mixed-role battles and a pristine baseline; invalid measurements are excluded.
- Initial input failures assumed popup focus and instantaneous layout/native-window transitions. Corrected the harness; all 32 final checks pass without gameplay changes.
- Godot 4.6 macOS preset names/universal texture requirements differed from the initial configuration. Corrected staging/preset fields before native tests.

## Remaining questions for human playtesting

Automation cannot establish subjective fun, intuitive tip timing, audio taste, competitive balance or performance on other hardware. Dense silhouettes still overlap; there is no full crowd simulator. The minimap remains full-information, and damage remains hitscan with animated traces. No networking or major new gameplay system was added.

1. Is the King objective and commander respawn rule clear within the first minute?
2. Can players find themselves and distinguish frontline, ranged and siege roles in a crowded fight?
3. Are shared resources and ally spending understandable, and do recruitment/route controls feel responsive?
4. Do tips arrive when needed without distracting from play? Is the optional guide sufficient?
5. Are cues distinct and restrained over a long match, with King danger prominent enough?
6. Is the HUD/minimap comfortable at 720p? Does Russian terminology sound natural to native speakers?
7. Do defensive openings stall excessively, and can coordinated siege pressure convert territory into King damage?
8. Are the existing 10–21 minute automated durations appropriate for real players? Observe before changing balance.

Raw captures/logs/JSON are in ignored `tests/artifacts/`; reproducible scripts are tracked. Distribution artifacts are in ignored `builds/`. Historical verification is separate to avoid confusing old and current measurements.
