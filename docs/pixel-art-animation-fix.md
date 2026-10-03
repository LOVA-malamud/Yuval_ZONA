# Manual-playtest animation repair

Fixed on `feat/pixel-art-action-overhaul` following the three manual-playtest screenshots from 2026-10-03. Changes remain local and uncommitted.

## Issue index and repair decisions

| Issue | Evidence / cause | Repair |
| --- | --- | --- |
| Detached heads, absent bodies, unrelated fragments while moving | All 20 local body/leg imports still used the previous 48×64 grid: bodies 2304×1152 and legs 2304×128. Current source uses 32×40 cells: bodies 1536×760 and legs 1536×120. The runtime was slicing an incompatible texture. | Reimported the workspace; validate atlas dimensions before slicing and recover the current source PNG once per mismatched atlas during source development. |
| Broken action particles and arrows | Local effects import was 3072×640; source is 1536×352. | Apply the same validation/recovery to the shared effects atlas. |
| Raised weapon or blocking shield can appear detached | The art rig moved equipment for heavy preparation and guard recoil without moving the hand/arm to its new grip. | Share grip coordinates between equipment and arms; rebake both teams and all roles/facings/frames. |
| A terminal launch can retain stale artwork | Direct Godot game execution does not perform the editor import pass. Previous checks imported isolated staging copies and missed this developer-cache state. | Add `tools/run_game.py`, which completes the import pass before launching. Update game and preview instructions. |

The prioritization was to repair the atlas interface first, then inspect the actual poses and fix equipment attachment. Redrawing the character pack before correcting the incompatible imports would have left the screenshot failure in place.

## Run the corrected game

Close the existing game process and run from the repository:

```sh
python3 tools/run_game.py
```

For the native action/facing preview:

```sh
python3 tools/run_game.py --preview
```

The fallback is for outdated local source imports; correctly imported assets continue using their original textures. Exported builds must use the normal import/export pipeline. There are no changes to combat damage, movement, reach, cooldowns or worker resource behavior.

## Verification

- Captured the native gallery against the actual stale workspace cache before reimporting: recovery restored whole characters and reported the incompatible atlases.
- Confirmed all local pixel PNG dimensions match their refreshed imported texture dimensions afterward.
- All 24 fast verification checks pass, including a reproduction using old-size body/effect textures, source recovery, texture reuse and the normal correctly imported path.
- All 11 native capture checks pass. Reviewed the corrected eight-direction gallery, crowded desktop battle, workers and touch layouts at the supported zoom range. Evidence is under ignored `tests/artifacts/pixel_cache_fix_visuals/`.
- All 6 render verification checks pass, including the animation regression and 30/60 FPS parity; evidence is under `tests/artifacts/pixel_cache_fix_render/`.
- Rebuilt all sprites with the existing live-pose clipping checks. The offline viewer and contact sheets use the same regenerated PNGs.

Manual retest priorities: walk/stop in every direction; heavy preparation and misses; frontal guard recoil; workers chopping/carrying/fleeing/depositing; pause/resume and respawn. The earlier benchmark in the delivery report describes its earlier source snapshot, not a new measurement of this repair.

All three verification runners above match production SHA-256 `9836d338d3288537f93cdbeecb13ffc6d0afd467c214627e00a4e7cf75826c96`.
