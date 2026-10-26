extends Control

const State = preload("res://GameState.gd")
const Opponent = preload("res://Opponent.gd")

const INK := Color("0b1420")
const PANEL := Color("132235")
const PANEL_LIGHT := Color("1b3045")
const LINE := Color("526d80")
const TEXT := Color("e9f1f0")
const MUTED := Color("9bafbd")
const AMBER := Color("ffc36e")
const TEAL := Color("65dacb")
const RED := Color("ed887e")
const BOARD_CENTER := Vector2(465, 448)
const SPACING := 145.0
const SQRT3_OVER_2 := 0.8660254

var state
var history: Array = []
var vs_ai := true
var ai_running := false
var generation := 0
var hover_node := -1
var hover_edge := -1
var moving_player := -1
var move_from := Vector2.ZERO
var move_to := Vector2.ZERO
var move_progress := 1.0:
	set(value):
		move_progress = value
		queue_redraw()
var flash_edge := -1
var cut_flash := 0.0:
	set(value):
		cut_flash = value
		queue_redraw()

var new_button: Button
var undo_button: Button
var mode_button: Button


func _ready() -> void:
	state = State.new()
	new_button = _make_button("NEW GAME    [R]", 575, AMBER)
	undo_button = _make_button("UNDO    [U]", 635, TEXT)
	mode_button = _make_button("SOLO  ·  VS COMPASS", 695, TEAL)
	new_button.pressed.connect(_new_game)
	undo_button.pressed.connect(_undo)
	mode_button.pressed.connect(_toggle_mode)
	_refresh_buttons()
	queue_redraw()


func _make_button(label: String, y: float, accent: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.position = Vector2(937, y)
	button.size = Vector2(280, 46)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.4))
	button.add_theme_stylebox_override("normal", _button_style(PANEL_LIGHT, accent.darkened(0.42)))
	button.add_theme_stylebox_override("hover", _button_style(accent, accent))
	button.add_theme_stylebox_override("pressed", _button_style(accent.darkened(0.16), accent))
	button.add_theme_stylebox_override("disabled", _button_style(PANEL, LINE.darkened(0.48)))
	add_child(button)
	return button


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _new_game() -> void:
	generation += 1
	ai_running = false
	history.clear()
	state = State.new()
	hover_node = -1
	hover_edge = -1
	moving_player = -1
	move_progress = 1.0
	flash_edge = -1
	cut_flash = 0.0
	_refresh_buttons()
	queue_redraw()


func _toggle_mode() -> void:
	vs_ai = not vs_ai
	_new_game()


func _undo() -> void:
	if history.is_empty():
		return
	var was_ai_running := ai_running
	generation += 1
	ai_running = false
	# In solo mode, undo the computer's reply and the human turn together.
	if vs_ai and history.size() >= 2 and (state.turn == 0 or was_ai_running):
		history.pop_back()
	state = history.pop_back()
	moving_player = -1
	move_progress = 1.0
	flash_edge = -1
	cut_flash = 0.0
	hover_node = -1
	hover_edge = -1
	_refresh_buttons()
	queue_redraw()


func _refresh_buttons() -> void:
	undo_button.disabled = history.is_empty()
	mode_button.text = "SOLO  ·  VS COMPASS" if vs_ai else "LOCAL  ·  TWO PLAYERS"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_new_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U:
			_undo()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if state.winner != -1 or ai_running or (vs_ai and state.turn == 1):
			return
		if state.phase == State.MOVE:
			var cell := _node_at(event.position)
			if cell >= 0 and state.legal_destinations().has(cell):
				var source: int = state.positions[state.turn]
				history.append(state.copy())
				state.step_to(cell)
				_start_move(state.turn, source, cell)
				_refresh_buttons()
				queue_redraw()
				get_viewport().set_input_as_handled()
		else:
			var edge := _edge_at(event.position)
			if edge >= 0 and state.legal_cuts().has(edge):
				_finish_cut(edge)
				get_viewport().set_input_as_handled()


func _finish_cut(edge: int) -> void:
	state.cut(edge)
	flash_edge = edge
	cut_flash = 1.0
	var tween := create_tween()
	tween.tween_property(self, "cut_flash", 0.0, 0.5)
	hover_edge = -1
	_refresh_buttons()
	queue_redraw()
	if vs_ai and state.winner == -1 and state.turn == 1:
		_run_ai()


