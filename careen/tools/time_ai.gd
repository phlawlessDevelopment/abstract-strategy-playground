extends SceneTree
## How long does each computer move take? godot --headless --path careen -s tools/time_ai.gd -- depth=2 seed=3
func _init() -> void:
	var depth := 2
	var seed_v := 3
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv[0] == "depth": depth = int(kv[1])
		if kv[0] == "seed": seed_v = int(kv[1])
	var ai := CarAI.new(seed_v)
	var r := CarRules.new()
	var worst := 0
	var total := 0
	var moves := 0
	while not r.is_over():
		var t0 := Time.get_ticks_msec()
		var pick := ai.choose(r, depth)
		var ms := Time.get_ticks_msec() - t0
		worst = maxi(worst, ms)
		total += ms
		moves += 1
		print("move %2d  %4d ms" % [moves, ms])
		if r.phase == CarRules.Phase.TILT:
			r.tilt(pick["tilt"])
		if not r.is_over():
			r.drop(pick["cell"])
	print("depth %d: %d moves, mean %d ms, worst %d ms" % [depth, moves, total / moves, worst])
	quit()
