# Strategic overhaul verification

Verified with Godot **4.6.2 stable**, Compatibility renderer, on the development Mac. Work remains on `feat/2v2-strategic-overhaul`. The existing repository had no commits, so review used the preserved pre-overhaul source archive as the baseline; no baseline files were reverted or deleted.

## Final regression results

| Check | Result |
| --- | --- |
| `validate_project.py` | 56 Godot files, 65 resource paths, scene IDs/node paths, seven input actions and upgrade stat keys pass |
| `validate_localization.py` | 122 matching English/Russian keys, matching formatting placeholders, referenced literal keys pass |
| `runtime_smoke.gd` | 90 assertions pass; zero failures |
| `route_travel.gd` | All 18 unit × lane × direction cases and worker terrain detour pass |
| `tactical_regression.gd` | 12 checks pass; zero failures |
| `localization_regression.gd` | 14 checks pass; zero failures |
| `localization_launch.gd -- write`, followed by a separate launch without `write` | Russian preference written and restored in the second engine process |
| `live_playtest.tscn`, through Godot MCP and again as a standalone process | 18 checks pass in each run; zero failures; real viewport mouse/key/action events |

The smoke suite covers four independent commanders, shared team ownership/wallets, all recruit types, all eight upgrade tracks, immediate stat propagation, invalid purchases and friendly fire, worker gathering/deposit and finite resources, army movement, melee cooldown, King defense, AI production, tower construction/atomic payment/levels/ownership/attacks/destruction/cooldown/rebuild, all four respawns, pause/resume, victory, defeat and restart.

Tactical tests cover stale obstructed paths, small moving-target endpoint changes, forward commander resupply, respawn path reset, worker retreat and danger memory, terrain line of sight, tank structure priority/damage, and a 60-unit battle. After 30 simulated seconds of the crowd scenario, 38 units survived, 15 survivors had taken damage, no actor violated terrain, and there were **zero severe overlap pairs** under the test's body-distance threshold. Some drawn silhouettes still overlap; this is not a full crowd simulation.

Localization tests explicitly start from a Russian TranslationServer locale with no preference and verify English is selected. They test save/reload, unsupported-locale fallback, every catalog entry/placeholder, all used Cyrillic glyphs in the actual font, live shop/routes/tabs/notices, switching during pause, and switching after victory. Tests use isolated preference files or restore the user's original settings byte-for-byte.

## Long-match results

These use the real game scripts and economy. The test substitutes an aggressive AI controller for the human commander; it does not grant resources or force King damage. It advances game systems at a specified fixed delta, so simulation time is different from wall-clock execution time. Values below are observed samples, not a guarantee of balance.

| Seed | Step | Conclusion time | Towers built / destroyed | Commander respawns | Worker deposits | Peak army per team | First King damage |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 42 | 10 Hz | 11:18.6 | 15 / 8 | 9 | 391 | 31 | 4:24.2 |
| 7 | 10 Hz | 16:34.1 | 19 / 13 | 9 | 561 | 37 | 14:17.5 |
| 19 | 10 Hz | 9:58.1 | 15 / 8 | 4 | 328 | 29 | 0:57.4 |
| 19 | 60 Hz | 21:16.8 | 33 / 25 | 14 | 713 | 40 | 0:58.1 |

All four concluded naturally, passed their progression/terrain/stall assertions, and observed forward gathering. Seeds 7 and 19 used all three lanes; seed 42 used two. The longest measured commander travel stall was **2 seconds** in each sample (the monitor samples every two seconds). The 60 Hz sample recorded 3,301 aggregate worker-seconds gathering forward timber. Lane pressure, worker deposits, tower turnover, respawns and eventual King destruction were observed, rather than judging only the opening minute.

After localization, seed 42 was rerun to completion: **678.6 seconds**, Ember victory, identical tower/deposit/respawn/army metrics, zero failures. Gameplay data and AI decision behavior were preserved.

The wide variation between seeds and time steps is a remaining balance limitation. Seed 7 took over fourteen minutes to first threaten a King, although it then concluded. Further human balance testing should focus on defensive openings and how easily a coordinated push converts territory into King pressure. No claim of competitive balance or frame-step determinism is made.

## Travel and recovery

