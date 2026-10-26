extends SceneTree
## How long does one Hard-level move take? Run:
##   godot --headless --path warp-and-weft -s tools/time_hard.gd
func _init() -> void:
	var ai := WWAI.new(21)
	var times: Array = []
	var depths: Array = []
	for b in 12:
		var r := WWRules.new(WWRules.make_board(31000 + b))
		while not r.is_over():
			var t0 := Time.get_ticks_usec()
			var pick := ai.choose(r, WWAI.Level.HARD)
			times.append((Time.get_ticks_usec() - t0) / 1000.0)
			depths.append(ai.depth_reached)
			r.play(pick)
	times.sort()
	var sum := 0.0
	for t in times:
		sum += t
	print("Hard move time over %d moves: mean %.0f ms  median %.0f ms  p95 %.0f ms  max %.0f ms" % [times.size(), sum / times.size(), times[times.size() / 2], times[int(times.size() * 0.95)], times[-1]])
	depths.sort()
	print("depth reached: median %d  min %d  max %d" % [depths[depths.size() / 2], depths[0], depths[-1]])
	quit()
