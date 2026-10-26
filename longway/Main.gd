extends Control

const Rules = preload("res://Rules.gd")
const AMBER := Color("f1b96a")
const TEAL := Color("72d8c8")
const INK := Color("111d29")
const BOARD_CENTER := Vector2(392, 402)
const HEX_SIZE := 55.0

@onready var panel: PanelContainer = $SidePanel
@onready var turn_label: Label = $SidePanel/VBox/TurnLabel
@onready var status_label: Label = $SidePanel/VBox/StatusLabel
@onready var amber_vault: Label = $SidePanel/VBox/AmberVault
@onready var teal_vault: Label = $SidePanel/VBox/TealVault
@onready var counter: Label = $SidePanel/VBox/Counter
@onready var mode_button: Button = $SidePanel/VBox/ModeButton
@onready var undo_button: Button = $SidePanel/VBox/UndoButton
@onready var restart_button: Button = $SidePanel/VBox/RestartButton

var board: Array[Vector2i] = Rules.cells()
var path: Array[int] = []
var played: Array[Dictionary] = []
var used_vault: Array[bool] = [false, false]
var current_player := 0
var winner := -1
var solo := false
var hover := -1
var generation := 0


func _ready() -> void:
	_style_ui()
	mode_button.pressed.connect(_toggle_mode)
	undo_button.pressed.connect(_undo)
	restart_button.pressed.connect(_new_game)
	_new_game()


func _style_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("172632")
	panel_style.border_color = Color("344956")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.set_content_margin_all(17)
	panel.add_theme_stylebox_override("panel", panel_style)
	for button in [mode_button, undo_button, restart_button]:
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("e9ede4"))
		button.add_theme_color_override("font_hover_color", Color("ffffff"))
		for state in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("2a424c") if state == "normal" else Color("3b6970")
			box.set_corner_radius_all(10)
			box.set_content_margin_all(6)
			button.add_theme_stylebox_override(state, box)


func _new_game() -> void:
	generation += 1
	path = [board.find(Vector2i.ZERO)]
	played.clear()
	used_vault = [false, false]
	current_player = 0
	winner = -1
	hover = -1
	_refresh()


func _toggle_mode() -> void:
	solo = not solo
	mode_button.text = "Mode: vs Wayfinder" if solo else "Mode: two players"
	_new_game()


func _undo() -> void:
	if played.is_empty():
		return
	generation += 1
	var count := 1
	if solo and current_player == 0 and played.size() >= 2:
		count = 2
	for i in count:
		played.pop_back()
	_rebuild_from_history()
	_refresh()


func _rebuild_from_history() -> void:
	path = [board.find(Vector2i.ZERO)]
	used_vault = [false, false]
	current_player = 0
	winner = -1
	for move in played:
		Rules.apply_move(path, used_vault, current_player, move)
		current_player = 1 - current_player


func _play(move: Dictionary) -> void:
	if winner >= 0:
		return
	played.append(move)
	Rules.apply_move(path, used_vault, current_player, move)
	current_player = 1 - current_player
	if Rules.legal_moves(path, used_vault, current_player, board).is_empty():
		winner = 1 - current_player
	_refresh()
	if solo and current_player == 1 and winner < 0:
		var planned_generation := generation
		var timer := get_tree().create_timer(0.38)
		timer.timeout.connect(func(): _ai_turn(planned_generation))


func _ai_turn(planned_generation: int) -> void:
	if planned_generation != generation or winner >= 0 or current_player != 1:
		return
	_play(Rules.choose_move(path, used_vault, 1, board))


func _refresh() -> void:
	if winner >= 0:
		turn_label.text = "%s wins!" % _name(winner)
		status_label.text = "%s has no way forward. Press New game to play again." % _name(current_player)
	else:
		turn_label.text = "%s to move" % _name(current_player)
		if solo and current_player == 1:
			status_label.text = "Wayfinder is finding a route…"
		else:
			status_label.text = "Choose a glowing hex beside the white head. Ringed hexes use your vault."
	turn_label.add_theme_color_override("font_color", AMBER if (winner if winner >= 0 else current_player) == 0 else TEAL)
	status_label.add_theme_color_override("font_color", Color("b8c7c7"))
	amber_vault.text = "Amber vault: %s" % ("SPENT" if used_vault[0] else "READY")
	teal_vault.text = "Teal vault: %s" % ("SPENT" if used_vault[1] else "READY")
	amber_vault.add_theme_color_override("font_color", AMBER.darkened(0.48) if used_vault[0] else AMBER)
	teal_vault.add_theme_color_override("font_color", TEAL.darkened(0.48) if used_vault[1] else TEAL)
	counter.text = "%d of 18 moves made" % played.size()
	undo_button.disabled = played.is_empty()
	queue_redraw()


