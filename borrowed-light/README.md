| Agent | Model | Contribution |
| --- | --- | --- |
| OpenAI Codex | GPT-6 | Original game design, rules engine, computer opponent, interface, playtesting, Linux export, and web publication. |

# Borrowed Light

**Three shared lanterns. Two colors of stone. Only what catches the light counts.**

A finite abstract strategy game on a 37-space hexagon. Slide any lantern, leave a stone behind, and reshape what the other lanterns can see. Includes a computer opponent for either seat, local two-player mode, move and score previews, hints, undo, and an in-game rules sheet.

Read [RULES.md](RULES.md) for the rules and design notes.

## Play

From the playground root, run the single-file Linux build:

```bash
./borrowed-light/build/linux/borrowed-light.x86_64
```

Or run the project with Godot 4.7.2:

```bash
godot --path borrowed-light
```

Browser version: https://phlawlessdevelopment.github.io/abstract-strategy-playground/games/borrowed-light/

The Linux executable is generated locally and ignored by the repository's build policy. To regenerate it after cloning:

```bash
godot --headless --path borrowed-light --import
mkdir -p borrowed-light/build/linux
godot --headless --path borrowed-light --export-release Linux build/linux/borrowed-light.x86_64
```

## Structure and verification

- `scripts/rules.gd`: pure positions, legal slides, light, scoring, and endings. Each move creates a new position.
- `scripts/opponent.gd`: deterministic minimax with alpha-beta pruning, adaptive depth, and a node budget. Runs without threads and works in the browser.
- `scripts/board.gd`: board rendering, mouse/controller/keyboard input, lighting previews, and movement animation.
- `scripts/main.gd`: interface and turn orchestration, including cancellation of pending computer moves when undoing or restarting.

Run the checks from the playground root:

```bash
godot --headless --path borrowed-light --quit-after 3
godot --headless --path borrowed-light --script res://tests/test_rules.gd
godot --headless --path borrowed-light --script res://tests/test_ui.gd
```

The rules checks cover occlusion, double illumination, immutable transitions, terminal positions, 400 random games to completion, and a computer versus random-play smoke test from both seats. Scene checks exercise previews, input callbacks, animated moves, both solo seats, cancellation during undo, hints, a full game, the final score, and restarting.

Godot's Compatibility renderer and single-threaded Web export are used. The game reads only packaged resources and has no runtime network dependencies. The three token sprites are copied from the playground's shared, freely reusable `_assets/` pack; the board and light are drawn in code. No external fonts, libraries, or downloaded artwork are required.
