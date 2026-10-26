extends SceneTree
## How much does the first-move edge vary from board to board? Run:
##   godot --headless --path warp-and-weft -s tools/edge_stats.gd -- boards=200 depth=8
func _init() -> void:
	var opts := {"boards": 200, "depth": 8}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2:
			opts[kv[0]] = int(kv[1])
	var ai := WWAI.new(3)
	var edges: Array = []
	var t0 := Time.get_ticks_msec()
	for b in opts["boards"]:
		var r := WWRules.new(WWRules.make_board(7000 + b), 7, 0.0)
		var sc := ai.score_moves(r, opts["depth"])
		var best := -1000
		for c in sc:
			best = maxi(best, sc[c])
		edges.append(best)
	edges.sort()
	var sum := 0.0
	for e in edges:
		sum += e
	var mean := sum / edges.size()
	var var_sum := 0.0
	for e in edges:
		var_sum += (e - mean) * (e - mean)
	var hist := {}
	for e in edges:
		var k := int(floor(e / 2.0)) * 2
		hist[k] = hist.get(k, 0) + 1
	var keys := hist.keys()
	keys.sort()
	print("depth %d, %d boards, %.2fs per board" % [opts["depth"], edges.size(), (Time.get_ticks_msec() - t0) / 1000.0 / edges.size()])
	print("  mean %+.2f  sd %.2f  min %d  max %d" % [mean, sqrt(var_sum / edges.size()), edges[0], edges[-1]])
	for k in keys:
		print("  [%+3d,%+3d) %s" % [k, k + 2, "#".repeat(hist[k])])
	quit()