func _name(player: int) -> String:
	return "Amber" if player == 0 else "Teal"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var found := _cell_at(event.position)
		if found != hover:
			hover = found
			queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if winner >= 0 or (solo and current_player == 1):
			return
		var clicked := _cell_at(event.position)
		for move in Rules.legal_moves(path, used_vault, current_player, board):
			if move.to == clicked:
				_play(move)
				return


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_new_game()
		elif event.keycode == KEY_U:
			_undo()


func _cell_at(point: Vector2) -> int:
	var nearest := -1
	var distance := 48.0
	for i in board.size():
		var d := point.distance_to(_position(board[i]))
		if d < distance:
			distance = d
			nearest = i
	return nearest


func _position(cell: Vector2i) -> Vector2:
	return BOARD_CENTER + Vector2(sqrt(3.0) * (float(cell.x) + float(cell.y) / 2.0), 1.5 * float(cell.y)) * HEX_SIZE


func _hex(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw() -> void:
	draw_rect(Rect2(Vector2(39, 139), Vector2(716, 527)), Color("101c28"), true)
	draw_rect(Rect2(Vector2(39, 139), Vector2(716, 527)), Color("293f4b"), false, 2.0)
	var legal: Array[Dictionary] = []
	if winner < 0:
		legal = Rules.legal_moves(path, used_vault, current_player, board)
	for i in board.size():
		var center := _position(board[i])
		var occupied := path.find(i)
		var fill := Color("203440")
		if occupied == 0:
			fill = Color("4a5b60")
		elif occupied > 0:
			fill = (AMBER if occupied % 2 == 1 else TEAL).darkened(0.46)
		var possible := false
		var vault := false
		for move in legal:
			if move.to == i:
				possible = true
				vault = move.vault
		if possible and not (solo and current_player == 1):
			fill = (AMBER if current_player == 0 else TEAL).darkened(0.55 if i == hover else 0.72)
		draw_colored_polygon(_hex(center, HEX_SIZE - 3), Color("0c151f"))
		draw_colored_polygon(_hex(center, HEX_SIZE - 7), fill)
		if possible and not (solo and current_player == 1):
			var mark := AMBER if current_player == 0 else TEAL
			draw_arc(center, 20 if vault else 9, 0, TAU, 32, mark, 3.5, true)
			if vault:
				draw_arc(center, 29, 0, TAU, 32, mark.darkened(0.35), 2.0, true)
	for i in range(1, path.size()):
		var a := _position(board[path[i - 1]])
		var b := _position(board[path[i]])
		var stroke := AMBER if i % 2 == 1 else TEAL
		var segment: PackedVector2Array = [a, b]
		if played[i - 1].vault:
			var sideways := (b - a).orthogonal().normalized() * 26.0
			segment = [a, a.lerp(b, 0.5) + sideways, b]
		draw_polyline(segment, INK, 16.0, true)
		draw_polyline(segment, stroke, 7.0, true)
	for i in path.size():
		var center := _position(board[path[i]])
		if i == path.size() - 1:
			draw_circle(center, 22, Color("f8f2db"), true, -1.0, true)
			draw_arc(center, 27, 0, TAU, 40, Color("f8f2db"), 2.0, true)
		elif i == 0:
			draw_circle(center, 7, Color("d1d3bf"), true, -1.0, true)
		else:
			draw_circle(center, 7, AMBER if i % 2 == 1 else TEAL, true, -1.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(61, 178), "THE ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("829b9d"))
	draw_string(font, Vector2(61, 640), "DOT = STEP     RING = VAULT     WHITE = HEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("829b9d"))
