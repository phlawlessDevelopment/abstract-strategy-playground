extends SceneTree
## Rules unit tests.   godot --headless --path gnomon -s tools/test_rules.gd

const Rules = preload("res://scripts/rules.gd")
const AI = preload("res://scripts/ai.gd")

var failures := 0
var checks := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func empty_state():
	var s = Rules.new()
	s.board.fill(0)
	s.counts = [0, 0, 0]
	return s


func put(s, x: int, y: int, p: int) -> void:
	s.board[y * s.N + x] = p
	s.counts[p] += 1


## Encode a move from (fx, fy) to (tx, ty) the way Rules does: from * 64 + to.
func mv(fx: int, fy: int, tx: int, ty: int) -> int:
	return (fy * 7 + fx) * 64 + ty * 7 + tx


func _init() -> void:
	test_eclipse_geometry()
	test_shadow_length_and_friends()
	test_snake_order()
	test_alternating_order()
	test_dusk_and_night()
	test_pass_and_no_moves()
	test_random_games_terminate()
	test_clone_independence()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## For each of the 8 sun directions, an enemy stone 1 or 2 cells toward the sun
## eclipses a stone; one cell *away* from the sun does not; a knight-move away
## never does.
func test_eclipse_geometry() -> void:
	for sun in 8:
		var dx: int = Rules.DX[sun]
		var dy: int = Rules.DY[sun]
		for k in [1, 2]:
			var s = empty_state()
			s.sun = sun
			put(s, 3, 3, 1)
			put(s, 3 + dx * k, 3 + dy * k, 2)
			var dead := s.eclipsed_cells()
			ok(dead.size() == 1 and dead[0] == 3 * 7 + 3, "sun %d, enemy %d toward sun eclipses" % [sun, k])
		var s2 = empty_state()
		s2.sun = sun
		put(s2, 3, 3, 1)
		put(s2, 3 - dx, 3 - dy, 2)
		# The enemy behind me is downhill of me: *it* is eclipsed, I am not.
		var behind := s2.eclipsed_cells()
		ok(behind.size() == 1 and behind[0] == (3 - dy) * 7 + (3 - dx), "sun %d, enemy away from sun is the one eclipsed" % sun)
		var s3 = empty_state()
		s3.sun = sun
		put(s3, 3, 3, 1)
		var fx: int = 3 + dx * 3
		var fy: int = 3 + dy * 3
		if fx >= 0 and fx < 7 and fy >= 0 and fy < 7:
			put(s3, fx, fy, 2)
		ok(s3.eclipsed_cells().is_empty(), "sun %d, enemy 3 cells away is out of reach" % sun)
	# Knight offsets are never aligned.
	for sun in 8:
		var s = empty_state()
		s.sun = sun
		put(s, 3, 3, 1)
		put(s, 4, 5, 2)
		put(s, 2, 1, 2)
		put(s, 5, 2, 2)
		put(s, 1, 4, 2)
		ok(s.eclipsed_cells().is_empty(), "knight offsets are safe at sun %d" % sun)


func test_shadow_length_and_friends() -> void:
	# Friendly stones never eclipse each other.
	var s = empty_state()
	s.sun = 0
	put(s, 3, 3, 1)
	put(s, 3, 2, 1)
	ok(s.eclipsed_cells().is_empty(), "friends do not eclipse")
	# Both colours can be eclipsed in the same resolution (simultaneous).
	var t = empty_state()
	t.sun = 2                       # sun to the east
	put(t, 1, 1, 1)
	put(t, 2, 1, 2)                 # Teal is east of Amber -> Amber eclipsed
	put(t, 1, 5, 2)
	put(t, 0, 5, 1)                 # Amber is west of Teal... Teal east of Amber -> Amber eclipsed again
	var dead := t.eclipsed_cells()
	ok(dead.size() == 2, "two eclipses in one pass")
	# Mutual: with the sun east, A at x=2 and T at x=3 and A at x=4: T is eclipsed by A(4), A(2) by T(3).
	var u = empty_state()
	u.sun = 2
	put(u, 2, 3, 1)
	put(u, 3, 3, 2)
	put(u, 4, 3, 1)
	ok(u.eclipsed_cells().size() == 2, "a chain A T A eclipses both A(2) and T(3) at once")
	# Shadow length parameter.
	var w = empty_state()
	w.shadow_len = 1
	w.sun = 2
	put(w, 2, 3, 1)
	put(w, 4, 3, 2)
	ok(w.eclipsed_cells().is_empty(), "shadow_len 1 does not reach 2 cells")


func test_snake_order() -> void:
	var s = Rules.new()
	s.snake = true
	s.reset()
	var order := []
	for i in 12:
		order.append(s.turn)
		var mv: PackedInt32Array = s.legal_moves()
		# Pick a deliberately passive move: first legal move. Stones are far apart
		# at the start so nobody dies this early.
		s.apply(mv[0])
		if s.winner != 0:
			break
	ok(order.slice(0, 8) == [1, 2, 2, 1, 1, 2, 2, 1], "snake order is A B B A A B B A, got %s" % [order])
	ok(s.round_no >= 5, "sun advanced after every 2 plies")


