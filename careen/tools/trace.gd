extends SceneTree
## Print a game as text. godot --headless --path careen -s tools/trace.gd -- a=1 b=1 seed=3
func show(r: CarRules) -> String:
	var out := ""
	for y in r.h:
		for x in r.w:
			out += [".", "A", "T", "#"][r.cells[y * r.w + x]]
		out += "\n"
	return out

func _init() -> void:
	var opts := {"a": 1, "b": 1, "seed": 3, "final": 1}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		opts[kv[0]] = int(kv[1])
	var ai := CarAI.new(int(opts["seed"]))
	var r := CarRules.new(6, 11, PackedInt32Array(), opts["final"])
	var turn_no := 0
	while not r.is_over():
		var d: int = opts["a"] if r.turn == CarRules.AMBER else opts["b"]
		var pick := ai.choose(r, d)
		var name := "Amber" if r.turn == CarRules.AMBER else "Teal"
		var line := "%2d %-5s " % [turn_no, name]
		if r.phase == CarRules.Phase.TILT:
			r.tilt(pick["tilt"])
			var e: Dictionary = r.events[-1]
			line += "tilt %-5s crushed A:%d T:%d  " % [CarRules.DIR_NAMES[pick["tilt"]], e["crushed"][0], e["crushed"][1]]
		if not r.is_over():
			r.drop(pick["cell"])
			line += "drop (%d,%d)" % [pick["cell"] % r.w, pick["cell"] / r.w]
		print(line)
		turn_no += 1
	print(show(r))
	print("lost A=%d T=%d" % [r.lost[0], r.lost[1]])
	quit()
