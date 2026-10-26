# Abstract sprite library

112 small, rule-neutral graphics for the games described in the repository README. These are original geometric marks, connection pieces, frames, hubs, and surface patterns. They are intentionally simple so a game can give them its own meaning.

| Folder | Count | Good for |
| --- | ---: | --- |
| `tokens/` | 24 | Pieces, counters, resources, selection marks |
| `frames/` | 16 | Cells, slots, focus rings, containers |
| `conduits/` | 24 | Paths, pipes, wires, branching connections |
| `nodes/` | 16 | Hubs, sockets, special locations |
| `accents/` | 16 | Small overlays and status marks |
| `textures/` | 16 | Tile surface treatments |

Every sprite has a transparent 128 × 128 PNG and a matching editable SVG. The artwork is white with varying opacity. Use Godot's `modulate` to tint it to a game's palette. The [`contact_sheet.png`](contact_sheet.png) shows all assets on a dark background, and [`manifest.json`](manifest.json) lists their paths.

The conduit ends reach the canvas edges, so they can connect when placed on adjacent 128 × 128 cells. Rotate them in 90° steps for other orientations. Frames leave open space for a number or piece. Textures have a faint rounded outline and can be layered over a filled tile.

Because each game is a separate Godot project, copy the sprites it uses into that game's project folder, then load them with `res://`. For example, after copying `tokens/open_ring.png` to `<game>/art/open_ring.png`:

```gdscript
$Piece.texture = preload("res://art/open_ring.png")
$Piece.modulate = Color("#69c9c4")
```

Run `python _assets/generate.py` from the repository root to rebuild the SVGs, PNGs, manifest, and contact sheet. The generator needs Python Pillow and `rsvg-convert`.
