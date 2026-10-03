# Original medieval character art

Original CROWNFRONT sprite artwork, authored for this project. No external character packs are used.

`medieval-reference.png` was created with the built-in imagegen tool as the art direction reference: five transparent medieval figures (Azure commander, sword infantry, hooded archer, siege-hammer tank, straw-hat woodcutter), steel/gold/warm skin palette, dark outlines, three-quarter facing, no text or environment. The exact prompt is in `art-direction-prompt.txt`. It is a development reference; gameplay and portraits use the original pixel rigs below.

`tools/generate_pixel_art.py` authors every production sprite directly on an integer grid and bakes the atlases. It does not trace, crop or transform the generated reference. Rebuild with Python 3 and Pillow:

```sh
python3 tools/generate_pixel_art.py
```

The generator rejects clipped live poses. Artwork uses 32×40 source cells with a `(16,31)` foot anchor, drawn at 2× into padded 64×80 world bounds. The extra transparent margin keeps raised swords, hammer heads and capes inside their cells. Commander bodies occupy approximately 48×64 world bounds; ordinary roles are smaller. Source resolution keeps atlas memory modest while retaining two-world-pixel clusters.

Each role has Azure and Ember body/leg atlases. Body columns are `direction * 6 + frame`, with directions E, SE, S, SW, W, NW, N, NE. Rows follow `atlas.json`. Legs have stationary, walking and braced rows. Weapons retain physical handedness rather than mirroring the whole character. Frames are sampled from gameplay timers; the artwork does not control combat.

`effects.png` uses 32×32 source cells, the same six-frame/eight-direction columns, and slash, heavy, block, dash, woodchip, heal, stun, death, deposit, spawn and arrow rows. Shadows and effects are pixel art too. Action effects pause with the session; the existing crown victory burst retains its result-screen behavior.

Review the original poses with `facing-contact-sheet.png`, `action-contact-sheet.png`, or open `preview.html` for an offline looping viewer with action, facing, team, movement, pause and frame controls. To use the native Godot preview:

```sh
python3 tools/run_game.py --preview
```

Space pauses, Left/Right changes facing, Up/Down changes action, and Escape closes it. Add `-- --capture` to save an exact 1280×800 review image under ignored `tests/artifacts/`.
