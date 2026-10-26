class_name WWRules
extends RefCounted
## Warp & Weft: pure game logic. No nodes, no drawing, no input.
##
## A square grid of numbers and ONE shared shuttle. Weft may only slide the
## shuttle along its row; Warp may only slide it along its column. The cell you
## land on is scored and then used up. The game ends when the player to move has
## no cell left on their line.

const WEFT := 0  # moves sideways (along rows); moves first
const WARP := 1  # moves up/down (along columns)

# Pool of values dealt onto the mirrored half of the board (diagonal included).
# 21 mirrored pairs + 6 diagonal cells = 27 slots; the centre cell is the start.
const VALUE_POOL: Array[int] = [
	-3, -2, -2, -1, -1,
	1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 9,
]

## Weft moves first and the first pick from a shared pool is worth about 4-5 points
## (measured in self-play at the depths people actually think), so Warp is handed a
## half-point komi, which also rules out draws.
const DEFAULT_KOMI := 4.5

var n: int = 7
var cells: int = 49
var komi: float = DEFAULT_KOMI   # points handed to Warp at the final count

var values: PackedInt32Array = PackedInt32Array()
var mask: int = 0            # bit i set => cell i is used up (the shuttle's own cell is always set)
var shuttle: int = 0
var turn: int = WEFT
var score: Array[int] = [0, 0]
var history: Array = []      # one Dictionary per move, for undo and "what just happened"


func _init(p_values: PackedInt32Array = PackedInt32Array(), p_n: int = 7, p_komi: float = DEFAULT_KOMI) -> void:
	n = p_n
	cells = n * n
	komi = p_komi
	if p_values.is_empty():
		p_values = make_board(randi(), n)
	values = p_values
	reset()


func reset() -> void:
	shuttle = (n / 2) * n + n / 2
	mask = 1 << shuttle
	turn = WEFT
	score = [0, 0]
	history.clear()


## A board that is its own mirror image across the main diagonal, so the two
## players see exactly the same world (just turned 90 degrees).
static func make_board(seed_value: int, size: int = 7) -> PackedInt32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = VALUE_POOL.duplicate()
	# Fisher-Yates with our own rng so a seed always gives the same board.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var vals := PackedInt32Array()
	vals.resize(size * size)
	var centre := size / 2
	var k := 0
	for r in size:
		for c in range(r, size):
			var v := 0
			if not (r == centre and c == centre):
				v = pool[k % pool.size()]
				k += 1
			vals[r * size + c] = v
			vals[c * size + r] = v
	return vals


# --- lanes -----------------------------------------------------------------

## Cells the player `who` could land on, given a mask and shuttle position: every
## unused cell on their line. Used-up cells are simply hopped over.
## Static so the AI can search without building Rules objects.
static func lane(m: int, at: int, who: int, size: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if who == WEFT:
		var row := (at / size) * size
		for x in size:
			if not (m >> (row + x)) & 1:
				out.append(row + x)
	else:
		var col := at % size
		for y in size:
			if not (m >> (y * size + col)) & 1:
				out.append(y * size + col)
	return out


func moves() -> PackedInt32Array:
	return lane(mask, shuttle, turn, n)


## The line the *other* player would get if `who` landed on `cell` now.
func reply_lane(cell: int, who: int) -> PackedInt32Array:
	return lane(mask | (1 << cell), cell, 1 - who, n)


func is_over() -> bool:
	return moves().is_empty()


func is_legal(cell: int) -> bool:
	return cell in moves()


## Land the shuttle on `cell`. Returns false (and changes nothing) if illegal.
func play(cell: int) -> bool:
	if not is_legal(cell):
		return false
	var gain := values[cell]
	history.append({"from": shuttle, "to": cell, "who": turn, "gain": gain})
	score[turn] += gain
	mask |= 1 << cell
	shuttle = cell
	turn = 1 - turn
	return true


func undo() -> bool:
	if history.is_empty():
		return false
	var h: Dictionary = history.pop_back()
	score[h["who"]] -= h["gain"]
	mask &= ~(1 << h["to"])
	shuttle = h["from"]
	turn = h["who"]
	return true


## Weft's margin over Warp at the final count (komi included). > 0 means Weft is ahead.
func margin() -> float:
	return float(score[WEFT] - score[WARP]) - komi


## -1 while playing, otherwise WEFT, WARP, or 2 for a draw.
func winner() -> int:
	if not is_over():
		return -1
	var m := margin()
	if m > 0.0:
		return WEFT
	if m < 0.0:
		return WARP
	return 2


func cells_left() -> int:
	var used := 0
	for i in cells:
		if (mask >> i) & 1:
			used += 1
	return cells - used

