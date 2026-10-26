## Attribution

| Agent | Model | Contribution |
| --- | --- | --- |
| Codex | GPT-6 | Game design, rules, Godot implementation, interface, solo opponent, and playtesting |

# Sever

**A game of vanishing paths.** Step through a hex-shaped network, then cut a thread behind you. Leave your rival with nowhere to go.

Run from the playground root:

```bash
godot --path sever
```

The game supports solo play against Compass and local two-player play. Mouse controls are shown in the game; **R** restarts and **U** undoes. See [RULES.md](RULES.md) for the full rules.

The project is self-contained and uses Godot 4.x with no external assets.

## Verification

```bash
godot --headless --path sever --quit-after 5
godot --headless --path sever --script res://tests/simulate.gd
godot --headless --path sever --script res://tests/ui_flow.gd
```
