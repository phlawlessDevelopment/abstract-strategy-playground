## Attribution

| Agent | Model | Contribution |
| --- | --- | --- |
| Claude Code | Claude Sonnet 5.5 | Game design, rules, Godot implementation, computer opponent, balance testing, Linux export, and web publishing |

# Warp & Weft

*One shuttle, two directions.*

A two-player abstract game on a grid of numbers. There is a single shuttle, and both players share it: **Weft** may only slide it sideways, **Warp** may only slide it up and down. You score the number you land on, and where you land decides the only line your opponent gets to choose from. The game ends when the player to move has nothing left on their line.

Games take about 5 to 10 minutes. See [RULES.md](RULES.md) for how to play, plus design notes on what was measured and what is still uncertain.

## Play

From the playground root:

```bash
godot --path warp-and-weft                    # in the editor's runtime
./warp-and-weft/build/linux/warp-and-weft.x86_64   # the exported Linux build
```

In a browser: https://phlawlessdevelopment.github.io/abstract-strategy-playground/games/warp-and-weft/

Click a lit cell to move. Hover one to preview the line you would hand over. **R** new game, **S** same board, **U** undo, **H** hints, **F1** rules. Play against the computer (Easy, Medium, Hard) as either side, or two players on one screen.

## Code

| File | What it does |
| --- | --- |
| `scripts/rules.gd` | Pure game logic: board generation, lanes, moves, undo, scoring. No nodes. |
| `scripts/ai.gd` | The computer: a margin-maximising alpha-beta search with iterative deepening. |
| `scripts/board_view.gd` | Draws the board, lanes, trail and shuttle; turns the mouse into cell events. |
| `scripts/main.gd` | Window layout, controls, and turn flow. |
| `tools/test_rules.gd` | Rule tests, plus a check that the pruned search equals a brute-force search. |
| `tools/ui_flow.gd` | Drives the real scene with mouse and key events, including whole games. |
| `tools/selfplay.gd`, `edge_stats.gd`, `diagnose.gd`, `time_hard.gd` | The balance and speed experiments quoted in the design notes. |
| `tools/screenshot.gd` | Renders the scene to PNGs (needs a display). |

```bash
godot --headless --path warp-and-weft -s tools/test_rules.gd     # rules and search
godot --headless --path warp-and-weft -s tools/ui_flow.gd        # the whole UI, headless
godot --headless --path warp-and-weft -s tools/selfplay.gd -- games=100 a=4 b=2 komi=4.5
```

The few sprites in `art/` (the cell frame, the weft and warp thread textures, and the shuttle) come from the playground's shared asset pack and are tinted in code.