func test_alternating_order() -> void:
	var s = Rules.new()
	s.snake = false
	s.reset()
	var order := []
	for i in 8:
		order.append(s.turn)
		s.apply(s.legal_moves()[0])
		if s.winner != 0:
			break
	ok(order == [1, 2, 1, 2, 1, 2, 1, 2], "plain order alternates, got %s" % [order])


func test_dusk_and_night() -> void:
	var s = empty_state()
	s.snake = false
	s.day_len = 1              # dusk after every round
	s.sun = 0                  # sun north; shadows fall south
	put(s, 0, 0, 1)            # on the outer ring
	put(s, 3, 3, 1)
	put(s, 6, 6, 2)            # on the outer ring
	put(s, 3, 5, 2)
	s.turn = 1
	var ev := []
	s.apply(mv(3, 3, 2, 3), ev)        # Amber steps sideways (nothing aligned)
	s.apply(mv(3, 5, 4, 5), ev)        # Teal steps sideways: round over
	ok(s.ring == 1, "ring darkened after dusk, ring=%d" % s.ring)
	ok(s.board[0] == 0 and s.board[48] == 0, "stones on the outer ring were lost to dusk")
	ok(s.counts[1] == 1 and s.counts[2] == 1, "counts updated after dusk: %s" % [s.counts])
	var saw_dusk := false
	for e in ev:
		if e.type == "dusk":
			saw_dusk = true
	ok(saw_dusk, "dusk event emitted")
	ok(not s.playable(0, 3) and s.playable(1, 1), "playable() respects the dark ring")
	ok(s.moves_for(3 * 7 + 2).size() > 0, "moves_for works after dusk")

	# The final dusk ends the game on stone count (nobody is deleted).
	var t = empty_state()
	t.snake = false
	t.day_len = 1
	t.max_ring = 1             # the first dusk is the last
	t.sun = 0
	put(t, 1, 1, 1)
	put(t, 2, 1, 1)
	put(t, 5, 5, 2)
	t.turn = 1
	t.apply(mv(2, 1, 2, 2))
	t.apply(mv(5, 5, 5, 4))
	ok(t.winner == Rules.P1, "more stones wins at the final dusk, winner=%d" % t.winner)
	ok(t.counts[1] == 2 and t.counts[2] == 1, "final dusk deletes nothing")

	# Equal stones at the final dusk is a draw.
	var u = empty_state()
	u.snake = false
	u.day_len = 1
	u.max_ring = 1
	u.sun = 0
	put(u, 1, 1, 1)
	put(u, 5, 5, 2)
	u.turn = 1
	u.apply(mv(1, 1, 1, 2))
	u.apply(mv(5, 5, 5, 4))
	ok(u.winner == Rules.DRAW, "equal stones at final dusk is a draw")

	# Eliminating the last enemy stone wins immediately; mutual wipe-out is a draw.
	var w = empty_state()
	w.snake = false
	w.sun = 2                   # east
	put(w, 1, 3, 1)
	put(w, 4, 4, 2)
	w.turn = 1
	w.apply(mv(1, 3, 2, 3))     # Amber to (2,3); Teal at (4,4) is not aligned
	ok(w.winner == 0, "no early win")
	w.apply(mv(4, 4, 4, 3))     # Teal steps to (4,3): two cells east of Amber -> Amber eclipsed
	ok(w.winner == Rules.P2, "last stone eclipsed -> opponent wins, got %d" % w.winner)


func test_pass_and_no_moves() -> void:
	# With only the centre cell alive, a lone stone has nowhere to step.
	var s = empty_state()
	s.ring = 3
	put(s, 3, 3, 1)
	put(s, 0, 0, 2)             # (off-board in effect; just keeps both sides alive)
	s.turn = 1
	var mvs: PackedInt32Array = s.legal_moves()
	ok(mvs.size() == 1 and mvs[0] == -1, "no legal step -> only PASS")
	s.apply(-1)
	ok(s.turn == 2 or s.second_half, "pass hands the move over")


func test_random_games_terminate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for snake in [false, true]:
		for g in 60:
			var s = Rules.new()
			s.snake = snake
			s.start_sun = g % 8
			s.reset()
			var plies := 0
			while s.winner == 0 and plies < 500:
				var mv: PackedInt32Array = s.legal_moves()
				ok(mv.size() > 0, "a running game always has a move (or pass)")
				s.apply(mv[rng.randi() % mv.size()])
				plies += 1
				ok(s.counts[1] >= 0 and s.counts[2] >= 0, "counts never negative")
			ok(s.winner != 0, "random game %d terminates (snake=%s)" % [g, snake])
			# counts must equal what is actually on the board
			var c1 := 0
			var c2 := 0
			for v in s.board:
				if v == 1:
					c1 += 1
				elif v == 2:
					c2 += 1
			ok(c1 == s.counts[1] and c2 == s.counts[2], "counts match board")


func test_clone_independence() -> void:
	var s = Rules.new()
	var c = s.clone()
	c.apply(c.legal_moves()[0])
	var same := true
	for i in s.board.size():
		if s.board[i] != Rules.new().board[i]:
			same = false
	ok(same, "applying a move on a clone leaves the original untouched")
