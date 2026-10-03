# Crisp medieval pixel art delivery

This report records the original delivery snapshot. The subsequent manual-playtest cache and equipment-attachment repair is indexed in [the animation fix report](pixel-art-animation-fix.md), with fresh regression/capture evidence and the corrected launcher.

Implemented on `feat/pixel-art-action-overhaul`, based on `aca1f34`, with local uncommitted changes. Verified on Linux with Godot **4.7.2 Standard**, Compatibility/OpenGL, Intel HD Graphics 630. See [the approved plan](pixel-art-action-overhaul-plan.md).

## Delivered behavior

- Original eight-direction Azure/Ember sprites for human/AI commanders, sword infantry, hooded archers, siege-hammer tanks and straw-hat workers. Native atlas size is 32×40 with two-world-pixel clusters and transparent weapon/cape margins; all atlas widths stay below 2048 pixels. The art generator rejects clipped live poses.
- Independent walking legs and upper-body actions. Displacement drives footsteps, including moving attacks, guard walking, loaded trips and ranged retreat. Idle retains facing; diagonal hysteresis prevents flicker. Offscreen actors keep time/motion/facing cheaply and refresh poses on re-entry.
- Commander strike preparation, sword follow-through on hits and misses, heavy wind-up/swing/recovery, directional guard with successful-block recoil, dash/cape motion, healing, stun and respawn. AI commanders use the same presentation.
- Infantry cuts, immediate archer releases with pixel arrow projectiles, cooldown-based bow preparation, and heavier tank hammer recovery. Existing damage timing, projectiles, reach, movement, cooldowns and resource yield remain unchanged.
- Worker tree-facing chops and wood chips, contrasting log bundles, loaded retreat, deposit feedback and stationary waiting. Workers still flee rather than fight; troops acquire no new guard ability.
- Pixel shadows, slash/block/dash/heal/stun/spawn/death/deposit effects, half-second untargetable death remnants, hit flashes and matching recruitment portraits. Characters/action effects freeze on session pause/end; the existing victory crown burst retains its result-screen clock. Existing emblems, role distinctions, health bars, human marker and telegraphs remain.
- Small mobile layout repairs: the economy drawer reserves the combat-button strip, scroll pages fit the shorter drawer, and localized drawer text expands left while preserving its right safe-area margin. These repair baseline overlap/clipping without redesigning HUD art.

Production artwork is baked from [the original pixel rigs](../tools/generate_pixel_art.py). The built-in imagegen tool created [the medieval art reference](../assets/pixel_art/medieval-reference.png); [its exact prompt](../assets/pixel_art/art-direction-prompt.txt) and asset/layout notes are preserved. No third-party character pack or runtime Python dependency is introduced.

## Review artifacts

Open [the offline interactive preview](../assets/pixel_art/preview.html): select action, facing, team and moving legs; pause or scrub frames. [Facing](../assets/pixel_art/facing-contact-sheet.png) and [action](../assets/pixel_art/action-contact-sheet.png) contact sheets are tracked with the artwork.

```sh
godot --path . --script tests/pixel_art_preview.gd
python3 tests/capture_pixel_art.py --output tests/artifacts/pixel_visuals_final
node tests/check_pixel_preview.mjs
```

Native review captures include an exact 1280×800 sprite gallery; crowded battles at 0.7×/0.9×/1.1× zoom in 1280×720 desktop and 1600×720 touch views; actual chopping/loaded trips; and 960×540 English/Russian touch views. They are saved under ignored `tests/artifacts/pixel_visuals_final/`. They were inspected for readable silhouettes, weapon bounds, restrained effects and touch-control placement. The offline viewer passes atlas loading, eight facings, 19 pose rows, team switching, pause/scrub/resume and narrow-screen layout checks.

## Verification evidence

Production code/artwork SHA-256:
`209cdbb92f1c5289fcb41ab6d7ebf26aed906daec557796df38bf78f5f71cbe3`.

The verification, capture and performance runners fingerprint production artwork as well as scripts/resources. Ignored logs/captures are local evidence; use these commands to reproduce them on a fresh checkout:

| Command / report | Result |
| --- | --- |
| `python3 tests/verify.py --suite native --output tests/artifacts/pixel_native_final` | PASS, all 25 checks: 15 Python tests, import, the complete fast regression set and native input flow. |
| `python3 tests/verify.py --suite render --fixture pixel_animation_regression --output tests/artifacts/pixel_render_final` | PASS, all 6 checks, including richer 30/60 FPS traces. |
| `python3 tests/capture_pixel_art.py --output tests/artifacts/pixel_visuals_final` | PASS, all 11 checks, with the same production fingerprint. |
| Desktop visual matrix in `tests/artifacts/pixel_desktop_final/` | All 62 visual/layout captures pass across five sizes, both languages and simulated safe areas (before the final log-bundle contrast polish). The final art snapshot is covered by the zoom/mobile/worker runner above. The stale live-input fixture was repaired and separately passed in the native run above. |
| `node tests/check_pixel_preview.mjs` | PASS; final browser capture under `tests/artifacts/pixel_browser/`. |

The new animation regression covers all facings, blocked/stationary/teleported movement, light/heavy misses, guard front/rear hits, dash/stun interruption, healing interruption, immediate troop damage/arrow launch, walking attacks, worker activity, loaded retreat, deposits, offscreen refresh, isolated death remnants, respawn and pause/end. Repeated pose sampling is checked against the gameplay snapshot. Presentation/headless parity now includes ability state/timers, stun, healing, respawn and worker state/resources; rendered traces exercise dash, guard and heavy.

Verification uncovered baseline test drift: the live input fixture clicked the now-hidden generic build button instead of the actual Guard Tower choice; tight input/command scheduling margins and audio teardown also needed correction. The fixtures now exercise actual controls and wait for their existing processing boundary. No combat delay was changed to satisfy tests.

## Performance and limits

Final rendered comparison is recorded in `tests/artifacts/pixel_performance_final/comparison.json`, against `aca1f34`: three sequential runs per version, 115 sustained actors including projectiles, 3-second warm-up and 15-second samples at 1280×720. The current source fingerprint matches the final verification and captures; the comparison reports no performance regression requiring investigation.

| Frame-time metric (median across three runs) | Baseline | Pixel overhaul | Change |
| --- | --- | --- | --- |
| p50 | 4.298 ms | 3.522 ms | −18.1% |
| p95 | 12.676 ms | 12.322 ms | −2.8% |
| Maximum | 19.586 ms | 19.333 ms | −1.3% |

These are measurements on the desktop hardware above; wall-clock results vary between runs and do not establish phone performance.

Physical phone readability/performance and new Android/macOS packages are not claimed. Terrain, buildings, HUD art and balance retain their existing direction. Fractional zoom preserves smooth camera/movement; nearest-filtered source clusters can occupy uneven screen widths at fractional scales. The native zoom captures cover the supported extremes.