Unopposed travel, including the initial rally wait, remained **41.4–59.0 seconds**, depending on unit and lane. North/center/south were checked for melee, ranged and tank in both directions. Workers were tested around an obstructed route separately.

The original commander stalls came from cached path endpoints surviving target movement/respawn and blocked segments. The shared movement code now refreshes stale goals and blocked routes, and respawn resets the controller and path. The defensive stalemate fixes were directed at spending and pressure: mixed five-unit groups, reinforcing an established friendly lane, shared tower-budget reservations, capped routine AI King investment, slower commander replenishment and tank siege priority. No scripted match phases or global damage escalation were introduced.

## Visual verification

Actual `ViewportTexture` images were captured and their dimensions asserted; requested window sizes alone were not accepted as evidence. Every core matrix image was inspected individually.

| Scenario | English | Russian |
| --- | --- | --- |
| Army shop + battle + owned tower context | 1280×720, 1280×800, 1920×1080 | 1280×720, 1280×800, 1920×1080 |
| King upgrade tab | All three | All three |
| Economy upgrade tab | All three | All three |
| Empty build-pad context | All three | All three |
| Settings | All three | All three |
| Victory | All three | All three |

This is **36 core captures**, all with zero out-of-viewport control bounds failures. Review checked the top wallet/King bars, bottom dock, card icons and text, route selector, minimap, contextual tower information, settings and result controls. Cyrillic rendered correctly; no clipped/overlapping Russian control text was found. A Settings backdrop stacking issue was discovered by screenshot review and fixed before regenerating the matrix.

Additional English/Russian 1280×720 captures cover King danger, empty/friendly/enemy/cooldown pads and defeat. The MCP-driven live test also captured and inspected both languages in the actual **1280×800** embedded viewport. Editor embedding locks that window size, so the standalone rendered matrix supplies the other verified resolutions; the report does not mislabel resized embedded captures.

Captures and raw logs/reports live in ignored `tests/artifacts/`. Reproduce the matrix with:

```sh
godot --path . --script tests/visual_review.gd -- battle 1280x720 en
godot --path . --script tests/visual_review.gd -- economy 1920x1080 ru
```

Substitute `king`, `pads`, `settings`, `victory`, `defeat`, `danger`, or `pad_states` and the desired dimensions/locale. These are staged visual fixtures, not evidence of naturally occurring balance outcomes.

## Godot MCP and input verification

The live integration scene was selected as the main scene temporarily through MCP and started with `godot_play`. It tested movement, mouse purchase hit testing, route selection, Space attack, tower build/upgrade controls, wheel zoom, Escape pause, frozen economy, mouse-opening Settings, opening the native language menu, keyboard selection of Russian, immediate UI changes, disk persistence, Escape back/resume, restart and bilingual captures.

The final run reported **18 passes, zero failures**. `godot_get_runtime_parse_errors` returned **count 0** for `user://logs/godot.log`; bridge diagnostics returned empty error and warning lists. The current runtime log was also read directly and preserved as `final_mcp_live.log`. Main scene was restored to `res://scenes/main/main.tscn` afterwards, launched again through MCP, and its current runtime log and MCP parse-error check were clean. It was then stopped normally.

During verification, input injection was corrected to use local viewport coordinates for scaled embedded play and the popup's own window ID for native menu key events. [Godot's menu implementation](https://github.com/godotengine/godot/blob/4.6/scene/gui/popup_menu.cpp) supports arrow navigation; the harness no longer assumes End selects the last entry. These were test-harness corrections, not changes to gameplay input. The editor's stale 800-high project configuration was also synchronized to the final 720 reference canvas before final MCP testing.

Deep live-node inspection was not repeatedly retried. Earlier combined run/wait workflows could block the editor and archived-log selection was unreliable; direct scene/play/stop/diagnostic calls and explicit runtime capture scripts were used instead.

## Scope of confidence

The automated regressions and completed matches establish functional stability for the tested scenarios. They do not replace extended human playtesting, a native Russian editorial review, multiplayer tests, export/platform testing, or performance profiling on low-end hardware. The prototype retains full-information minimaps, hitscan damage with visual traces, static terrain, and no sound/networking. Dense fights can still visually overlap.
