# Crownfront — 2v2 Strategic Overhaul

A playable local 2D action/strategy prototype for **Godot 4.6.2 Standard**, using GDScript and original procedural art. Two commanders share each team's King, gold, wood and upgrades. **Destroy the opposing King to win.** Commander deaths cost time, not the match.

Development branch: `feat/2v2-strategic-overhaul`.

## Run

Import `project.godot` in Godot 4.6.2 and press **F5**. Run the main scene, not an individual entity scene. No external artwork, credentials, backend or networking is required. The bundled Godot MCP addon is an editor/testing integration, not gameplay logic.

The Compatibility renderer uses a 1280×720 reference canvas with expanding aspect and anchors/containers. 1280×720, 1280×800 and 1920×1080 were rendered and inspected at their actual image dimensions.

## Teams and controls

| Team | Commander | Controller |
| --- | --- | --- |
| Azure | 1 · YOU | Human; white double ring and YOU marker |
| Azure | 2 · Warden | Balanced support AI; guards approaches, builds and joins pushes |
| Ember | 3 · Vanguard | Aggressive AI; concentrates mixed recruitment waves |
| Ember | 4 · Steward | Economy/defense AI; gathers, builds and reinforces |

| Input | Action |
| --- | --- |
| WASD | Move; normalized diagonals, terrain collision and map bounds |
| Hold Space | Strike a nearby enemy; respects range, cooldown and line of sight |
| E near your King | Open King upgrades; full heal with a 30-second cooldown |
| E near a pad | Show its contextual construction/upgrade panel |
| Mouse wheel over battlefield | Zoom within 0.7–1.1× |
| Route dropdown | Choose **North / Center / South** for new army recruits |
| Army / King / Economy tabs | Recruit units or purchase shared upgrades |
| Escape / Pause button | Pause or resume; restart from pause or results |
| Pause → Settings → Language | Switch English / Русский immediately; selection is saved |

Commanders have 180 HP, 24 damage per 0.55 seconds, 65 reach and 230 movement speed. All four respawn at separate base positions after **12 seconds**. Only the human owns an enabled camera. The two friendly commanders contribute to the same economy; the Warden normally leaves **120 gold and 45 wood** for the human. Human commands can spend that reserve.

## Crown Pass battlefield

The world is **4600×2600**, with two citadels, three winding roads, connecting clearings, raised terrain islands and nine strategic build pads. There is open maneuvering space around roads; this is a route network, not a literal maze.

- **North / Pine road:** bends through forward groves and the northern crossing.
- **Center / Crown pass:** the shortest approach, with several turns between terrain islands.
- **South / Lowlands:** a broad flank through exposed timber and the southern crossing.
- Each base has a protected Gate pad. Grove watchposts cover approach roads and resource access. The three neutral crossing pads are exposed positions that can change ownership after destruction.

Units retain their assigned lane after recruitment. Changing the dropdown affects subsequent recruits and briefly emphasizes the route on the minimap. The minimap shows all teams—there is **no fog of war**—with large King/commander markers, tower/pad symbols, groves, terrain, army clusters and the camera footprint.

Measured unopposed base-to-King approach times, including up to six seconds of assembly at the first waypoint:

| Unit | Center | North | South |
| --- | ---: | ---: | ---: |
| Melee | 41.4 s | 45.3–45.4 s | 44.8 s |
| Ranged | 45.1 s | 49.5 s | 48.9 s |
| Tank | 53.6 s | 59.0 s | 58.3 s |

Both directions were tested. Combat and detours naturally increase travel time; groups can leave the assembly point sooner.

## Economy, workers and recruitment

Both teams begin with **210 gold, 35 wood and three free workers**. Passive income is **10 gold/second**. Workers deliver equal amounts of wood and gold. Purchases/upgrades are available anywhere; actual tower construction requires a living nearby commander.

Safe groves are finite: eight trees per team, 140 wood per tree. Forward groves are renewable and exposed. Workers spread across trees, travel via the same terrain-aware navigation as armies, gather, carry visible logs, return and deposit. They flee enemies sensed within 190 reach and temporarily avoid the threatened grove. This reduces repeated suicide trips without making forward gathering risk-free.

| Recruit | Gold | HP | Damage | Speed | Reach | Cooldown |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Worker | 65 | 65 | — | 105 | — | — |
| Melee | 50 | 110 | 16 | 105 | 26 | 0.85 s |
| Ranged | 75 | 70 | 14 | 95 | 180 | 1.10 s |
| Tank | 115 | 400 | 24 | 78 | 30 | 1.35 s |