func _run_ai() -> void:
	ai_running = true
	var this_generation := generation
	await get_tree().create_timer(0.38).timeout
	if generation != this_generation or state.turn != 1 or state.winner != -1:
		return
	var choice := Opponent.choose_turn(state)
	if choice.x < 0:
		ai_running = false
		return
	var source: int = state.positions[1]
	history.append(state.copy())
	state.step_to(choice.x)
	_start_move(1, source, choice.x)
	_refresh_buttons()
	queue_redraw()
	await get_tree().create_timer(0.32).timeout
	if generation != this_generation:
		return
	_finish_cut(choice.y)
	ai_running = false
	queue_redraw()


func _start_move(player: int, source: int, destination: int) -> void:
	moving_player = player
	move_from = _point(source)
	move_to = _point(destination)
	move_progress = 0.0
	var tween := create_tween()
	tween.tween_property(self, "move_progress", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: moving_player = -1; queue_redraw())


func _update_hover(pos: Vector2) -> void:
	var node := -1
	var edge := -1
	if not ai_running and state.winner == -1:
		if state.phase == State.MOVE:
			node = _node_at(pos)
		elif state.phase == State.CUT:
			edge = _edge_at(pos)
	if node != hover_node or edge != hover_edge:
		hover_node = node
		hover_edge = edge
		queue_redraw()


func _point(index: int) -> Vector2:
	var axial: Vector2i = state.cells[index]
	return BOARD_CENTER + Vector2((float(axial.x) + float(axial.y) * 0.5) * SPACING,
		float(axial.y) * SQRT3_OVER_2 * SPACING)


func _node_at(pos: Vector2) -> int:
	var best := -1
	var distance := 35.0
	for i in state.cells.size():
		var d := pos.distance_to(_point(i))
		if d < distance:
			best = i
			distance = d
	return best


func _edge_at(pos: Vector2) -> int:
	var best := -1
	var distance := 17.0
	for e in state.legal_cuts():
		var segment: Vector2i = state.edges[e]
		var from := _point(segment.x)
		var to := _point(segment.y)
		var t: float = clampf((pos - from).dot(to - from) / from.distance_squared_to(to), 0.0, 1.0)
		# Require a click away from either node so adjacent threads are unambiguous.
		if t < 0.18 or t > 0.82:
			continue
		var d := pos.distance_to(from.lerp(to, t))
		if d < distance:
			best = e
			distance = d
	return best


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	_draw_panel(Rect2(38, 143, 850, 620), PANEL)
	_draw_panel(Rect2(912, 143, 330, 620), PANEL)
	_draw_header()
	_draw_network()
	_draw_sidebar()
	if state.winner != -1:
		_draw_winner()


