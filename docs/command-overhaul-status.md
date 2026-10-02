# Command and coordination overhaul

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

At this checkpoint, all 17 fast verification checks passed, including command
validation, shared-wallet contention, cancellation, coordination, tutorial
progress, resource-extension checks and presentation parity. Reports are local
ignored artifacts under `tests/artifacts/overhaul_final_gate/`.

The overhaul is an implementation checkpoint, not a completed release gate.
Final rendered/native-input verification, the complete 160-match pacing sweep,
performance comparisons, and final documentation remain incomplete. Earlier
rendered cases passed individually, but interrupted runs have no final suite
summary. No pacing adjustment should be justified from the partial sweep.
Physical phone/tablet testing has not been performed. Existing documentation
about earlier milestones remains historical evidence, not verification of this
branch.

Pending verification entry points:

```sh
python3 tests/verify.py --suite desktop
python3 tests/verify.py --suite tuning
python3 tests/compare_performance.py
```
