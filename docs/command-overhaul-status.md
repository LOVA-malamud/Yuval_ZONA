# Command and coordination overhaul

Historical evidence for the local commander-overhaul snapshot through `8c28682`. This code is now integrated into `main` with a newer gameplay rework; these results do not verify the combined source. See [integration record](branch-integration.md) and [current rework acceptance](rework-verification.md).

Branch: `feat/command-and-coordination-overhaul`.

This branch adds persistent ally orders, local Rally and Regroup commands,
focus targeting, a playable tutorial, difficulty preferences, shared spending
visibility, battle alerts, and a match recap. It introduces match-owned content,
map and rules resources, a fixed 60 Hz session, validated commands, and replay
version 3 events. Existing English and Russian interfaces are extended.

Keyboard additions: Q Rally, R Regroup, and 1/2/3 select the route for new
recruits. Click an enemy to focus attacks while holding Space. Ally orders and
the tactical commands are also available through the HUD. The tutorial and
difficulty selection are available from the pause menu.

The verification workflow targets Godot 4.7.2. Run the isolated fast suite with:

```sh
python3 tests/verify.py --suite fast
```

The corrected final source passes the 18-check fast gate, all 82 desktop checks (the complete bilingual five-size matrix, cutouts, native controls and a death/projectile trace at 30/60 FPS), and 47 native feature/input checks including fullscreen restoration. Detailed evidence and remaining measurements are in [overhaul-verification.md](overhaul-verification.md).

The old pacing sweep is not established as complete. The local three-match full suite at `8c28682` passed all 20 checks; it does not verify the newer rework. Earlier pacing data is superseded by a correction to AI counting of queued dead troops. Three baseline/current capacity comparisons in each mode are complete; p95 regressed 17.1% for headless CPU and 10.4% for rendered frame time. Registry caching and avoiding hidden UI refreshes reduce the cost, but a regression remains. Physical phone/tablet testing has not been performed.

Final verification entry points:

```sh
python3 tests/verify.py --suite desktop
python3 tests/verify.py --suite tuning --match-jobs 4
python3 tests/compare_performance.py
python3 tests/compare_performance.py --mode rendered --output tests/artifacts/performance_rendered
```
