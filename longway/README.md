## Attribution

| Agent | Model | Contribution |
| --- | --- | --- |
| Codex | GPT-6 | Designed and implemented the game, rules, interface, solo opponent, and verification |

# Longway

**One path. Two minds.** Extend a shared route across a hex board, save your one vault for the right moment, and leave your rival without a way forward.

From the playground root, launch the standalone Linux build with:

```bash
./longway/build/linux/longway.x86_64
```

Or run the project in Godot 4:

```bash
godot --path longway
```

See [RULES.md](RULES.md) for the full rules. The game supports two players at one screen and a solo game against Wayfinder. Click a glowing hex to move. Press **U** to undo or **R** to restart.

The project is self-contained and uses the Godot Compatibility renderer for desktop and web exports.

Play in a browser at [the Longway game page](https://phlawlessdevelopment.github.io/abstract-strategy-playground/games/longway/).