Reach is measured between body edges. Tanks prioritize visible fortifications and deal **1.75× damage to towers/Kings** (42 damage), giving a successful army a way to break defenses. Ranged units maintain distance and back away from close attackers. Frontliners use slightly different approach points; lightweight separation spreads actors without turning them into solid navigation obstacles.

Team caps remain **10 workers and 40 combat units**. Commanders, Kings and towers do not consume these slots. Worker death loses the carried load.

## Guard Towers and pads

Approach an empty pad and use **BUILD**. A tower costs **140 gold + 55 wood**, deducted atomically from the shared wallet. Enemy home pads are protected; occupied pads cannot be overwritten. Destroyed towers release their pad after an **eight-second rebuild cooldown**.

| Level | HP | Damage | Reach | Cooldown | Upgrade cost from previous level |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 | 480 | 18 | 245 | 1.20 s | Construction: 140 gold + 55 wood |
| 2 | 640 | 24 | 265 | 1.08 s | 100 gold + 65 wood |
| 3 | 800 | 30 | 285 | 0.96 s | 200 gold + 130 wood |

Upgrades add 160 current/max HP, preserving missing health. Only friendly towers can be upgraded, by a living commander within 150 pixels and clear line of sight. Pads and towers do not block roads.

A plus sign means an empty pad; team-colored pennants and a solid outline identify ownership; a grey cross and progress arc mark cooldown. Towers show visible shot trails, hit flashes, health, construction/death effects and an upgrade pulse. The first milestone deliberately uses one tower type.

## Kings and shared upgrades

Kings begin with **1200 HP, 32 damage, 225 reach and one attack/second**. They defend automatically. Sustained damage or critical health triggers a restrained HUD/minimap warning with a 15-second alert cooldown. King death freezes gameplay immediately and plays a brief crown-break effect/result fade; restart creates a fresh match.

The King and Economy tabs show each track's level, current → next value and wood cost. Existing and future workers receive shared upgrades immediately.

| Track | First wood cost | Added per level |
| --- | ---: | --- |
| King health | 35 | 220 max/current HP |
| King damage | 40 | 8 damage |
| King attack speed | 45 | 0.2 attacks/second |
| King range | 40 | 24 reach |
| Worker movement | 35 | 18 speed |
| Worker capacity | 30 | 5 wood |
| Worker gathering | 45 | 0.8 wood/second |
| Passive income | 65 | 2 gold/second |

Each track caps at eight; next cost is `ceil(base_cost * 1.55 ^ level)`. AI limits routine King investment to two levels per track so it does not indefinitely fortify a base instead of fighting for territory. Human upgrade limits remain unchanged.

## AI and match pacing

AI is attached to individual commanders, never embedded in Team. It senses nearby enemies and receives the friendly King's local alarm; it does not query hidden enemy armies across the map. The enemy King's known location is a strategic objective.

Aggressive commanders save for mixed groups, march at army pace, and reinforce established friendly lane pressure. Support/economic commanders handle worker replacement, towers, approach patrols and periodic pushes. All react to King danger and return for supplies when badly wounded. Controllers respect a teammate's announced tower budget, avoiding two bots spending the same planned resources. They use the exact same purchase/upgrade/build validation as the human; no ongoing resource cheats.

The map, finite safe timber, shared economy and vulnerable forward defenses create the pacing. There are no scripted early/mid/late phase bonuses or forced King damage. Completed automated samples lasted roughly **10–21 minutes**, with variation by tactical seed and simulation step. This is evidence of progression, not proof of competitive balance.

## Architecture and tuning

| Area | Responsibility |
| --- | --- |
| `scripts/core/game_manager.gd` | Match composition, team lookup, command validation, spawning, King-only result, shared spatial index |
| `scripts/core/team.gd` | Team ID, wallet, roster, stat/upgrade data and change signals; no controller decisions |
| `scripts/player/player.gd` | Persistent commander body, camera, health, interaction and respawn |
| `scripts/player/human_controller.gd` | Input adapter driving that body |
| `scripts/ai/enemy_ai.gd` | Independent commander strategy, sensing, spending and movement decisions |
| `scripts/navigation/route_map.gd` | Lane waypoints, static obstacle rectangles, shared AStarGrid2D, swept collision and line of sight |
| `scripts/units/` | Common damage/targeting/path cache; role-aware combat units; King specialization |
| `scripts/workers/` | Tree supply and gather/return/avoidance state machine |
| `scripts/structures/` | Pad lifecycle and Guard Tower combat/upgrades |
| `scripts/ui/` | Container-based HUD, contextual construction, shared shop icons and clustered minimap |
| `scripts/visuals/` | Original procedural silhouettes and short-lived effects |

