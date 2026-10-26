extends SceneTree
## Where does the first-player edge come from? Run:
##   godot --headless --path warp-and-weft -s tools/diagnose.gd -- boards=300 depth=4
func _init() -> void:
	var opts := {"boards": 300, "depth": 4}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2:
			opts[kv[0]] = int(kv[1])
	var ai := WWAI.new(11)
	var stranded := [0, 0]            # [Weft stranded, Warp stranded]
	var diff_by := [0.0, 0.0]
	var n_by := [0, 0]
	var diffs: Array = []
	var moves_each := [0.0, 0.0]
	for b in opts["boards"]:
		var r := WWRules.new(WWRules.make_board(9000 + b), 7, 0.0)
		while not r.is_over():
			r.play(ai.choose_depth(r, opts["depth"]))
		var who: int = r.turn            # the stranded player
		stranded[who] += 1
		var d := float(r.score[0] - r.score[1])
		diff_by[who] += d
		n_by[who] += 1
		diffs.append(d)
		for h in r.history:
			moves_each[h["who"]] += 1
	var mean := 0.0
	for d in diffs:
		mean += d
	mean /= diffs.size()
	var sd := 0.0
	for d in diffs:
		sd += (d - mean) * (d - mean)
	sd = sqrt(sd / diffs.size())
	print("depth %d mirror self-play, %d boards" % [opts["depth"], opts["boards"]])
	print("  Weft stranded in %d games, Warp stranded in %d games" % [stranded[0], stranded[1]])
	print("  avg Weft-Warp diff overall %+.2f (sd %.2f)" % [mean, sd])
	print("  ...when Weft is the stranded one: %+.2f   when Warp is: %+.2f" % [diff_by[0] / maxi(1, n_by[0]), diff_by[1] / maxi(1, n_by[1])])
	print("  avg moves made: Weft %.1f  Warp %.1f" % [moves_each[0] / opts["boards"], moves_each[1] / opts["boards"]])
	quit()
