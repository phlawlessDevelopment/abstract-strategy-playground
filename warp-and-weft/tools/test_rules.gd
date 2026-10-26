extends SceneTree
## Rule and AI tests. Run:
##   godot --headless --path warp-and-weft -s tools/test_rules.gd
## Exits with code 1 if anything fails.

var failures := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


# Unpruned reference minimax: value = future (mover - other) points.
func brute(vals: PackedInt32Array, m: int, at: int, who: int, depth: int, n: int) -> int:
	var mv := WWRules.lane(m, at, who, n)
	if mv.is_empty() or depth == 0:
		return 0
	var best := -1000000
	for cell in mv:
		best = maxi(best, vals[cell] - brute(vals, m | (1 << cell), cell, 1 - who, depth - 1, n))
	return best


func _init() -> void:
	# --- board generation ---------------------------------------------------
	for seed_value in 50:
		var v := WWRules.make_board(seed_value)
		var symmetric := true
		for r in 7:
			for c in 7:
				if v[r * 7 + c] != v[c * 7 + r]:
					symmetric = false
		ok(symmetric, "board %d is mirror-symmetric" % seed_value)
		ok(v[24] == 0, "centre cell is 0")
	ok(WWRules.make_board(5) == WWRules.make_board(5), "same seed -> same board")
	ok(WWRules.make_board(5) != WWRules.make_board(6), "different seed -> different board")

	# --- start position and lanes -------------------------------------------
	var r := WWRules.new(WWRules.make_board(1))
	ok(r.shuttle == 24 and r.turn == WWRules.WEFT, "starts at centre, Weft to move")
	var mv := r.moves()
	ok(mv.size() == 6, "Weft starts with 6 options")
	for c in mv:
		ok(c / 7 == 3 and c != 24, "Weft's options are in the centre row")
	ok(r.play(25), "Weft can step right")
	ok(r.turn == WWRules.WARP and r.shuttle == 25, "turn passes to Warp")
	for c in r.moves():
		ok(c % 7 == 4 and c != 25, "Warp's options are in the shuttle's column")
	ok(not r.play(26), "Warp cannot move sideways")
	ok(not r.play(25), "cannot land where the shuttle already is")
	ok(r.score[0] == r.values[25] and r.score[1] == 0, "gain goes to the mover")

	# --- used-up cells are hopped over -------------------------------------
	var rj := WWRules.new(WWRules.make_board(2))
	rj.play(26)                       # Weft to (3,5)
	rj.play(5 * 7 + 5)                # Warp to (5,5)
	rj.play(5 * 7 + 1)                # Weft to (5,1); the used cell (5,5) lies between 1 and 6
	var rj2 := WWRules.new(rj.values)
	rj2.mask |= 1 << (5 * 7 + 5)
	rj2.shuttle = 5 * 7 + 3
	rj2.mask |= 1 << rj2.shuttle
	rj2.turn = WWRules.WEFT
	ok(5 * 7 + 6 in rj2.moves() and 5 * 7 + 4 in rj2.moves(), "a used cell is hopped over, not a wall")
	ok(not (5 * 7 + 5 in rj2.moves()) and not (5 * 7 + 3 in rj2.moves()), "used cells and the shuttle's own cell are not options")

	# --- undo ---------------------------------------------------------------
	var ru := WWRules.new(WWRules.make_board(3))
	var snap_mask := ru.mask
	ru.play(ru.moves()[0])
	ru.play(ru.moves()[0])
	ru.undo()
	ru.undo()
	ok(ru.mask == snap_mask and ru.score == [0, 0] and ru.turn == WWRules.WEFT and ru.shuttle == 24, "undo restores everything")
	ok(not ru.undo(), "undo on empty history is a no-op")

	# --- stranding ends the game --------------------------------------------
	var rs := WWRules.new(WWRules.make_board(4), 7, 0.0)
	# Use up the whole of row 0 except the shuttle's target, then land there as Warp's target.
	rs.shuttle = 0 * 7 + 3           # shuttle at (0,3), Warp to move? set Weft: row 0 empty below
	rs.mask = 1 << rs.shuttle
	for x in 7:
		rs.mask |= 1 << x
	rs.turn = WWRules.WEFT
	ok(rs.is_over(), "no cells left on the line -> game over")
	rs.score = [10, 7]
	rs.komi = 0.0
	ok(rs.winner() == WWRules.WEFT, "higher score wins")
	rs.komi = 3.0
	ok(rs.winner() == 2, "komi equal to the lead is a draw")
	rs.komi = 4.0
	ok(rs.winner() == WWRules.WARP, "komi is added to Warp's score")
	rs.komi = 0.0
	rs.score = [8, 8]
	ok(rs.winner() == 2, "equal score is a draw")

	# --- random games always finish -----------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for pass_n in 1:
		for g in 300:
			var rg := WWRules.new(WWRules.make_board(g))
			var steps := 0
			while not rg.is_over():
				var m := rg.moves()
				ok(m.size() > 0, "moves() non-empty while not over")
				rg.play(m[rng.randi_range(0, m.size() - 1)])
				steps += 1
				if steps > 60:
					break
			ok(steps <= 48, "game finishes within 48 moves")
			ok(rg.winner() != -1, "finished game has a result")
			# score bookkeeping: tallies equal the sum of gains in history
			var s := [0, 0]
			for h in rg.history:
				s[h["who"]] += h["gain"]
			ok(s == rg.score, "scores match history")

	# --- search: alpha-beta must agree with brute force ---------------------
	var ai := WWAI.new(5)
	for pass_n in 1:
		for g in 40:
			var rg := WWRules.new(WWRules.make_board(500 + g))
			# Play a few random moves to reach varied positions.
			for k in g % 9:
				var m := rg.moves()
				if m.is_empty():
					break
				rg.play(m[rng.randi_range(0, m.size() - 1)])
			if rg.is_over():
				continue
			for depth in [2, 3, 4, 5]:
				var sc := ai.score_moves(rg, depth)
				for cell in sc:
					var expect: int = rg.values[cell] - brute(rg.values, rg.mask | (1 << cell), cell, 1 - rg.turn, depth - 1, 7)
					ok(sc[cell] == expect, "search == brute force (board %d depth %d cell %d got %d want %d)" % [g, depth, cell, sc[cell], expect])

	# --- default komi -------------------------------------------------------
	var rk := WWRules.new(WWRules.make_board(8))
	ok(rk.komi == 4.5, "default komi is 4.5")
	rk.score = [21, 16]
	rk.mask = (1 << 49) - 1           # everything used up: game over
	ok(rk.is_over() and rk.winner() == WWRules.WEFT, "lead of 5 beats komi 4.5: Weft wins")
	rk.score = [20, 16]
	ok(rk.winner() == WWRules.WARP, "lead of 4 loses to komi 4.5: Warp wins")

	# --- every AI level plays only legal moves and finishes games ------------
	for level in [WWAI.Level.EASY, WWAI.Level.MEDIUM, WWAI.Level.HARD]:
		for g in 6:
			var ra := WWRules.new(WWRules.make_board(800 + g))
			var guard := 0
			while not ra.is_over() and guard < 60:
				var pick := ai.choose(ra, level)
				ok(ra.is_legal(pick), "AI level %d picked a legal move" % level)
				ra.play(pick)
				guard += 1
			ok(ra.is_over(), "AI level %d finished game %d" % [level, g])

	# --- Hard search is exact once the endgame fits in its depth -------------
	var rx := WWRules.new(WWRules.make_board(77))
	while rx.cells_left() > 9 and not rx.is_over():
		var mm := rx.moves()
		rx.play(mm[rng.randi_range(0, mm.size() - 1)])
	if not rx.is_over():
		ai.choose_deep(rx, 14, 5000000)
		ok(ai.depth_reached >= rx.cells_left(), "Hard reaches full depth with %d cells left (got %d)" % [rx.cells_left(), ai.depth_reached])

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