Existing scene composition, team ownership, economy, worker state machine and resource definitions were extended rather than rebuilt. Explicit strategic routes plus a shared static A* grid were chosen over navigation baking: terrain is fixed, moving actors/pads do not obstruct paths, and all systems use identical geometry. Cached paths recover after endpoint changes, obstruction and respawn.

Tune unit `.tres` files in `resources/units`, upgrade `.tres` files in `resources/upgrades`, `resources/battle_balance.tres`, team starting stats, and the route-map layout. Main's exported `strategy_seed` makes AI timing reproducible. Numeric data is copied into combat entities; shared resources are not modified during matches.

For future local/network players, replace a commander controller while retaining its body and team. The command boundary is ready for explicit authority validation, but networking still needs stable entity/controller IDs, authoritative input/command transport, synchronized simulation and replication. None of those are implemented here.

## English / Russian localization

English is always the first-launch default, even on a Russian operating system. Open **Pause → Settings → Language** to choose **English** or **Русский**. The same Settings menu is available after victory/defeat. Changes update the HUD, notices, shop, tooltips, world labels, routes and result screens immediately, including while paused. Escape closes Settings first; the match stays paused until you resume.

- `localization/en.tres` and `localization/ru.tres` are native Godot **Translation** resources with 122 matching symbolic message keys. They are editable text resources, requiring no translation importer or external service.
- The `Localization` autoload registers them with `TranslationServer.add_translation` during startup and explicitly sets the chosen locale. Godot's native `tr()` and Control auto-translation perform lookup; there is no parallel custom translation dictionary.
- `user://settings.cfg`, section `[interface]`, key `language`, persists the selection using `ConfigFile`. Missing, unreadable or unsupported preferences fall back to `en`; the operating-system locale is never selected automatically. A failed write displays a localized message while keeping the chosen language active for that session.
- Dynamic notices retain their key and formatting arguments so already-visible notices update too. Team names, unit/upgrade presentation fields and commander status labels are keys; gameplay IDs remain unchanged.
- World drawing responds to `NOTIFICATION_TRANSLATION_CHANGED`. Tab titles and formatted HUD values refresh on `language_changed`. The existing Godot fallback font contains every Cyrillic glyph used by the Russian catalog, verified through `Font.has_char` and actual rendered captures.

To add a language, copy a catalog, set its `locale`, translate the values while retaining every symbolic key and `%` formatting placeholder, and register the resource in `scripts/localization/localization.gd`. Add its locale to `LANGUAGES` and its autonym to the Settings dropdown in the same order. Extend `tests/validate_localization.py` and the runtime/capture tests to cover the new language. Use the English fallback for missing translations during development, but complete the catalog before release. Recheck long text at all supported resolutions.

## What was tested

See [the verification report](docs/verification.md) for exact results and limitations.

```sh
python3 tests/validate_project.py
python3 tests/validate_localization.py
godot --headless --path . --script tests/localization_regression.gd
godot --headless --path . --script tests/localization_launch.gd -- write
godot --headless --path . --script tests/localization_launch.gd
godot --headless --path . --script tests/runtime_smoke.gd
godot --headless --path . --script tests/route_travel.gd
godot --headless --path . --script tests/tactical_regression.gd
godot --headless --path . --script tests/match_simulation.gd -- 42
godot --headless --path . --script tests/match_simulation.gd -- 19 0.016666667
godot --path . tests/live_playtest.tscn --quit-after 1500
godot --path . --script tests/visual_review.gd -- battle 1280x720 ru
```

Use your Godot executable path if it is not on PATH. Initial editor import registers script classes. Tests use the real game scripts. `live_playtest.tscn` sends input events and creates a staged test encounter before restarting to a normal match. Visual scenarios include `base`, `battle`, `king`, `economy`, `pads`, `pad_states`, `danger`, `pause`, `settings`, `victory`, and `defeat`. The optional third visual argument chooses `en` or `ru`; capture dimensions are asserted against the actual image. Test captures/logs/JSON go to ignored `tests/artifacts/`.

## Known limitations / next step

- Local prototype only; no online/local second human UI, accounts, matchmaking or backend.
- Full-information minimap, no fog, no sound pass, hitscan damage with animated traces rather than physical projectiles.
- AI is intentionally lightweight. It can make inefficient purchases and does not tactically optimize tower upgrades. Long match length varies; very defensive human play can prolong it.
- Static rectangular terrain, no dynamic wall building, no full crowd simulation. Dense battles still have overlapping silhouettes despite zero severe overlaps in the tested 60-unit stress case.
- Automated playtests substitute an AI for the human. Input automation and screenshot inspection were performed; extended subjective human playtesting was not.

The most valuable next milestone is **human playtesting and balance telemetry**: test openings, reinforcement control, defensive counterplay and camera/HUD comfort with real players before adding networking.
