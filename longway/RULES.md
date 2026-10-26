# Longway

Two players take turns extending one shared path across 19 hexes. Amber goes first. The white marker is the path's head.

On your turn, click an empty hex next to the head. That hex becomes the new head. Every visited hex stays blocked for the rest of the game.

**Once per game**, you may vault: jump over one visited hex beside the head and land on the empty hex immediately beyond it. A ring around a legal destination shows that this move uses your vault. Each player has their own vault.

If you start your turn with nowhere to step or vault, you lose. The player who made the last move wins. There are no draws.

The right panel shows whose turn it is and which vaults remain. Play against a friend on one screen or switch to Wayfinder for a solo game. **U** undoes the last turn (both players' moves in solo mode); **R** starts a new game.

## Design notes

I wanted a tiny board where both players shape the same route, and where a single saved vault can overturn a tempting trap. I am most unsure whether the vault is too valuable near the edge; I would try a larger board if careful games end too quickly.
