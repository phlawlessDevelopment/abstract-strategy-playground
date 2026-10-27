extends SceneTree
## Self-play for tuning. Run:
##   godot --headless --path careen -s tools/selfplay.gd -- games=100 a=1 b=1 size=6 stones=9
## a / b are search depths in turns (0 = random). Each pairing is played with seats swapped.
func _init() -> void:
	var opts := {"games": 100, "a": 0, "b": 0, "size": 6, "stones": 11, "seed": 1, "posts": "", "final": 1, "norepeat": 0}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2:
			opts[kv[0]] = kv[1] if kv[0] == "posts" else int(kv[1])
	var posts := PackedInt32Array()
	if opts["posts"] != "":
		for p in String(opts["posts"]).split(","):
			posts.append(int(p))
	var ai := CarAI.new(int(opts["seed"]))
	var t0 := Time.get_ticks_msec()
	var wins_a := 0
	var wins_b := 0
	var draws := 0
	var first_wins := 0
	var crushed_total := 0
	var turns_total := 0
	var hist := {}
	var tilt_gain := [0, 0]    # net stones gained by each seat's own tilts (enemy crushed minus own crushed)
	var tilt_count := [0, 0]
	var swing_by_turn := {}
	for g in int(opts["games"]):
		for swap in 2:
			var d_amber: int = opts["a"] if swap == 0 else opts["b"]
			var d_teal: int = opts["b"] if swap == 0 else opts["a"]
			var r := CarRules.new(opts["size"], opts["stones"], posts, opts["final"], opts["norepeat"] == 1)
			while not r.is_over():
				var d := d_amber if r.turn == CarRules.AMBER else d_teal
				var pick := ai.choose(r, d)
				if r.phase == CarRules.Phase.TILT:
					var who := r.turn
					var turn_idx := r.events.size()
					r.tilt(pick["tilt"])
					var e: Dictionary = r.events[-1]
					var net: int = e["crushed"][1 - who] - e["crushed"][who]
					tilt_gain[who] += net
					tilt_count[who] += 1
				if not r.is_over():
					r.drop(pick["cell"])
			crushed_total += r.lost[0] + r.lost[1]
			turns_total += r.events.size()
			var diff: int = r.lost[1] - r.lost[0]     # positive = Amber ahead
			hist[diff] = hist.get(diff, 0) + 1
			var w := r.winner()
			if w == 2:
				draws += 1
			else:
				if w == CarRules.AMBER:
					first_wins += 1
				if (w == CarRules.AMBER) == (swap == 0):
					wins_a += 1
				else:
					wins_b += 1
	var total: int = int(opts["games"]) * 2
	print("depth a=%d vs b=%d | size %d stones %d final %d norepeat %d | %d games in %.1fs | nodes %d" % [opts["a"], opts["b"], opts["size"], opts["stones"], opts["final"], opts["norepeat"], total, (Time.get_ticks_msec() - t0) / 1000.0, ai.nodes])
	print("  a wins %.1f%%  b wins %.1f%%  draws %.1f%%   | first player (Amber) wins %.1f%%" % [100.0 * wins_a / total, 100.0 * wins_b / total, 100.0 * draws / total, 100.0 * first_wins / total])
	print("  net stones gained by own tilts per tilt:  Amber %+.3f   Teal %+.3f" % [float(tilt_gain[0]) / maxi(1, tilt_count[0]), float(tilt_gain[1]) / maxi(1, tilt_count[1])])
	print("  avg stones crushed per game %.2f   avg lead histogram (Amber lead: games):" % [float(crushed_total) / total], hist)
	quit()
