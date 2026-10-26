extends Control
## Game flow for Gnomon: owns the rules state, the AI, undo, and the animation
## of rule events. All drawing lives in view.gd.

const Rules = preload("res://scripts/rules.gd")
const AI = preload("res://scripts/ai.gd")
const View = preload("res://scripts/view.gd")

const LEVELS := [
	{"name": "Easy", "depth": 1},
	{"name": "Normal", "depth": 2},
	{"name": "Hard", "depth": 3},
	{"name": "Expert", "depth": 4},
]
const C_AMBER := Color("f6b93b")
const C_TEAL := Color("4fdcc6")
const C_MUTED := Color("968fb0")
const C_BAD := Color("ff7a86")
const C_SUN := Color("ffe9a6")

var state                       # authoritative rules state
var disp                        # what the screen currently shows (lags during animation)
var view
var ai
var history: Array = []         # snapshots of `state` before each move, for undo
var vs_ai := true
var human_side := 1
var level := 1
var busy := false
var hints := true
var _ai_token := 0              # invalidates a pending AI move after restart/undo
var _autoplay := false          # dev aid: the computer plays both sides


func _ready() -> void:
	randomize()
	view = View.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	view.cell_clicked.connect(_on_cell_clicked)
	view.button_pressed.connect(_on_button)
	view.hover_changed.connect(_on_hover)
	ai = AI.new(LEVELS[level].depth)
	view.show_help = true
	_new_game()
	if "--shots" in OS.get_cmdline_user_args():
		_shot_mode()
	elif "--autoplay" in OS.get_cmdline_user_args():
		_autoplay_mode()
	elif "--stress" in OS.get_cmdline_user_args():
		_stress_mode()


# ------------------------------------------------------------------ setup

func _new_game() -> void:
	_ai_token += 1
	state = Rules.new()
	disp = state.clone()
	history.clear()
	busy = false
	view.state = disp
	view.selected = -1
	view.dests = PackedInt32Array()
	view.dest_info = {}
	view.last_from = -1
	view.last_to = -1
	view.log_lines = []
	view.game_over = false
	view.banner_visible = true
	view.sun_t = float(disp.sun)
	view.night_fade = 1.0
	_rebuild_views()
	_log("A new game. Amber moves first.", C_MUTED)
	_refresh_buttons()
	_begin_turn()


func _rebuild_views() -> void:
	view.views.clear()
	for i in disp.board.size():
		if disp.board[i] != 0:
			_spawn_view(i, disp.board[i])


func _spawn_view(idx: int, owner: int) -> void:
	var sv := View.StoneView.new()
	sv.pos = view.cell_center(idx)
	sv.owner = owner
	view.views[idx] = sv


func _refresh_buttons() -> void:
	var x := View.PANEL_X
	var w := View.PANEL_W
	var bw := (w - 12.0) / 2.0
	var y := 640.0
	var h := 38.0
	view.buttons = [
		{"id": "new", "label": "New game  (R)", "rect": Rect2(x, y, bw, h)},
		{"id": "undo", "label": "Undo  (U)", "rect": Rect2(x + bw + 12, y, bw, h)},
		{"id": "mode", "label": "vs Computer" if vs_ai else "Two players", "rect": Rect2(x, y + 48, bw, h), "on": vs_ai},
		{"id": "side", "label": "You: Amber" if human_side == 1 else "You: Teal", "rect": Rect2(x + bw + 12, y + 48, bw, h), "on": vs_ai},
		{"id": "level", "label": "Level: " + LEVELS[level].name, "rect": Rect2(x, y + 96, bw, h), "on": vs_ai},
		{"id": "help", "label": "How to play  (F1)", "rect": Rect2(x + bw + 12, y + 96, bw, h)},
	]
	view.show_hints = hints


# ------------------------------------------------------------------ turn flow

func _is_human_turn() -> bool:
	if _autoplay:
		return false
	return not vs_ai or state.turn == human_side


func _begin_turn() -> void:
	view.selected = -1
	view.dests = PackedInt32Array()
	view.dest_info = {}
	view.thinking = false
	if state.winner != 0:
		_show_result()
		return
	view.game_over = false
	var who := "Amber" if state.turn == 1 else "Teal"
	var other := "Teal" if state.turn == 1 else "Amber"
	view.title_owner = state.turn
	view.title_text = "%s to move" % who
	view.sub_text = _default_sub()
	if state.second_half:
		view.turn_hint = "The sun turns after this move."
	else:
		view.turn_hint = "Then %s moves, then the sun turns." % other
	if not _is_human_turn():
		_ai_turn()


