# Warp & Weft

*One shuttle, two directions.*

Imagine a loom. The **warp** threads run up and down; the **weft** threads run side to side. In this game there is a single shuttle on a grid of numbers, and the two of you share it: one player may only push it **sideways** (Weft, red), the other only **up and down** (Warp, blue).

## How to play

**Setup.** A 7 × 7 grid of numbers, mostly positive, a few negative. The shuttle sits on the middle cell. The grid is a mirror image of itself across the diagonal (the cell in row 2, column 5 equals the cell in row 5, column 2), so the two players see exactly the same world, turned on its side.

**Your turn.**

1. Look at the line the shuttle is on. If you are **Weft**, that's its *row*; if you are **Warp**, its *column*.
2. Slide the shuttle to **any unused cell on that line**. You may hop over cells that are already used.
3. You **score the number** on the cell where you land. That cell is now used up.

That's the whole move. The twist is what it does to your opponent: **the cell you land on decides the only line they get to choose from.** Land on a 9 and you're delighted, until you notice your opponent now has a column with an 8 in it.

**The end.** The game ends the moment the player to move has **no unused cell on their line**. Highest total wins. Cells still left on the board are worth nothing to anyone, so stranding your opponent while you're ahead is a way to win early, and avoiding being stranded while you're behind is part of the fight.

**Komi.** Weft moves first, and picking first from a shared pool is worth around four or five points. So **Warp starts with 4.5 points** already on the scoreboard. The half point means there are no draws.

## What the screen shows

- Cells lit in your colour (with threads running your way) are your legal moves.
- **Hover** a lit cell to preview the line you'd hand your opponent. With **Hints** on, their best reply is ringed, and the side panel tells you the net result (your gain minus their best reply). If landing there would strand them, it says so, and says who would win.
- Used cells keep the colour of whoever took them and show what was taken, so the finished board reads as a record of the game.

## Controls

Mouse: click a lit cell. **R** new game · **S** same board again · **U** undo · **H** hints on/off · **F1** rules · **Esc** close rules. Play against the computer (Easy, Medium, Hard) as either side, or two players on one screen.

## A few things worth knowing

- Taking the biggest number is usually a trap. Look at the line it hands over.
- A **negative number** is sometimes the right move, if every other cell on your line gives your opponent something better.
- As rows and columns fill up, count the unused cells on your opponent's line *before* you land. The end arrives sooner than it feels like it should.

---

## Design notes

**What I was going for.** One idea, followed all the way down: *a single piece that both players control, each along a different axis.* Everything else is there to make that idea readable. Each move is two decisions at once, what you gain and what menu you leave behind, and that's where the "can't tell which of these two is better" moments are meant to come from. The loom theme isn't decoration for its own sake: warp and weft really are the two perpendicular directions, and the used-up cells end up woven in both.

**What I measured** (computer vs computer, 7 × 7, boards generated at random; the numbers are from this project's `tools/`):

- *First move is strong.* With no komi, Weft won 64–86% of games between equal-strength players. Both seats make about the same number of moves, so it isn't tempo; it's simply getting the first pick from a shared pool. With a 4.5 komi, Weft's win rate between equal players was 46%, 55%, 53% and 50% at search depths 1, 2, 4 and 6 (300 games each).
- *Thinking pays.* Looking two moves ahead beat greedy play 80% of the time; four beat two 63%; the Hard level (searching about ten plies, exactly in the endgame) beat the four-ply player in 81% of 80 games. So the game rewards lookahead rather than luck of the board, at least up to the depths I tested.
- *A variant I threw away.* I tried letting used-up cells *block* a slide instead of being hopped over. Games shrank to about ten moves and deeper search stopped helping, so the hop rule stayed.
- *A bug worth admitting.* My first search had a pruning mistake that made deeper search *lose* to shallower search. That looked like "the game has no depth", and it was wrong; the fix is checked against a brute-force search in `tools/test_rules.gd`.

**What I'm unsure about.**

- **Nobody has played this but computers.** All the evidence above is self-play. I can tell you the game doesn't collapse into a first-player win or a coin-flip; I can't yet tell you it's *fun*.
- **Komi 4.5 is tuned to how people play, not to perfect play.** The first-move edge shrinks as players get stronger (about +5.2 points at two-ply, +4.4 at four, +3.6 at six), so very strong players may find Warp slightly favoured.
- **The ending.** A game usually stops with about 20 of the 48 cells still unused. That's the intended "ending is a weapon" idea, but it might feel abrupt, or like the board is being wasted.
- **Hints may do too much of the thinking.** With them on, a human sees the two-ply consequence of every move for free. They can be switched off, but I don't know what the right default is.
- **Numbers on a grid** might not be the most tactile way to feel "one piece, two owners".

**Ideas I'd try next.** Replace komi with a pie rule (after Weft's first move, Warp may swap seats). Larger boards, or boards that aren't mirror-symmetric, to see whether the balance holds. A shuttle that is allowed to *pass* once. Cells that change value when they're passed over. Showing a "how many unused cells are on each line" gauge to make stranding easier to see coming.
