# Contributor guide

Use Godot **4.7.2 Standard**, GDScript and the Compatibility renderer. `scenes/main/main.tscn` composes a match; `tutorial.tscn` enables its separate guided mode.

## Simulation and lifecycle

`MatchSession` owns a fixed 60 Hz clock, actor IDs, command queue and lifecycle: initializing, running, paused, finished and stopped. Production physics and accelerated matches call the same `step()`. Economy, controller decisions, actors, projectiles and coordination advance there; they have no separate gameplay process clocks. Paused and finished sessions do not advance.

Actors register once and leave the registry on tree exit. Dead commanders remain for respawn. Do not enumerate global groups for cross-match gameplay: use the owning session registry and the match’s Trees/Entities nodes. Projectiles are filtered by owning game.

`presentation_enabled = false` removes the HUD, battlefield and cameras and bypasses effects/audio. Rendering does not choose gameplay outcomes. Two concurrent matches in the parity fixture also verify match ownership.

## Commands and events

Construct `MatchCommand(action, commander_id, payload)` and call `session.submit()`. The monotonic receipt completes through `command_completed(receipt, CommandResult)`. Accepted commands execute FIFO at the next command phase and validate the current wallet, route, actor and target. Pause, finish and stop cancel pending work. Rejected submissions complete immediately. UI purchase feedback follows completion.

`execute()` is the synchronous adapter for fixed-tick controller intentions and compatibility helpers. Human and AI movement, attacks and interaction use validated INPUT payloads; controllers choose intentions, bodies execute them. Recruitment, upgrades, tower construction, ally orders, Rally and Regroup share this boundary. Creation failures cannot consume resources or change counts.

Purchase, death, respawn, deposit, coordination, alert and result events originate in gameplay. `publish()` adds simulation time and tick, copies payloads and guards observer re-entry into immediate mutation. Observers may submit future commands. Recap attribution uses stable commander/actor IDs.

## Resources

`resources/content_catalog.tres` lists UnitStats and UpgradeDefinition resources and common army/worker scenes. Keep content ID separate from category and tactical role. For a fourth recruit using an existing role, copy a unit resource, give it a unique ID and translated display name, add it to the catalog, and retain a supported `melee`, `ranged` or `tank` role. Army art, recruitment cards and replay metadata use the role; AI builds its roster from catalog roles. A genuinely new behavior needs code and corresponding coverage.

`default_map.tres` resolves MapDefinition bounds, obstacles, three route geometries, bases, renewable groves and home/neutral pads. Navigation, battlefield and minimap share that definition. `default_rules.tres` resolves starting resources, caps, worker cost, grouping wait, troop speed multiplier and difficulty. GameManager duplicates mutable runtime definitions; fixture edits to external resource entries should explicitly duplicate those entries too.

Each definition exposes `validation_errors()`. Match creation rejects missing factories/definitions, duplicate or reserved IDs, unsupported roles, invalid numeric values, missing unit translations, unknown upgrade stat keys, out-of-bounds geometry and incompatible lane/base counts before creating gameplay actors. Scenario numeric/unknown-field validation remains the runner’s separate boundary.

To prototype a map, duplicate the resource and set it on a main-scene instance. Keep this shipped game’s three-lane/two-team semantics, valid paths and reachable spawns. `definition_regression.gd` demonstrates a renamed ranged recruit, changed bounds/route and worker price without editing controllers.

## Verification and experiments

`python3 tests/verify.py --suite fast` stages an isolated project and XDG preference directories, checks source/localization/Python, imports Godot and runs the regression fixtures. Engine script errors, unexpected errors, leaked resources and nonzero exits fail verification. `--fixture NAME` diagnoses one fixture; it does not imply the whole suite passed.

`--suite desktop` adds exact-pixel SubViewport captures at five sizes in both languages, 30/60 FPS trace parity, native viewport input and simulated safe areas. A compositor may resize the native window; captures explicitly use the requested pixel size. `--suite full` adds three complete seeded matches and replay validation. CI runs fast checks; display-dependent checks are local.

Version-1 scenarios retain their existing meanings. Unknown fields fail validation. Add tuning fields to `tests/match_scenarios.py` and apply them before actor creation; record effective values. Run paired seeds and both assignments for asymmetric configurations:

```sh
python3 tests/run_lab.py --suite matches --seeds 42,43,44 --scenarios tests/scenarios/pacing.json --jobs 2
python3 tests/validate_replay.py tests/artifacts/game_lab_report.json
node tests/check_replay_browser.mjs tests/artifacts/game_lab_report.html
```

Replays use version 3 source events, stable IDs, metadata and sampled motion; old replay views remain supported. `--sample-seconds 5 --no-html` keeps large experiments manageable. `--resume` accepts checkpoints only with identical source digest, engine, seeds, limit, sample interval and scenario config. Technical failures fail the runner and never count as balance results.

`--suite tuning --match-jobs 4` runs seeds 42–61 over the eight agreed grouping/speed/tower-health configurations. `select_pacing.py` chooses the fewest changed values meeting the 12–18 minute median and at most two timeouts; otherwise it reports the target unmet and selects the nearest eligible fallback.

Run `python3 tests/compare_performance.py` (headless) and `python3 tests/compare_performance.py --mode rendered --output tests/artifacts/performance_rendered` alone, with no other Godot instances, for three sequential 115-actor capacity runs per revision, including projectiles. It reports median p50/p95/max and flags p95 regression over 10% for investigation. Fixture durability sustains combat; these stress timings are not balance measurements. Generated artifacts stay under ignored `tests/artifacts`.