func _draw_panel(rect: Rect2, fill: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = LINE.darkened(0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	draw_style_box(style, rect)


func _label(pos: Vector2, message: String, font_size: int, color: Color = TEXT) -> void:
	draw_string(get_theme_default_font(), pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_header() -> void:
	_label(Vector2(40, 66), "SEVER", 43, TEXT)
	_label(Vector2(218, 63), "A GAME OF VANISHING PATHS", 16, MUTED)
	_label(Vector2(40, 107), "Step across a thread. Then choose one to cut behind you.", 17, MUTED)
	draw_line(Vector2(40, 126), Vector2(1240, 126), LINE.darkened(0.25), 1.0)


func _draw_network() -> void:
	_label(Vector2(63, 177), "THE NETWORK", 16, MUTED)
	_label(Vector2(735, 177), "%d / %d" % [state.threads_left(), state.edges.size()], 15, MUTED)
	for e in state.edges.size():
		var edge: Vector2i = state.edges[e]
		var a := _point(edge.x)
		var b := _point(edge.y)
		if state.intact[e] == 1:
			var color := LINE
			var width := 5.0
			if state.phase == State.CUT and state.legal_cuts().has(e) and state.winner == -1:
				color = AMBER if state.turn == 0 else TEAL
				width = 10.0 if hover_edge == e else 7.0
				draw_line(a, b, color.darkened(0.5), width + 7.0, true)
			draw_line(a, b, color, width, true)
			if state.phase == State.CUT and state.legal_cuts().has(e):
				draw_circle(a.lerp(b, 0.55), 8.0 if hover_edge == e else 6.0, color)
		else:
			draw_line(a, b, LINE.darkened(0.66), 2.0, true)
			if e == state.last_cut:
				var middle := a.lerp(b, 0.5)
				var normal := (b - a).normalized().orthogonal() * 11.0
				draw_line(middle - normal, middle + normal, RED.lightened(0.18 * cut_flash), 4.0, true)
				if cut_flash > 0.0:
					draw_circle(middle, 19.0 + 25.0 * (1.0 - cut_flash), Color(RED.r, RED.g, RED.b, cut_flash * 0.16))
	for i in state.cells.size():
		var p := _point(i)
		var available: bool = state.phase == State.MOVE and state.winner == -1 and state.legal_destinations().has(i)
		if available:
			var active_color: Color = AMBER if state.turn == 0 else TEAL
			draw_circle(p, 34.0 if hover_node == i else 31.0, Color(active_color.r, active_color.g, active_color.b, 0.18))
			draw_arc(p, 31.0, 0.0, TAU, 48, active_color, 2.5, true)
		draw_circle(p, 23.0, PANEL_LIGHT)
		draw_arc(p, 23.0, 0.0, TAU, 36, LINE, 2.0, true)
	for player in 2:
		var p := _point(state.positions[player])
		if moving_player == player and move_progress < 1.0:
			p = move_from.lerp(move_to, move_progress)
		_draw_traveler(p, player, player == state.turn and state.winner == -1)
	if state.phase == State.CUT and state.winner == -1:
		var old := _point(state.departed)
		draw_arc(old, 40.0, 0.0, TAU, 48, AMBER if state.turn == 0 else TEAL, 2.0, true)
	_label(Vector2(64, 737), "LIT POINTS = LEGAL STEPS     •     LIT THREADS = LEGAL CUTS", 15, MUTED)


func _draw_traveler(p: Vector2, player: int, active: bool) -> void:
	var color: Color = AMBER if player == 0 else TEAL
	if active:
		draw_circle(p, 38.0, Color(color.r, color.g, color.b, 0.14))
		draw_arc(p, 34.0, 0.0, TAU, 48, color, 2.2, true)
	draw_circle(p + Vector2(0, 3), 26.0, INK)
	draw_circle(p, 23.0, color)
	if player == 0:
		var diamond := PackedVector2Array([p + Vector2(0, -11), p + Vector2(9, 0), p + Vector2(0, 11), p + Vector2(-9, 0)])
		draw_colored_polygon(diamond, INK)
	else:
		draw_circle(p, 11.0, INK)
		draw_circle(p, 4.0, color)


func _draw_sidebar() -> void:
	_label(Vector2(937, 177), "TURN / STATUS", 15, MUTED)
	_draw_panel(Rect2(935, 194, 284, 125), PANEL_LIGHT)
	var acting: int = state.winner if state.winner != -1 else state.turn
	var color: Color = AMBER if acting == 0 else TEAL
	_draw_traveler(Vector2(969, 232), acting, false)
	_label(Vector2(1007, 239), "AMBER" if acting == 0 else "TEAL", 25, color)
	var phase_label := "WINS · RIVAL IS STUCK" if state.winner != -1 else ("CHOOSE A THREAD TO CUT" if state.phase == State.CUT else "STEP TO A LIT POINT")
	if vs_ai and ai_running and state.winner == -1:
		phase_label = "COMPASS IS THINKING..."
	_label(Vector2(953, 290), phase_label, 15, TEXT)
	_label(Vector2(937, 352), "HOW TO PLAY", 15, MUTED)
	_label(Vector2(937, 385), "01   MOVE", 17, color if state.phase == State.MOVE else MUTED)
	_label(Vector2(937, 410), "Step to an adjacent empty point", 16, TEXT)
	_label(Vector2(937, 433), "along an uncut thread.", 16, TEXT)
	_label(Vector2(937, 472), "02   CUT", 17, color if state.phase == State.CUT else MUTED)
	_label(Vector2(937, 497), "Cut any thread touching the point", 16, TEXT)
	_label(Vector2(937, 520), "you left, including the one crossed.", 16, TEXT)
	_label(Vector2(937, 554), "Trap your rival to win.", 16, MUTED)
	_label(Vector2(937, 755), "%d TURNS PLAYED   ·   %d THREADS REMAIN" % [state.moves_played, state.threads_left()], 12, MUTED)


func _draw_winner() -> void:
	var color: Color = AMBER if state.winner == 0 else TEAL
	draw_rect(Rect2(38, 143, 850, 620), Color(INK.r, INK.g, INK.b, 0.52))
	_draw_panel(Rect2(228, 335, 472, 202), PANEL_LIGHT)
	_label(Vector2(277, 388), "NO PATH REMAINS", 18, MUTED)
	_label(Vector2(277, 448), ("AMBER" if state.winner == 0 else "TEAL") + " WINS", 38, color)
	_label(Vector2(277, 492), "Press R or NEW GAME to play again.", 17, TEXT)
