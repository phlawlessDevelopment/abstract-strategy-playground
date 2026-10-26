# Sever

Two travelers begin on opposite sides of a network of 19 points. Amber goes first.

On your turn:

1. **Step** along an uncut thread to a neighboring empty point. Lit points show your legal steps.
2. **Cut** one of the threads touching the point you just left. You may cut the thread you crossed. Lit threads show your choices; click one to cut it.

The cuts are permanent. If your opponent has no legal step when their turn begins, you win.

The default mode is solo against Compass. The mode button switches to local two-player play and starts a fresh game. Click **New Game** or press **R** to restart. Click **Undo** or press **U** to take back a turn. In solo mode, Undo takes back your turn and Compass's reply together.

## Design notes

I wanted a move to make the map smaller while leaving a choice about *which* route disappears. Cutting the path you just used is safe; cutting a different one can set a trap but may leave the old point useful later. I'm unsure whether Compass's two-turn lookahead feels too defensive, and whether a larger network would create more interesting late games without overstaying its welcome.