func _default_sub() -> String:
	if vs_ai and not _is_human_turn():
		return "The computer is thinking…"
	return "Pick a stone, then a cell."


func _show_result() -> void:
	view.game_over = true
	view.title_owner = state.winner if state.winner != 3 else 0
	if state.winner == 3:
		view.title_text = "A draw"
		view.sub_text = "The light fades on level terms."
	else:
		var who := "Amber" if state.winner == 1 else "Teal"
		view.title_text = "%s wins" % who
		view.sub_text = "%d stone%s to %d." % [state.counts[state.winner], "" if state.counts[state.winner] == 1 else "s", state.counts[3 - state.winner]]
	view.turn_hint = "Press R for a new game."


func _ai_turn() -> void:
	view.thinking = true
	var token := _ai_token
	busy = true
	await get_tree().create_timer(0.45).timeout
	if token != _ai_token:
		return
	ai.depth = LEVELS[level].depth
	var m: int = ai.choose(state)
	# On the easiest level the computer sometimes plays a random legal move.
	if level == 0 and randf() < 0.3:
		var mv: PackedInt32Array = state.legal_moves()
		m = mv[randi() % mv.size()]
	busy = false
	_play(m)


func _play(m: int) -> void:
	if state.winner != 0:
		return
	history.append(state.clone())
	var events: Array = []
	var mover: int = state.turn
	state.apply(m, events)
	busy = true
	view.selected = -1
	view.dests = PackedInt32Array()
	view.dest_info = {}
	var token := _ai_token
	await _animate(events, mover, token)
	if token != _ai_token:
		return
	busy = false
	_begin_turn()


# ------------------------------------------------------------------ input

func _on_cell_clicked(idx: int) -> void:
	if view.show_help or busy:
		return
	if state.winner != 0:
		view.banner_visible = not view.banner_visible
		return
	if not _is_human_turn():
		return
	if idx < 0:
		_deselect()
		return
	if view.selected >= 0 and idx in view.dests:
		_play(view.selected * 64 + idx)
		return
	if state.board[idx] == state.turn:
		_select(idx)
	else:
		_deselect()


func _select(idx: int) -> void:
	view.selected = idx
	view.dests = state.moves_for(idx)
	view.dest_info = {}
	for d in view.dests:
		view.dest_info[d] = _preview(idx, d)
	if view.dests.is_empty():
		view.sub_text = "That stone is boxed in."


func _deselect() -> void:
	view.selected = -1
	view.dests = PackedInt32Array()
	view.dest_info = {}


## What would moving from -> to do? Simulates it and reports the stones this
## move eclipses and how many of your own stones it leaves standing in shadow.
func _preview(from: int, to: int) -> Dictionary:
	var c = state.clone()
	var ev: Array = []
	var me: int = state.turn
	c.apply(from * 64 + to, ev)
	var takes := 0
	var lost := 0
	for e in ev:
		if e.type == "eclipse" or e.type == "dusk":
			for s in e.stones:
				if s.player == me:
					lost += 1
				else:
					takes += 1
	# Own stones left in an enemy shadow after the move (including after the
	# sun turns, if this move ends the round).
	var exposed := 0
	if c.winner == 0:
		for i in c.eclipsed_cells():
			if c.board[i] == me:
				exposed += 1
	var parts := []
	if takes > 0:
		parts.append("eclipses %d" % takes)
	if lost > 0:
		parts.append("loses %d to the dark" % lost)
	if exposed > 0:
		parts.append("leaves %d of yours in shadow" % exposed)
	if parts.is_empty():
		parts.append("quiet move")
	return {
		"good": takes > 0 and exposed + lost == 0,
		"risky": takes > 0 and exposed + lost > 0,
		"bad": takes == 0 and exposed + lost > 0,
		"text": ", ".join(parts),
	}


