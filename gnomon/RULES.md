# Gnomon

*Stand uphill. Cast the shadow.*

A two-player abstract game about light. A sun circles the board, every stone casts a shadow, and a stone caught in an enemy's shadow is gone. Games take 5–10 minutes.

```
godot --path gnomon          # from the playground folder
```

Click a stone, then a highlighted cell. **R** new game · **U** undo · **H** hints on/off · **S** show tomorrow's shadows · **F1** rules · right-click or **Esc** to deselect. Play against the computer (four levels) or two players on one screen.

---

## How to play

Imagine we're sitting at a 7×7 board. Amber has five round stones along the bottom, Teal has five diamond stones along the top. Around the board is a dial with a sun on it. Amber moves first.

**Shadows.** Every stone casts a shadow *straight away from the sun*, two cells long. If the sun is in the north, shadows point south; if it's in the north-east, they point south-west. Shadows run in a straight line, orthogonal or diagonal, and they don't stop at stones.

**Eclipse.** After you move, every *enemy* stone standing in one of *your* shadows is eclipsed and removed. Your own shadows never hurt you, and an enemy's shadow only hurts you after *they* move. So "standing in a shadow" is a threat, not a death: you get a turn to react. Put it another way: whoever is **uphill** (nearer the sun, in line, within two cells) wins that standoff.

**Your turn.** Move one of your stones one step, in any of the 8 directions, onto an empty cell. You must move; you can't pass unless you truly can't.

**The sun turns.** After each round (one move by Amber, one by Teal) the sun moves one notch clockwise, 45°. The standoffs rotate with it: two stones that are safe now may be a death sentence in two rounds, and the other way round. A pair of enemy stones in line within two cells is a ticking clock; the sun's position decides who dies when it arrives, and you can see it coming.

**Dusk.** One full circuit of the sun is a day, 8 rounds. At the end of each day the outermost ring of cells goes dark and any stone on it is lost. The board shrinks 7×7 → 5×5 → 3×3. When the third dusk falls, the game ends.

**Winning.** Eclipse every enemy stone and you win. If the last dusk falls first, whoever has more stones wins; equal is a draw. (Both sides losing their last stones to the same dusk is also a draw.)

### Reading the board

- **Tinted streaks** are shadows, coloured by their owner. Don't step into the other colour's.
- A stone under a **dark veil with a red ring and "!"** is yours and in an enemy shadow: move it, or break the threat, before they move.
- A stone with a **gold ring and "×"** is theirs and in your shadow: almost any move that leaves your shadow in place takes it.
- A **dashed ring** marks a stone that will be in shadow once the sun turns, if nothing changes.
- The **hollow ring on the dial** is where the sun goes next.
- Pick a stone and the destination dots tell you what the move does: gold = takes a stone and leaves nothing of yours exposed, orange = takes one but exposes you, red = leaves you exposed for nothing, white = quiet. Hover a dot for the details.
- The **red-tinted ring** of cells pulses as dusk approaches.

### A few things worth knowing

- Stones a knight's move apart (like b2 and c4) are never in line, so they never threaten each other, whatever the sun does.
- The sun starts in the **north**, so Teal begins uphill; Amber has the first move to make up for it. Around round 4 the sun passes south and the advantage swings to Amber. Fights are about the *timing* of that swing.
- Because the sun is on a fixed schedule, you can always see what the next few rounds will do. Most mistakes are forgetting the sun is about to move.
- Dusk is a second clock. Five stones on the edge need five moves to step inward; you only get one move per round.

---

## Design notes

**What I was going for.** A game where *the rules themselves have weather*: one shared, perfectly predictable global state (the sun) that every local fight depends on, so the question is never just "can I take that stone?" but "when, and who will be uphill by then?" I wanted decisions that need you to hold a rotating picture in your head, with the rotation public and deterministic so it's a puzzle rather than a gamble, and a shrinking board so nobody can hide.

**What I tried and threw out**, with the numbers from AI-vs-AI games. The AI is a plain alpha-beta search, and all of this is reproducible with the tools below.

- *Eclipses resolve instantly for both colours after every move.* Hard to read (danger only shows when you blunder) and unbalanced: with ordinary alternating turns Teal, who always moves last before the sun turns, won 196 of 240 depth-3 games (82%) across the eight start directions.
- *Snake turn order* (A B | B A | A B, so the sun-turner moves again). Looked like the principled fix, but it made the result swing wildly with the sun's start direction: at depth 2, Amber won 59–1 from one start and lost 3–57 from another.
- *Shadows only take stones on their owner's move* + *sun starts in the north* was the combination that worked: depth 3 vs depth 3 gave **52–48** over 100 games. Search depth matters far more than side: depth 3 beat depth 2 by 79–19 as Amber and 96–4 as Teal, and depth 4 beat depth 3 by 14–2 and 15–1 (only 16 games each way). That's the "skill beats luck" property I wanted.
- Average game: about 24 plies (12 rounds), so most games end during the second day; dusk matters a lot to anyone who hides.

**What I'm unsure about.**

- *Is it fun for a person, not a search algorithm?* The AIs are ruthless about tempo; a human might find the rotation hard to hold in their head. The overlays try to carry that, but I haven't watched a newcomer play.
- *Shadow length 2 and 5 stones* were chosen by feel. I only compared shadow lengths 1–3 under the earlier, instant-eclipse rules (length 1 was lopsided toward Teal, length 3 made games a few plies shorter), never under the final rules. 5 stones means each loss hurts; 6–7 on a bigger board might give more room for strategy.
- *Fixed start direction.* It balances the AI games, but starting angle is a real lever (north: 52–48; south-west: Teal won 39 of 40). A pie rule, where Amber picks the starting sun and Teal picks a side, could be more elegant, but it asks a newcomer to judge something they can't yet evaluate.
- *Endgames with one stone each* become cat-and-mouse. That felt good, but long ones could stall until dusk.

**Ideas I'd try next.** Let players choose the starting sun (pie rule). A second, slower "moon" casting shadows the other way. Stones of different shadow lengths. Hex board with a 6-position sun. A move that lets you spend a stone to hold the sun for a round.

---

## For tinkerers

```
godot --headless --path gnomon -s tools/test_rules.gd                    # rules unit tests (7000+ checks)
godot --headless --path gnomon -s tools/selfplay.gd -- games=100 p1=3 p2=3   # AI vs AI statistics
godot --headless --path gnomon -s tools/transcript.gd -- depth=3 seed=1  # one game, move by move
godot --path gnomon -- --autoplay    # watch the computer play both sides in the real UI
```

`selfplay` options: `p1`/`p2` search depth (0 = random), `len` shadow length, `day` rounds per day, `sun` start direction 0–7 (N, NE, E, SE, S, SW, W, NW), `snake=1`, `mover=0` (instant-eclipse rule). Game logic lives in `scripts/rules.gd` with no rendering; `scripts/ai.gd` is the search; `scripts/view.gd` draws; `scripts/main.gd` runs the game.
