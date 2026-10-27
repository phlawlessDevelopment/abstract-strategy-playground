class_name CarAI
extends RefCounted
## Computer opponent: negamax with alpha-beta over whole turns (a tilt followed by a drop).
##
## Value = stones the opponent will lose minus stones the mover will lose, from the
## mover's side, counted from the position being searched. Searching on bare boards
## (never on CarRules objects) keeps it fast and means it cannot disturb the live game.
##
## At the horizon a position is scored by the opponent's best immediate tilt, because that
## is what threatens the stone that was just dropped.

var rng := RandomNumberGenerator.new()
var nodes: int = 0
var node_limit: int = 0       # 0 = unlimited; checked between root candidates only

var _w: int = 6
var _h: int = 6
var _final: int = 1           # final tilts after the last drop (see CarRules)
var _no_repeat: bool = false  # a tilt may not repeat the previous tilt's direction


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## The distinct things a tilt can do from board b for player `me`: [[swing, board, dir], ...],
## best swing first. Tilts that leave the board identical to an earlier tilt are dropped.
func _tilt_options(b: PackedByteArray, me: int, banned: int) -> Array:
	var opts := []
	for d in 4:
		if d == banned:
			continue
		var nb := b.duplicate()
		var l: Array = [0, 0]
		CarRules.settle(nb, _w, _h, d, l)
		var dup := false
		if not _no_repeat:          # with a ban, equal boards still differ in what the next tilt may be
			for o in opts:
				if o[1] == nb:
					dup = true
					break
		if dup:
			continue
		var entry := [l[1 - me] - l[me], nb, d]
		var at := opts.size()
		while at > 0 and opts[at - 1][0] < entry[0]:
			at -= 1
		opts.insert(at, entry)
	return opts


## Empty cells, those touching a stone first (they are where tactics happen).
func _drop_order(b: PackedByteArray) -> PackedInt32Array:
	var near := PackedInt32Array()
	var far := PackedInt32Array()
	for i in _w * _h:
		if b[i] != CarRules.EMPTY:
			continue
		var x := i % _w
		var y := i / _w
		var touching := (x > 0 and b[i - 1] != 0) or (x < _w - 1 and b[i + 1] != 0) \
				or (y > 0 and b[i - _w] != 0) or (y < _h - 1 and b[i + _w] != 0)
		if touching:
			near.append(i)
		else:
			far.append(i)
	near.append_array(far)
	return near


## Best swing among the four tilts for `me`, stopping early once it reaches `cap`.
## Cheaper than _tilt_options: no deduplication, no sorting, no boards kept.
func _best_swing(b: PackedByteArray, me: int, cap: int, banned: int) -> int:
	var best := -1000
	var l: Array = [0, 0]
	for d in 4:
		if d == banned:
			continue
		var nb := b.duplicate()
		l[0] = 0
		l[1] = 0
		CarRules.settle(nb, _w, _h, d, l)
		var v: int = l[1 - me] - l[me]
		if v > best:
			best = v
			if best >= cap:
				break
	return best


## Value of the closing tilts for `me`, `left` of them still to be made (alternating).
func _finale_value(b: PackedByteArray, me: int, left: int, banned: int) -> int:
	if left == 0:
		return 0
	var best := -1000
	for o in _tilt_options(b, me, banned):
		var v: int = o[0] - _finale_value(o[1], 1 - me, left - 1, o[2] if _no_repeat else -1)
		best = maxi(best, v)
	return best


## Value for `me` to act on board b, with `rm` stones in hand and `ro` in the opponent's.
func _search(b: PackedByteArray, me: int, rm: int, ro: int, depth: int, alpha: int, beta: int, banned: int) -> int:
	nodes += 1
	if rm == 0:
		return _finale_value(b, me, _final, banned)
	if depth == 0:
		return _best_swing(b, me, beta, banned)   # horizon: how hard can the best tilt hit?
	var opts := _tilt_options(b, me, banned)
	var best := -1000
	for o in opts:
		var base: int = o[0]
		var nb: PackedByteArray = o[1]
		for c in _drop_order(nb):
			nb[c] = me + 1
			var v := base - _search(nb, 1 - me, ro, rm - 1, depth - 1, base - beta, base - alpha, o[2] if _no_repeat else -1)
			nb[c] = CarRules.EMPTY
			if v > best:
				best = v
				if best > alpha:
					alpha = best
					if alpha >= beta:
						return best
	return best


## Choose {tilt, cell, value} for the player to move in r. `depth` counts own turns searched
## (0 = random tilt and drop). Picks at random among equally good moves.
func choose(r: CarRules, depth: int) -> Dictionary:
	_w = r.w
	_h = r.h
	_final = r.final_tilts
	_no_repeat = r.no_repeat
	var banned: int = r.last_dir if r.no_repeat else -1
	var me := r.turn
	var rm: int = r.reserve[me]
	var ro: int = r.reserve[1 - me]
	if r.phase == CarRules.Phase.DROP:
		var empties := r.empty_cells()   # opening drop on an empty tray
		return {"tilt": -1, "cell": empties[rng.randi_range(0, empties.size() - 1)], "value": 0}
	if depth <= 0:
		var d: int = rng.randi_range(0, 3)
		while not r.dir_ok(d):
			d = rng.randi_range(0, 3)
		var nb := r.cells.duplicate()
		var l: Array = [0, 0]
		CarRules.settle(nb, _w, _h, d, l)
		var pool := PackedInt32Array()
		for i in _w * _h:
			if nb[i] == CarRules.EMPTY:
				pool.append(i)
		return {"tilt": d, "cell": pool[rng.randi_range(0, pool.size() - 1)] if rm > 0 and not pool.is_empty() else -1, "value": 0}
	var opts := _tilt_options(r.cells, me, banned)
	if r.finale_left > 0 or rm == 0:
		# Closing tilt(s): pick the tilt with the best value including the reply.
		var bestv := -1000
		var picks := []
		for o in opts:
			var v: int = o[0] - _finale_value(o[1], 1 - me, r.finale_left - 1, o[2] if _no_repeat else -1)
			if v > bestv:
				bestv = v
				picks = [{"tilt": o[2], "cell": -1, "value": v}]
			elif v == bestv:
				picks.append({"tilt": o[2], "cell": -1, "value": v})
		return picks[rng.randi_range(0, picks.size() - 1)]
	var best := -1000
	var picks := []
	for o in opts:
		var base: int = o[0]
		var nb: PackedByteArray = o[1]
		for c in _drop_order(nb):
			nb[c] = me + 1
			# Only moves at least as good as the best so far need exact values.
			var v := base - _search(nb, 1 - me, ro, rm - 1, depth - 1, -1000, base - best + 1, o[2] if _no_repeat else -1)
			nb[c] = CarRules.EMPTY
			if v > best:
				best = v
				picks = [{"tilt": o[2], "cell": c, "value": v}]
			elif v == best:
				picks.append({"tilt": o[2], "cell": c, "value": v})
	return picks[rng.randi_range(0, picks.size() - 1)]