func _on_hover(idx: int) -> void:
	if state == null or state.winner != 0 or busy:
		return
	if view.selected >= 0 and idx in view.dests:
		var info: Dictionary = view.dest_info.get(idx, {})
		var t: String = info.get("text", "")
		view.sub_text = ("→ %s: %s" % [view.cell_name(idx), t]) if t != "" else "→ %s" % view.cell_name(idx)
	else:
		view.sub_text = _default_sub()


func _on_button(id: String) -> void:
	match id:
		"close_help":
			view.show_help = false
		"help":
			view.show_help = true
		"new":
			_new_game()
		"undo":
			_undo()
		"mode":
			vs_ai = not vs_ai
			_refresh_buttons()
			_new_game()
		"side":
			human_side = 3 - human_side
			_refresh_buttons()
			_new_game()
		"level":
			level = (level + 1) % LEVELS.size()
			_refresh_buttons()
			ai.depth = LEVELS[level].depth


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if view.show_help:
		view.show_help = false
		return
	match event.keycode:
		KEY_R:
			_new_game()
		KEY_U:
			_undo()
		KEY_H:
			hints = not hints
			view.show_hints = hints
		KEY_S:
			view.show_next = not view.show_next
		KEY_F1, KEY_SLASH:
			view.show_help = true
		KEY_ESCAPE:
			_deselect()


func _undo() -> void:
	if history.is_empty():
		return
	_ai_token += 1
	busy = false
	state = history.pop_back()
	if vs_ai:
		while not history.is_empty() and state.turn != human_side:
			state = history.pop_back()
	disp = state.clone()
	view.state = disp
	view.sun_t = float(disp.sun)
	view.night_fade = 1.0
	view.last_from = -1
	view.last_to = -1
	_rebuild_views()
	_log("Move taken back.", C_MUTED)
	_begin_turn()


# ------------------------------------------------------------------ animation

func _cell_name(idx: int) -> String:
	return view.cell_name(idx)


func _log(text: String, col: Color) -> void:
	view.log_lines.append({"text": text, "col": col})


func _owner_col(p: int) -> Color:
	return C_AMBER if p == 1 else C_TEAL


func _owner_name(p: int) -> String:
	return "Amber" if p == 1 else "Teal"


