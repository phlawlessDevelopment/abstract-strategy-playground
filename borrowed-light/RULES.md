# Borrowed Light

Move a shared lantern. Leave your color behind. Only stones that catch the light count.

## Take a turn

Ember plays circles, Jade plays diamonds. Ember goes first. The three golden lanterns belong to both players.

1. Click **any lantern** that can move. Its legal destinations light up.
2. Slide it any distance along one of the board's **six straight directions**. Click a highlighted space to land there.
3. Leave a stone of your color in the space the lantern **started from**.

You cannot jump over a stone or another lantern. You can move a lantern your opponent just moved. Stones stay where they are for the rest of the game.

Hover over a destination before clicking to see the resulting light and score changes. Click another lantern to switch; right-click or Escape cancels your selection.

## Follow the light

Every lantern shines along all six straight directions. The **first stone** in each direction catches the light and is worth **one point** to its owner. That stone blocks the light from reaching anything behind it. Another lantern also blocks a ray.

A stone lit by two or three lanterns still counts **only once**. Bright stones with a ring are scoring; dim stones are in shadow and score nothing. The numbers on the right show the current score, which can change as lanterns move.

For example, if a lantern sees **Ember, then Jade** along one line, Ember scores one and Jade scores zero on that line. Jade might still catch light from a different lantern.

## End the game

When **all three lanterns are trapped**, the game ends immediately. The player with the most lit stones wins. Equal scores are a draw. One trapped lantern does not end the game while another can move.

Every move leaves one permanent stone, so there are at most 34 moves. There is no passing, capture, or repetition.

## Play at one machine

The mode menu offers a computer opponent with either player moving first, or **Two players** for taking turns on the same screen. Changing the mode starts a fresh game.

- **New game / R:** restart; an unfinished game asks for confirmation.
- **Undo / U:** undo one move in two-player mode, or return to your last decision in solo mode. You can undo the ending too.
- **Hint / H:** preview a suggested legal move. Click its destination or press Enter to play it.
- **1, 2, 3:** select a lantern. **Arrow keys** cycle its destinations; **Enter** moves; **Escape** cancels. On a controller, **LB/RB** select lanterns, **D-pad** cycles destinations, **A** confirms, and **B** cancels.
- **Show light rays:** hide or show the beams. Scoring rings always remain visible.

## A thought to start with

Following your opponent's lantern can put your stone in front of theirs. But moving a different lantern may bring their hidden stone back into the light. Watch all three lanterns, and think about which spaces will stay reachable after your move.

## Design notes

I wanted an ownership game where the pieces you move are shared, and your permanent pieces matter through visibility rather than territory. The score is a picture of the current lighting, not points already banked. Closing a corridor can protect a lead or strand your own stones in darkness.

The open question is whether following the most recently moved lantern becomes too reliable with expert play. I would most like feedback on whether relighting old stones gives enough reason to switch lanterns. The computer is a bounded search opponent, not a solved-game oracle.

In 400 seeded random games, Ember won 181, Jade won 146, and 73 were draws. Games averaged 25.29 moves, ranging from 10 to 33. That is a useful smoke test for endings and obvious imbalance, not a proof of balance.
