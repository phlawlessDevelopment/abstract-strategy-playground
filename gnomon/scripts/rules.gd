extends RefCounted
## Pure rules for Gnomon. No rendering, no input, no nodes — just state.
##
## The board is N x N. Cells are indexed idx = y * N + x, y = 0 is the top row.
## A stone is 1 (Amber) or 2 (Teal). The sun sits in one of 8 directions;
## `sun` indexes DX/DY and gives the direction *toward* the sun.
##
## Shadow rule: a stone's shadow falls `shadow_len` cells directly away from
## the sun. A stone standing in an enemy shadow is eclipsed (removed). That is
## the same as: a stone is eclipsed if an enemy stone stands within
## `shadow_len` cells of it, in a straight line, toward the sun.

const N := 7
const DX := [0, 1, 1, 1, 0, -1, -1, -1]
const DY := [-1, -1, 0, 1, 1, 1, 0, -1]
const SUN_NAMES := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

# Result codes for `winner`.
const ONGOING := 0
const P1 := 1
const P2 := 2
const DRAW := 3

# --- tunables (set before reset()) ---
var shadow_len := 2
var day_len := 8          # rounds per full circuit of the sun
var rings_per_day := 1    # how many outer rings go dark at each dusk
var max_ring := 3         # the dusk that would darken this many rings ends the game instead
var start_sun := 0        # N: Teal begins uphill, Amber has the first move
var start_rows := 1       # 1: stones on the 2nd row from each edge, 0: on the edge
var snake := false        # experiment: alternate who opens each round (A B | B A | A B ...)
var mover_captures := true  # true: shadows only take stones on their owner's move

# --- state ---
var board := PackedInt32Array()
var sun := 0
var ring := 0             # number of outer rings that are dark
var turn := 1             # player to move
var round_no := 0         # completed rounds (each = one move by each player)
var second_half := false  # true when the player to move is the 2nd mover of the round
var winner := 0
var counts := [0, 0, 0]   # index by player
var last_removed := 0     # stones removed by the most recent apply()


func _init() -> void:
	board.resize(N * N)
	reset()


func reset() -> void:
	board.fill(0)
	sun = start_sun
	ring = 0
	turn = 1
	round_no = 0
	second_half = false
	winner = ONGOING
	last_removed = 0
	counts = [0, 0, 0]
	# Five stones each, mirrored through the centre so neither side is favoured
	# by the starting layout.
	var row := N - 1 - start_rows
	for x in [1, 2, 3, 4, 5]:
		_put(x, row, P1)
		_put(N - 1 - x, N - 1 - row, P2)


func _put(x: int, y: int, p: int) -> void:
	board[y * N + x] = p
	counts[p] += 1


func clone():
	var c = get_script().new()
	c.shadow_len = shadow_len
	c.day_len = day_len
	c.rings_per_day = rings_per_day
	c.max_ring = max_ring
	c.start_sun = start_sun
	c.start_rows = start_rows
	c.snake = snake
	c.mover_captures = mover_captures
	c.second_half = second_half
	c.board = board.duplicate()
	c.sun = sun
	c.ring = ring
	c.turn = turn
	c.round_no = round_no
	c.winner = winner
	c.counts = counts.duplicate()
	return c


# ---------------------------------------------------------------- geometry

static func xy_to_idx(x: int, y: int) -> int:
	return y * N + x


static func idx_x(i: int) -> int:
	return i % N


static func idx_y(i: int) -> int:
	return i / N


## True if the cell is on the board and not yet swallowed by night.
func playable(x: int, y: int) -> bool:
	return x >= ring and y >= ring and x < N - ring and y < N - ring


func other(p: int) -> int:
	return 3 - p


# ---------------------------------------------------------------- moves

## Every legal move for the player to move, encoded as from * 64 + to.
## If the player has no stone that can step, the only move is PASS (-1).
func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	if winner != ONGOING:
		return out
	for i in N * N:
		if board[i] != turn:
			continue
		var x := i % N
		var y := i / N
		for d in 8:
			var nx: int = x + DX[d]
			var ny: int = y + DY[d]
			if playable(nx, ny) and board[ny * N + nx] == 0:
				out.append(i * 64 + ny * N + nx)
	if out.is_empty():
		out.append(-1)
	return out


