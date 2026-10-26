extends RefCounted
## A small alpha-beta searcher for Gnomon. Because the rules engine already
## handles the sun's steps and dusk inside apply(), the search sees them for
## free: it will happily walk away from a stone that the sun is about to
## eclipse two rounds from now.

var depth := 3
var nodes := 0
var rng := RandomNumberGenerator.new()

const WIN := 100000.0


func _init(d: int = 3) -> void:
	depth = d
	rng.randomize()


## Pick a move for the player to move. Ties are broken at random so games vary.
func choose(state) -> int:
	nodes = 0
	var moves: PackedInt32Array = state.legal_moves()
	if moves.size() == 1:
		return moves[0]
	var order := Array(moves)
	order.shuffle()
	var best: int = order[0]
	var best_v := -INF
	var alpha := -INF
	for m in order:
		var c = state.clone()
		c.apply(m)
		var v := _after(state.turn, c, depth - 1, alpha, INF)
		if v > best_v:
			best_v = v
			best = m
		alpha = maxf(alpha, v)
	return best


## Value, for `mover`, of the child position `c`. With snake turn order the
## same player can move twice in a row (around the sun's step), so the usual
## "negate at every ply" negamax trick has to check whose turn it really is.
func _after(mover: int, c, d: int, alpha: float, beta: float) -> float:
	if c.turn == mover and c.winner == 0:
		return _search(c, d, alpha, beta)
	return -_search(c, d, -beta, -alpha)


func _search(s, d: int, alpha: float, beta: float) -> float:
	nodes += 1
	if s.winner != 0:
		if s.winner == 3:
			return 0.0
		return (WIN + d) if s.winner == s.turn else -(WIN + d)
	if d <= 0:
		return evaluate(s, s.turn)
	# Generate children once and try captures first: it makes alpha-beta prune
	# far more, which buys an extra ply of depth for the same time.
	var kids := []
	for m in s.legal_moves():
		var c = s.clone()
		c.apply(m)
		kids.append([c.last_removed + (1000 if c.winner == s.turn else 0), c])
	if d >= 2:
		kids.sort_custom(func(a, b): return a[0] > b[0])
	var best := -INF
	for k in kids:
		var v := _after(s.turn, k[1], d - 1, alpha, beta)
		if v > best:
			best = v
		alpha = maxf(alpha, v)
		if alpha >= beta:
			break
	return best


## Static evaluation from `me`'s point of view.
func evaluate(s, me: int) -> float:
	var foe: int = 3 - me
	var e: float = (s.counts[me] - s.counts[foe]) * 100.0
	# Pending eclipses. `me` is the player to move: enemy stones already standing
	# in my shadows are as good as mine to take; mine in theirs are in danger.
	if s.mover_captures and me == s.turn:
		var shaded: PackedInt32Array = s.eclipsed_cells()
		for i in shaded:
			if s.board[i] == foe:
				e += 85.0
			else:
				e -= 45.0
	var n: int = s.N
	var c: float = (n - 1) / 2.0
	# Tempo accounting for dusk: every stone on the outermost live ring needs one
	# move to step inward. Each side gets roughly one move per round.
	var rounds_to_dusk: int = s.day_len - (s.round_no % s.day_len)
	var final_dusk: bool = s.ring + s.rings_per_day >= s.max_ring
	var need := [0, 0, 0]
	for i in n * n:
		var p: int = s.board[i]
		if p == 0:
			continue
		var x: int = i % n
		var y: int = i / n
		var edge: int = mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
		var sgn: float = 1.0 if p == me else -1.0
		if edge == s.ring and not final_dusk:
			need[p] += 1
			e -= sgn * 4.0
		e += sgn * (3.0 - maxf(absf(x - c), absf(y - c)))
	if not final_dusk:
		e -= 100.0 * maxi(0, need[me] - rounds_to_dusk)
		e += 100.0 * maxi(0, need[foe] - rounds_to_dusk)
	return e
