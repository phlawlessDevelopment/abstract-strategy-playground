# Careen

*Drop a stone, and your opponent decides which way the tray tilts.*

Imagine a flat square tray, six cells by six, with nothing on it. You and I each have eleven stones: **Amber** has circles, **Teal** has diamonds. Amber goes first.

## How to play

**Your turn is two things, in this order:**

1. **Tilt** the tray: north, east, south or west. Every stone on it slides as far as it can go that way. A stone stops when it meets a wall or another stone. Stones never jump over each other, so the order they sit in along a line never changes.
2. **Drop** one of your stones onto any empty cell.

That is the whole turn. (On the very first turn the tray is empty, so Amber only drops.)

**The twist is who tilts what.** Your dropped stone sits exactly where you put it, but *you don't tilt again*. Your opponent does, at the start of their turn, and they pick whichever direction suits them. So a stone is only as good as its worst future: before you drop, you are really asking "what happens to this if they go north? east? south? west?"

**Crushing.** When a tilt has finished sliding, look at every stone. If a stone has an **enemy stone directly on both sides of it**, either left and right or above and below, it is crushed and removed. Walls are not enemies, so a stone against a wall is safe on that line. A stone with a friend next to it on a line is also safe on that line.

All the crushes in one look happen at the same moment. Then everything slides again the same way (the gaps may have closed up), and you look again. Keep going until nothing more is crushed. A single tilt can set off a little avalanche. Stones of *both* colours can be crushed by the same tilt, including your own, so tilting is not free.

**Ending.** Teal drops the very last stone. Then Amber, who would have been next, makes one final tilt and the game is over. Now count. **The player who lost fewer stones wins.** Equal losses are a draw.

## What the screen shows

- The four arrows around the tray are the tilts. Hover one to see where every stone would end up (outlines) and which would be crushed (red crosses). With **Hints** on, each arrow also shows the net result for you: **+1** means a tilt crushes one more of their stones than yours.
- When you are about to drop, hover an empty cell. The arrows then show what each of *their* tilts would do to you if you dropped there, and the worst one is drawn on the tray.
- White corner brackets mark the stone dropped last. The cards show stones still in hand and stones lost.

## Controls

Mouse: click an arrow to tilt (or use the **arrow keys**), then click an empty cell to drop. **R** new game, **U** undo (back to the start of your turn), **H** hints on/off, **F1** rules. Play against the computer (Easy, Medium or Hard) as either colour, or two players on one screen.

## A few things worth knowing

- A stone alone in the middle of a row is a target. Two of your stones side by side are safe along that row, but a tilt can slide them into a different column where they are not.
- Every tilt is a decision too. Sometimes all four directions hurt you, and the best you can do is pick the one that hurts least and then drop a stone that makes *their* tilts worse.
- Stones are never added back. Every crush is permanent, so a lead of one stone late in the game is worth a lot.

---

## Design notes

**What I was going for.** I wanted a game where one move is shared between two people. The usual structure is "I move, you respond". Here the dropper commits to a stone and the *other* player chooses how the whole world shifts before it matters, a bit like "I cut, you choose". It gives two kinds of decision: where to drop (look at four futures at once) and which way to tilt (one of four, usually all with a catch). The physics is deliberately tiny: slide, then check for a stone caught between two enemies.

**What I measured** (computer vs computer on the 6 x 6 tray, 11 stones each; the numbers come from `tools/selfplay.gd`):

- *Thinking beats luck.* A player looking one whole turn ahead beat a random player in 99.6% of games. Two turns ahead beat one turn ahead 97%, and three beat two 83% to 4.5% (the rest were draws). That is where the Easy / Medium / Hard levels come from.
- *Stones per player decided how often games end in a draw.* Between two-turn-ahead players, 7 stones on a 5 x 5 tray gave 52% draws, 9 stones on 6 x 6 gave 32%, and 11 stones on 6 x 6 gave 17.5%. More stones on the tray means more crushes (about 9 per game at 11 stones) and fewer stalemates.
- *The first player is not favoured between careful players,* but is between shallow ones. At two turns ahead Amber took 53% of the decisive games, and at three turns ahead (112 games) exactly 50%, with 12.5% draws. At one turn ahead Amber won about 85% of them: the player who drops first always has one stone more on the tray when the other tilts, which matters if you cannot see your own next tilt coming. The more carefully both sides think, the less this matters.
- *Variants I tried and dropped.* Posts (fixed obstacles) in three symmetric layouts cut crushes to 3-5 per game and favoured Amber (57-66% of decisive games), so the tray is empty. A rule that forbids repeating the previous tilt direction did not reduce draws and made Amber's edge bigger (67%). Giving Teal a second final tilt reduced draws to 21% but handed Teal the last word (Amber took only 33% of decisive games), so only Amber gets the closing tilt.

**What I'm unsure about.**

- **Nobody but computers has played it yet.** I know the game does not collapse and that lookahead pays off. I do not yet know whether the first few quiet turns, when nothing can be crushed, feel like setup or like waiting.
- **Hints may do too much.** The numbers on the arrows are a one-turn lookahead handed to you for free. They are the best way to learn the game, but you may want to switch them off.
- **Is the drop-then-opponent-tilts structure clear enough?** It is simple once you have seen it, and a little strange the first time.
- **Draws are 12-17% between careful computers.** Humans will probably blunder more, but a rule that breaks ties might help.

**Ideas I'd try next.** A tray that is not square (the geometry decides which lines are safe). Crushing a *line* of two stones when both ends are enemies. A pie rule for the first drop. Letting the dropper place two stones on some turns. Larger trays with more stones, if the computer could search them quickly enough.
