# Crosscurrent

Two players share a 5 × 5 board. Coral goes first; teal goes second. Each player has ten stones.

On your turn:

1. Click any empty square to place a stone.
2. Choose one of the four arrows beside that square's row or column. The whole row or column shifts one square in that direction. Stones and empty spaces wrap around the edge.

You can change your chosen square before clicking an arrow. Hover over an arrow to preview the result.

After 20 turns, each orthogonally connected group of your stones scores its size squared. Diagonals do not connect. For example, groups of four and two stones score 16 + 4 = 20. The higher score wins; equal scores draw. Press **R** or click **New game** to restart.

## Design notes

I wanted every placement to double as a small change to the board's geography: moving an empty space can join your group or split the other player's. I'm unsure whether scoring large groups makes the last few turns too swingy, and whether ten stones each is the best length. I'd try a shorter eight-stone game or a second board shape after more playtests.
