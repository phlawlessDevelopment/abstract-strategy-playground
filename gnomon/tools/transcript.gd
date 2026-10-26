extends SceneTree
## Prints one search-vs-search game ply by ply, as ASCII.
##   godot --headless --path gnomon -s tools/transcript.gd -- depth=2 len=2

const Rules = preload("res://scripts/rules.gd")
const AI = preload("res://scripts/ai.gd")


func _ascii(s) -> String:
	var out := ""
	for y in s.N:
		var line := ""
		for x in s.N:
			var i: int = y * s.N + x
			if not s.playable(x, y):
				line += " #"
			elif s.board[i] == 0:
				line += " ."
			else:
				var ch := "A" if s.board[i] == 1 else "t"
				line += " " + ch
		out += line + "\n"
	return out


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var s = Rules.new()
	s.shadow_len = int(args.get("len", 2))
	s.day_len = int(args.get("day", 8))
	s.start_sun = int(args.get("sun", 0))
	s.start_rows = int(args.get("rows", 1))
	s.snake = int(args.get("snake", 0)) == 1
	s.mover_captures = int(args.get("mover", 1)) == 1
	s.reset()
	var ai := AI.new(int(args.get("depth", 2)))
	ai.rng.seed = int(args.get("seed", 1))
	print("start  sun=%s" % s.SUN_NAMES[s.sun])
	print(_ascii(s))
	var ply := 0
	while s.winner == 0 and ply < 120:
		var m: int = ai.choose(s)
		var who := "Amber" if s.turn == 1 else "Teal"
		var ev := []
		var before_sun: int = s.sun
		s.apply(m, ev)
		ply += 1
		var desc := ""
		for e in ev:
			match e.type:
				"move":
					desc += " move %d,%d->%d,%d" % [e.from % 7, e.from / 7, e.to % 7, e.to / 7]
				"eclipse":
					for st in e.stones:
						desc += " ECLIPSE(%s@%d,%d)" % ["A" if st.player == 1 else "t", st.idx % 7, st.idx / 7]
				"sun":
					desc += " SUN->%s" % s.SUN_NAMES[e.sun]
				"dusk":
					desc += " DUSK ring=%d lost=%d" % [e.ring, e.stones.size()]
		print("ply %d %s:%s   [A=%d t=%d sun=%s]" % [ply, who, desc, s.counts[1], s.counts[2], s.SUN_NAMES[s.sun]])
		print(_ascii(s))
	print("winner=%d" % s.winner)
	quit()
