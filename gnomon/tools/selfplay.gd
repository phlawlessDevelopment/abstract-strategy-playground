extends SceneTree
## Headless self-play. Run:
##   godot --headless --path gnomon -s tools/selfplay.gd -- games=40 p1=2 p2=2 len=2 day=8
## p1/p2: search depth per side, 0 = uniformly random legal move.

const Rules = preload("res://scripts/rules.gd")
const AI = preload("res://scripts/ai.gd")


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var games := int(args.get("games", 20))
	var d1 := int(args.get("p1", 0))
	var d2 := int(args.get("p2", 0))

	var wins := [0, 0, 0, 0]
	var by_total_night := 0
	var plies_sum := 0
	var left_sum := 0
	var max_plies := 0
	var passes := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var t0 := Time.get_ticks_msec()

	for g in games:
		var s = Rules.new()
		s.shadow_len = int(args.get("len", 2))
		s.day_len = int(args.get("day", 8))
		s.max_ring = int(args.get("rings", 3))
		s.start_sun = int(args.get("sun", 0))
		s.start_rows = int(args.get("rows", 1))
		s.snake = int(args.get("snake", 0)) == 1
		s.mover_captures = int(args.get("mover", 1)) == 1
		s.reset()
		var ais := [null, AI.new(d1) if d1 > 0 else null, AI.new(d2) if d2 > 0 else null]
		var plies := 0
		while s.winner == 0:
			var m: int
			var brain = ais[s.turn]
			if brain == null:
				var mv: PackedInt32Array = s.legal_moves()
				m = mv[rng.randi() % mv.size()]
			else:
				m = brain.choose(s)
			if m < 0:
				passes += 1
			s.apply(m)
			plies += 1
			if plies > 400:
				push_error("runaway game")
				break
		wins[s.winner] += 1
		if s.ring >= s.max_ring and s.counts[1] > 0 and s.counts[2] > 0:
			by_total_night += 1
		plies_sum += plies
		max_plies = maxi(max_plies, plies)
		left_sum += s.counts[1] + s.counts[2]

	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	print("games=%d  P1 wins=%d  P2 wins=%d  draws=%d" % [games, wins[1], wins[2], wins[3]])
	print("avg plies=%.1f  max=%d  avg stones left=%.2f  ended by night=%d  passes=%d  (%.1fs)" % [
		float(plies_sum) / games, max_plies, float(left_sum) / games, by_total_night, passes, dt])
	quit()