## Replays the rule events on `disp` so the screen shows each step in turn.
func _animate(events: Array, mover: int, token: int) -> void:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	for e in events:
		if token != _ai_token:
			return          # a restart or undo happened mid-animation
		match e.type:
			"move":
				var sv = view.views.get(e.from)
				if sv == null:
					continue
				view.views.erase(e.from)
				view.views[e.to] = sv
				disp.board[e.to] = disp.board[e.from]
				disp.board[e.from] = 0
				view.last_from = e.from
				view.last_to = e.to
				var tw := create_tween()
				tw.tween_property(sv, "pos", view.cell_center(e.to), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				await tw.finished
			"pass":
				_log("%s has no move and passes." % _owner_name(mover), C_MUTED)
			"eclipse":
				await _remove_stones(e.stones, "eclipsed")
			"sun":
				var target := float(e.sun)
				if target < view.sun_t:
					target += 8.0
				var tw := create_tween()
				tw.tween_property(view, "sun_t", target, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				await tw.finished
				view.sun_t = fposmod(view.sun_t, 8.0)
				disp.sun = e.sun
				disp.round_no = e.round
				_log("The sun moves to the %s." % names[e.sun], C_SUN)
			"dusk":
				disp.ring = e.ring
				view.night_fade = 0.0
				_log("Dusk. The outer ring goes dark.", C_BAD)
				var tw := create_tween()
				tw.tween_property(view, "night_fade", 1.0, 0.9)
				if not e.stones.is_empty():
					_remove_stones(e.stones, "lost to the dark")
				await tw.finished
			"night":
				_log("Night falls on the whole board.", C_BAD)
				await get_tree().create_timer(0.6).timeout
	if token != _ai_token:
		return
	# Settle: the display must match the real state exactly.
	disp = state.clone()
	view.state = disp
	_sync_views()


func _remove_stones(stones: Array, verb: String) -> void:
	var longest: Tween = null
	for s in stones:
		var sv = view.views.get(s.idx)
		if sv == null:
			continue
		view.views.erase(s.idx)
		disp.board[s.idx] = 0
		disp.counts[s.player] -= 1
		# Keep the dying stone drawable while it fades: park it under a fresh key.
		var key: int = 1000 + int(s.idx) + (Time.get_ticks_msec() % 997) * 100
		view.views[key] = sv
		var col: Color = _owner_col(s.player)
		view.burst(sv.pos, col)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sv, "scale", 0.15, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(sv, "alpha", 0.0, 0.5)
		tw.chain().tween_callback(func(): view.views.erase(key))
		longest = tw
		_log("%s's stone on %s %s." % [_owner_name(s.player), _cell_name(s.idx), verb], col)
	if longest != null:
		await longest.finished


## After an animation, make sure every live stone sits where the rules say.
func _sync_views() -> void:
	for k in view.views.keys():
		if k >= 1000:
			continue
		if state.board[k] == 0:
			view.views.erase(k)
	for i in state.board.size():
		if state.board[i] != 0 and not view.views.has(i):
			_spawn_view(i, state.board[i])


# ------------------------------------------------------------------ screenshots (dev aid)

func _shot_mode() -> void:
	# `godot --path gnomon -- --shots` saves PNGs of a few screens, for checking the UI.
	view.show_help = false
	await get_tree().create_timer(0.6).timeout
	_save_shot("shot_start")
	view.show_help = true
	await get_tree().create_timer(0.2).timeout
	_save_shot("shot_help")
	view.show_help = false
	vs_ai = false
	_new_game()
	# A hand-built middlegame: sun south-east.
	state.board.fill(0)
	state.counts = [0, 0, 0]
	state.sun = 3
	state.ring = 0
	state.round_no = 5
	for st in [[2, 2, 1], [3, 3, 2], [5, 2, 1], [4, 1, 2], [1, 4, 1], [1, 5, 2], [4, 5, 1], [6, 4, 2], [2, 4, 1]]:
		state.board[st[1] * 7 + st[0]] = st[2]
		state.counts[st[2]] += 1
	state.turn = 1
	disp = state.clone()
	view.state = disp
	view.sun_t = float(state.sun)
	_rebuild_views()
	_begin_turn()
	_select(4 * 7 + 2)
	view.hover = 3 * 7 + 3
	await get_tree().create_timer(0.4).timeout
	_save_shot("shot_mid")
	get_tree().quit()


func _stress_mode() -> void:
	# `godot --path gnomon -- --stress`: drives the real click handlers, and
	# interrupts animations and AI turns with undo / new game, to catch crashes.
	view.show_help = false
	vs_ai = true
	human_side = 1
	level = 1
	_new_game()
	var played := 0
	for i in 14:
		var guard := 0
		while (busy or not _is_human_turn()) and guard < 100 and state.winner == 0:
			await get_tree().create_timer(0.1).timeout
			guard += 1
		if state.winner != 0:
			_new_game()
			continue
		for idx in state.board.size():
			if state.board[idx] == state.turn and not state.moves_for(idx).is_empty():
				_on_cell_clicked(idx)
				_on_cell_clicked(state.moves_for(idx)[0])
				played += 1
				break
		# Interrupt at different moments: mid-slide, mid-eclipse, mid-AI-think.
		await get_tree().create_timer(0.12 * (i % 5)).timeout
		if i % 4 == 2:
			_undo()
		elif i % 7 == 6:
			_new_game()
		elif i % 5 == 3:
			_on_button("level")
	await get_tree().create_timer(1.0).timeout
	print("STRESS finished without crashing: moves=%d plies=%d" % [played, history.size()])
	get_tree().quit()


func _autoplay_mode() -> void:
	# `godot --path gnomon -- --autoplay`: watch the computer play itself to the
	# end through the real UI, saving a few frames. Used to test the event flow.
	_autoplay = true
	view.show_help = false
	level = 1
	ai.depth = 2
	_new_game()
	var shots := 0
	var t0 := Time.get_ticks_msec()
	while state.winner == 0 and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(1.5).timeout
		if shots < 3 and state.round_no >= 4 + shots * 5:
			_save_shot("auto_%d" % shots)
			shots += 1
	await get_tree().create_timer(1.8).timeout
	_save_shot("auto_end")
	print("AUTOPLAY finished: winner=%d plies=%d round=%d counts=%s" % [state.winner, history.size(), state.round_no, state.counts])
	get_tree().quit()


func _save_shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("GNOMON_SHOT_DIR")
	if dir == "":
		dir = "/tmp"
	img.save_png("%s/%s.png" % [dir, name])
