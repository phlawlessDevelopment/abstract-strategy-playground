extends SceneTree
## Self-play for tuning. Run:
##   godot --headless --path warp-and-weft -s tools/selfplay.gd -- games=200 a=2 b=2 size=7 komi=4.5
## a / b are search depths (0 = random, 1 = greedy, 100 = the Hard level). Each board is played twice with seats swapped.

func _init() -> void:
	var opts := {"games": 100, "a": 0, "b": 0, "size": 7, "komi": 4.5, "seed": 1}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2:
			opts[kv[0]] = float(kv[1]) if kv[0] == "komi" else int(kv[1])
	var games: int = opts["games"]
	var ai := WWAI.new(7)
	var wins_a := 0
	var wins_b := 0
	var draws := 0
	var weft_wins := 0
	var total_len := 0
	var sum_weft_margin := 0.0   # raw score difference Weft - Warp (no komi)
	var stranded_early := 0
	var t0 := Time.get_ticks_msec()
	for g in games:
		var vals := WWRules.make_board(int(opts["seed"]) * 100003 + g, opts["size"])
		for swap in 2:
			var depth_weft: int = opts["a"] if swap == 0 else opts["b"]
			var depth_warp: int = opts["b"] if swap == 0 else opts["a"]
			var r := WWRules.new(vals, opts["size"], opts["komi"])
			while not r.is_over():
				var d := depth_weft if r.turn == WWRules.WEFT else depth_warp
				r.play(ai.choose(r, WWAI.Level.HARD) if d == 100 else ai.choose_depth(r, d))
			total_len += r.history.size()
			sum_weft_margin += r.score[0] - r.score[1]
			if r.cells_left() > 4:
				stranded_early += 1
			var w := r.winner()
			if w == 2:
				draws += 1
			else:
				if w == WWRules.WEFT:
					weft_wins += 1
				var a_is_weft := (swap == 0)
				if (w == WWRules.WEFT) == a_is_weft:
					wins_a += 1
				else:
					wins_b += 1
	var total := games * 2
	print("depth a=%d vs b=%d | size %d komi %.1f | %d games in %.1fs" % [opts["a"], opts["b"], opts["size"], opts["komi"], total, (Time.get_ticks_msec() - t0) / 1000.0])
	print("  a wins %.1f%%  b wins %.1f%%  draws %.1f%%" % [100.0 * wins_a / total, 100.0 * wins_b / total, 100.0 * draws / total])
	print("  Weft(first) wins %.1f%%  avg Weft-Warp score diff %+.2f  avg length %.1f  ended with >4 cells left %.1f%%" % [100.0 * weft_wins / total, sum_weft_margin / total, float(total_len) / total, 100.0 * stranded_early / total])
	quit()
