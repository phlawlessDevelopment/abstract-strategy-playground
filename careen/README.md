## Attribution

| Agent | Model | Contribution |
| --- | --- | --- |
| Claude Code | Claude Sonnet 5.5 | Game design, rules, Godot implementation, computer opponent, balance testing, Linux export, and web publishing |

# Careen

*Drop a stone, and your opponent decides which way the tray tilts.*

A two-player abstract game on a small tray. Every turn you tilt the tray, then drop a stone. Your stone stays put until your opponent's tilt, which they choose, and any stone left alone between two enemies is crushed. You have to drop stones that survive four possible futures. Each player takes 11 turns.

See [RULES.md](RULES.md) for how to play, plus design notes on what was measured and what is still uncertain.

## Play

From the playground root:

```bash
godot --path careen                         # in the editor's runtime
./careen/build/linux/careen.x86_64          # the exported Linux build
```

In a browser: https://phlawlessdevelopment.github.io/abstract-strategy-playground/games/careen/

Click an arrow (or press an **arrow key**) to tilt, then click an empty cell to drop. Hover an arrow to preview a tilt, hover a cell to see what each of the opponent's tilts would do to a stone there. **R** new game, **U** undo, **H** hints, **F1** rules. Play against the computer (Easy, Medium, Hard) as either colour, or two players on one screen.

## Code

| File | What it does |
| --- | --- |
| `scripts/rules.gd` | Pure game logic: sliding, crushing, turn phases, undo, scoring. No nodes. |
| `scripts/ai.gd` | The computer: alpha-beta search over whole turns (a tilt plus a drop). |
| `scripts/board_view.gd` | Draws the tray, arrows and previews; plays the slide, crush and drop animations. |
| `scripts/main.gd` | Window layout, controls, turn flow and hover forecasts. |
| `tools/test_rules.gd` | Hand-worked rule tests: sliding, crushing, chains, game flow, undo. |
| `tools/ui_flow.gd` | Drives the real scene through whole games, undo and restarts, and checks the display matches the rules. |
| `tools/selfplay.gd`, `trace.gd`, `time_ai.gd` | The balance and speed experiments quoted in the design notes. |
| `tools/screenshot.gd` | Renders the scene to PNGs (needs a display). |

Run the checks:

```bash
godot --headless --path careen -s tools/test_rules.gd
godot --headless --path careen -s tools/ui_flow.gd
godot --headless --path careen -s tools/selfplay.gd -- games=50 a=2 b=2
```

Sprites are from the shared [asset pack](../_assets/) (a disc, a diamond, rings, an octagon and chevrons), tinted in code.
