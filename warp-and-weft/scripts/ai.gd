class_name WWAI
extends RefCounted
## Computer opponent. Searches on bare (mask, shuttle, turn) state, never on Rules
## objects, so it is fast and cannot disturb the live game.
##
## The search value is "future points for the player to move minus future points
## for the other player". Margin is additive, so no running score is needed.
## Only even depths are used for decisions: an odd-depth search ends on its own
## move and over-values it.

enum Level { EASY, MEDIUM, HARD }

const HARD_NODE_BUDGET := 80000    # keeps a move around a third of a second natively, well under a second in a browser
const HARD_MAX_DEPTH := 14

var rng := RandomNumberGenerator.new()
var nodes: int = 0
var node_limit: int = 0     # 0 = unlimited
var depth_reached: int = 0  # what the last Hard search completed (shown in the UI / tests)

var _stop: bool = false
var _values: PackedInt32Array
var _n: int


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Pick a move for whoever is to move in `r`.
func choose(r: WWRules, level: int) -> int:
	var mv := r.moves()
	match level:
		Level.EASY:
			# Greedy: grab the biggest number, with the occasional slip.
			if rng.randf() < 0.25:
				return mv[rng.randi_range(0, mv.size() - 1)]
			return _pick_best(score_moves(r, 1))
		Level.MEDIUM:
			return _pick_best(score_moves(r, 2))
		_:
			return choose_deep(r, HARD_MAX_DEPTH, HARD_NODE_BUDGET)


## Iterative deepening under a node budget. Always completes depth 2; deeper
## iterations that run out of budget are thrown away. Exact once depth covers
## every cell that is left.
func choose_deep(r: WWRules, max_depth: int, budget: int) -> int:
	var best := score_moves(r, 2)
	nodes = 0
	node_limit = budget
	depth_reached = 2
	var d := 4
	while d <= max_depth and depth_reached < r.cells_left():
		var sc := _root_scores(r, d)
		if _stop:
			break
		best = sc
		depth_reached = d
		d += 2
	node_limit = 0
	_stop = false
	return _pick_best(best)


## Fixed-depth choice, used by tests and tuning. depth 0 = random legal move,
## depth 1 = greedy (largest cell on the line).
func choose_depth(r: WWRules, depth: int) -> int:
	var mv := r.moves()
	if depth <= 0:
		return mv[rng.randi_range(0, mv.size() - 1)]
	return _pick_best(score_moves(r, depth))


## Score every legal move to a fixed depth. Returns {cell: value}.
func score_moves(r: WWRules, depth: int) -> Dictionary:
	node_limit = 0
	_stop = false
	return _root_scores(r, depth)


func _root_scores(r: WWRules, depth: int) -> Dictionary:
	_values = r.values
	_n = r.n
	_stop = false
	var out := {}
	for cell in r.moves():
		var v: int = _values[cell]
		if depth > 1:
			v -= _search(r.mask | (1 << cell), cell, 1 - r.turn, depth - 1, -1000000, 1000000)
			if _stop:
				return {}
		out[cell] = v
	return out


## Sorted best-first by immediate gain (cheap move ordering).
func _ordered(m: int, at: int, who: int) -> PackedInt32Array:
	var mv := WWRules.lane(m, at, who, _n)
	if mv.size() < 2:
		return mv
	var arr: Array = Array(mv)
	arr.sort_custom(func(a, b): return _values[a] > _values[b])
	return PackedInt32Array(arr)


func _search(m: int, at: int, who: int, depth: int, alpha: int, beta: int) -> int:
	nodes += 1
	if node_limit > 0 and nodes > node_limit:
		_stop = true
		return 0
	var mv := _ordered(m, at, who)
	if mv.is_empty():
		return 0          # the player to move is stranded: the game is over
	if depth == 0:
		return 0
	var best := -1000000
	for cell in mv:
		# A move is worth (its gain) - (the opponent's best continuation). Because of the
		# gain term the child's window is shifted: v = g - c, so c lies in (g - beta, g - alpha).
		var g: int = _values[cell]
		var v: int = g - _search(m | (1 << cell), cell, 1 - who, depth - 1, g - beta, g - alpha)
		if _stop:
			return 0
		if v > best:
			best = v
			if best > alpha:
				alpha = best
				if alpha >= beta:
					break
	return best


func _pick_best(scores: Dictionary) -> int:
	var best := -1000000
	var ties: Array = []
	for cell in scores:
		if scores[cell] > best:
			best = scores[cell]
			ties = [cell]
		elif scores[cell] == best:
			ties.append(cell)
	return ties[rng.randi_range(0, ties.size() - 1)]
