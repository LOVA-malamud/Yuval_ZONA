# Gameplay rework: balance evidence and remaining acceptance

Godot execution stopped at the user's request. Do not launch the editor, headless engine, builds, or engine tests until the user authorizes it again. Existing captured results were inspected with Python only after that request.

## Full-match comparison status

The intended comparison is 20 matching seeds (42–61), three difficulties, for both the original revision and the rework: 120 matches total.

Only **8 original-revision standard matches** completed (seeds 42–49). All were wins, with no recorded technical failures or timeouts. Their median duration was **968.06 seconds (16.13 minutes)**; four finished within the 10–15-minute target. All eight replay version 3 captures passed Python consistency validation.

**No rework full matches completed.** The interrupted standard runs reached 1,500 simulated seconds for seed 42, 1,530 for seed 43, 1,590 for seed 44, and 1,470 for seed 45. These progress lines are observations, not final match outcomes or replay captures. There are **zero completed baseline/candidate pairs**. Easy and hard full-match comparisons have not completed.

The observed unfinished rework matches already exceed the intended match-length target. Match pacing therefore remains provisional and needs diagnosis and tuning before acceptance. No claim about win rates, completed duration distributions, or improvement over the original revision is supported by this partial sweep.

Captured checkpoints and progress logs are preserved under `tests/artifacts/rework_comparisons/`; `partial-status.json` records the exact stop status. The original and candidate source snapshots remain under `/private/tmp/crownfront-rework-baseline` and `/private/tmp/crownfront-rework-candidate`. Candidate code changed after the interrupted snapshot, so a later comparison must create a fresh snapshot and retain its source digest.

## Combat and wood evidence recorded before the stop

The isolated duel lab with 360 commander HP reported median durations of 13.09 seconds (easy), 13.08 (standard), and 12.335 (hard). Successful unguarded heavy strikes were 17/39, 25/53, and 11/47 respectively. Guarded contacts are counted separately; they do not apply stun. These are automated counterplay measurements; human judgement of heavy-strike difficulty and duel enjoyment remains necessary.

The home-grove probe reported 280 seconds of safe supply with three starting workers after reducing home trees to 60 wood each. Full-match worker losses, upgrades, and construction can change that timing.

## Verification and later acceptance

Eight Python scenario/report tests passed after the engine stop. Earlier engine captures validated replay version 4 in 30- and 60-second smoke runs, including ability use, commander encounter escape telemetry, deployment counts, and finite wood.

Recent static fixes make AI recovery honor configured healing radius and prevent replacement-worker spending after every tree has depleted. Those final fixes have not been engine-tested.

When engine execution is authorized again: validate those fixes, capture the final candidate revision, complete the paired full-match sweep, investigate prolonged King stalemates, and rerun any resulting pacing change. Combat enjoyment and final Android ergonomics still require human playtests.