## Destinations for one stone (used by the UI to highlight).
func moves_for(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if winner != ONGOING or board[i] != turn:
		return out
	var x := i % N
	var y := i / N
	for d in 8:
		var nx: int = x + DX[d]
		var ny: int = y + DY[d]
		if playable(nx, ny) and board[ny * N + nx] == 0:
			out.append(ny * N + nx)
	return out


# ---------------------------------------------------------------- eclipses

## Indices of every stone that is currently eclipsed (in an enemy shadow).
func eclipsed_cells() -> PackedInt32Array:
	var out := PackedInt32Array()
	var dx: int = DX[sun]
	var dy: int = DY[sun]
	for i in N * N:
		var p := board[i]
		if p == 0:
			continue
		var x := i % N
		var y := i / N
		for k in range(1, shadow_len + 1):
			var nx := x + dx * k
			var ny := y + dy * k
			if nx < 0 or ny < 0 or nx >= N or ny >= N:
				break
			var q := board[ny * N + nx]
			if q != 0 and q != p:
				out.append(i)
				break
	return out


## Same test, for an arbitrary sun direction (used for "next round" previews).
func eclipsed_cells_for_sun(s: int) -> PackedInt32Array:
	var saved := sun
	sun = s
	var out := eclipsed_cells()
	sun = saved
	return out


# ---------------------------------------------------------------- apply

## Play one move. `events`, if given, receives dictionaries describing what
## happened so the UI can animate it. Returns nothing; read `winner` etc.
func apply(move: int, events = null) -> void:
	if winner != ONGOING:
		return
	last_removed = 0
	if move >= 0:
		var from := move / 64
		var to := move % 64
		board[to] = board[from]
		board[from] = 0
		if events != null:
			events.append({"type": "move", "from": from, "to": to, "player": turn})
	elif events != null:
		events.append({"type": "pass", "player": turn})

	_resolve(events, turn)

	if winner != ONGOING:
		turn = other(turn)
		return

	if not second_half:
		# First mover of the round is done; the other player replies.
		second_half = true
		turn = other(turn)
		return

	# Both players have moved: the sun steps one notch clockwise.
	second_half = false
	round_no += 1
	sun = (sun + 1) % 8
	if events != null:
		events.append({"type": "sun", "sun": sun, "round": round_no})
	if not mover_captures:
		_resolve(events)
	if winner == ONGOING and round_no % day_len == 0:
		_dusk(events)
	# Next round's opener: with `snake`, the player who just moved second opens
	# again (so nobody is always the last to move before the sun turns).
	if not snake:
		turn = other(turn)


## Remove eclipsed stones. With `mover_captures`, only the player who has just
## moved collects: stones of the *other* colour that stand in the mover's
## shadows. (Your own stones in an enemy shadow are safe until that enemy moves.)
## `by` is the player whose move this is; pass 0 to remove everything eclipsed.
func _resolve(events, by: int = 0) -> void:
	var dead := eclipsed_cells()
	if by != 0 and mover_captures:
		var mine := PackedInt32Array()
		for i in dead:
			if board[i] != by:
				mine.append(i)
		dead = mine
	if dead.is_empty():
		return
	var info := []
	for i in dead:
		info.append({"idx": i, "player": board[i]})
		counts[board[i]] -= 1
		board[i] = 0
	last_removed += dead.size()
	if events != null:
		events.append({"type": "eclipse", "stones": info})
	_check_end()


func _dusk(events) -> void:
	if ring + rings_per_day >= max_ring:
		# The last dusk: night is total and the game is over. Whoever kept more
		# stones wins. (Nobody is deleted: the count is taken as the light dies.)
		if events != null:
			events.append({"type": "night"})
		if counts[P1] > counts[P2]:
			winner = P1
		elif counts[P2] > counts[P1]:
			winner = P2
		else:
			winner = DRAW
		return
	ring += rings_per_day
	var info := []
	for i in N * N:
		if board[i] != 0 and not playable(i % N, i / N):
			info.append({"idx": i, "player": board[i]})
			counts[board[i]] -= 1
			board[i] = 0
	last_removed += info.size()
	if events != null:
		events.append({"type": "dusk", "ring": ring, "stones": info})
	_check_end()


func _check_end() -> void:
	if counts[P1] == 0 and counts[P2] == 0:
		winner = DRAW
	elif counts[P1] == 0:
		winner = P2
	elif counts[P2] == 0:
		winner = P1
