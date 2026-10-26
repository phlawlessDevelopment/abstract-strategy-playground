extends Control

const GameState = preload("res://GameState.gd")
const VIRTUAL_SIZE := Vector2(1100, 740)
const BOARD := Vector2(340, 170)
const PITCH := 85.0
const TILE := 77.0
const INK := Color("#102026")
const PANEL := Color("#193139")
const CELL := Color("#27444b")
const PALE := Color("#ebeee3")
const MUTED := Color("#9db6b7")
const CORAL := Color("#ff806e")
const TEAL := Color("#68d6c1")
const GOLD := Color("#f7d887")

var state: GameState = GameState.new()
var selected := -1
var hovered_cell := -1
var hovered_arrow := -1
var last_action := "Choose an empty square."
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	var factor := minf(size.x / VIRTUAL_SIZE.x, size.y / VIRTUAL_SIZE.y)
	var origin := (size - VIRTUAL_SIZE * factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	_draw_header()
	_draw_side_panels()
	_draw_board()
	_draw_arrows()
	_draw_footer()
	draw_set_transform(Vector2.ZERO)


func _draw_header() -> void:
	_label("CROSSCURRENT", Vector2(54, 75), 34, PALE)
	_label("Place a stone. Shift its line. Build the strongest groups.", Vector2(54, 110), 17, MUTED)
	var badge := Rect2(837, 55, 207, 43)
	draw_rect(badge, PANEL)
	_label("TURN %02d / 20" % min(state.moves + 1, 20), Vector2(861, 83), 20, GOLD)


func _draw_side_panels() -> void:
	draw_rect(Rect2(50, 170, 220, 447), PANEL)
	draw_rect(Rect2(830, 170, 220, 447), PANEL)
	var view: Array[int] = state.board
	if selected >= 0 and hovered_arrow >= 0:
		view = state.preview_move(selected, hovered_arrow)
	var points := state.scores(view)
	_label("THE PLAYERS", Vector2(70, 207), 16, MUTED)
	_draw_player(1, 70, 250, points[0])
	_draw_player(2, 70, 368, points[1])
	draw_line(Vector2(70, 448), Vector2(250, 448), Color("#41616a"), 1.0)
	_label("HOW TO SCORE", Vector2(70, 485), 16, GOLD)
	_label("Connected stones form", Vector2(70, 518), 16, PALE)
	_label("groups. Each group scores", Vector2(70, 544), 16, PALE)
	_label("its size squared.", Vector2(70, 570), 16, PALE)
	_label("4 stones = 16 points", Vector2(70, 601), 15, MUTED)
	_label("YOUR MOVE", Vector2(850, 207), 16, MUTED)
	if state.finished:
		var result := "DRAW GAME"
		if state.winner > 0:
			result = ("CORAL" if state.winner == 1 else "TEAL") + " WINS"
		_label(result, Vector2(850, 253), 24, GOLD)
		_label("Final score", Vector2(850, 289), 16, PALE)
		_label("%d  :  %d" % points, Vector2(850, 321), 26, PALE)
		_label("Start a new game below.", Vector2(850, 374), 16, MUTED)
	else:
		var turn_color: Color = CORAL if state.player == 1 else TEAL
		_label("CORAL" if state.player == 1 else "TEAL", Vector2(850, 255), 27, turn_color)
		_label("to place and shift", Vector2(850, 284), 16, PALE)
		if selected < 0:
			_label("1. Pick an empty square", Vector2(850, 339), 16, PALE)
			_label("2. Choose an arrow", Vector2(850, 369), 16, MUTED)
		else:
			_label("1. Square chosen", Vector2(850, 339), 16, MUTED)
			_label("2. Choose an arrow", Vector2(850, 369), 16, GOLD)
			_label("Shift preview active." if hovered_arrow >= 0 else "Hover to preview.", Vector2(850, 407), 15, MUTED)
	draw_line(Vector2(850, 453), Vector2(1030, 453), Color("#41616a"), 1.0)
	_label("LAST ACTION", Vector2(850, 489), 16, MUTED)
	_label(last_action, Vector2(850, 523), 15, PALE)
	var restart := Rect2(850, 552, 180, 47)
	draw_rect(restart, Color("#35565c") if restart.has_point(_mouse_virtual()) else Color("#2b484e"))
	_label("NEW GAME   R", Vector2(870, 583), 17, PALE)


func _draw_player(owner: int, x: float, y: float, score: int) -> void:
	var color: Color = CORAL if owner == 1 else TEAL
	draw_circle(Vector2(x + 20, y + 7), 16.0, color)
	draw_circle(Vector2(x + 15, y + 2), 4.0, Color(1, 1, 1, 0.28))
	_label("CORAL" if owner == 1 else "TEAL", Vector2(x + 49, y + 5), 19, PALE)
	_label("%d" % score, Vector2(x + 47, y + 44), 34, color)
	_label("points" if selected < 0 or hovered_arrow < 0 else "preview", Vector2(x + 104, y + 42), 14, MUTED)


func _draw_board() -> void:
	draw_rect(Rect2(318, 148, 469, 469), PANEL)
	var previewing := selected >= 0 and hovered_arrow >= 0
	var cells: Array[int] = state.board
	if previewing:
		cells = state.preview_move(selected, hovered_arrow)
	var line_index := -1
	if previewing:
		line_index = int(selected / 5) if hovered_arrow < 2 else selected % 5
	for cell in range(25):
		var row := int(cell / 5)
		var column := cell % 5
		var rect := Rect2(BOARD + Vector2(column, row) * PITCH, Vector2(TILE, TILE))
		var lit := previewing and (row == line_index if hovered_arrow < 2 else column == line_index)
		var color := Color("#36555a") if lit else CELL
		if cell == hovered_cell and cells[cell] == 0 and not state.finished and not previewing:
			color = Color("#3c6064")
		draw_rect(rect, color)
		if cell == selected and not previewing:
			draw_rect(rect.grow(-2), GOLD, false, 3.0)
	# Draw connections under the stones so groups are easy to read.
	for cell in range(25):
		if cells[cell] == 0:
			continue
		var cx := cell % 5
		var cy := int(cell / 5)
		var center := _cell_center(cell)
		var color: Color = CORAL if cells[cell] == 1 else TEAL
		if cx < 4 and cells[cell + 1] == cells[cell]:
			draw_line(center, _cell_center(cell + 1), color.darkened(0.2), 10.0)
		if cy < 4 and cells[cell + 5] == cells[cell]:
			draw_line(center, _cell_center(cell + 5), color.darkened(0.2), 10.0)
	for cell in range(25):
		if cells[cell] > 0:
			_stone(_cell_center(cell), cells[cell], false)
	if selected >= 0 and not previewing:
		_stone(_cell_center(selected), state.player, true)


func _stone(center: Vector2, owner: int, ghost: bool) -> void:
	var color: Color = CORAL if owner == 1 else TEAL
	if ghost:
		color.a = 0.47
	draw_circle(center + Vector2(0, 4), 27.0, Color(0, 0, 0, 0.22 if not ghost else 0.1))
	draw_circle(center, 25.0, color)
	draw_circle(center + Vector2(-7, -7), 6.0, Color(1, 1, 1, 0.25 if not ghost else 0.1))


func _draw_arrows() -> void:
	if selected < 0 or state.finished:
		return
	for direction in range(4):
		var center := _arrow_center(direction)
		var active := direction == hovered_arrow
		draw_rect(Rect2(center - Vector2(19, 19), Vector2(38, 38)), GOLD if active else Color("#35565c"))
		var triangle: PackedVector2Array
		match direction:
			0:
				triangle = PackedVector2Array([center + Vector2(-10, 0), center + Vector2(6, -9), center + Vector2(6, 9)])
			1:
				triangle = PackedVector2Array([center + Vector2(10, 0), center + Vector2(-6, -9), center + Vector2(-6, 9)])
			2:
				triangle = PackedVector2Array([center + Vector2(0, -10), center + Vector2(-9, 6), center + Vector2(9, 6)])
			_:
				triangle = PackedVector2Array([center + Vector2(0, 10), center + Vector2(-9, -6), center + Vector2(9, -6)])
		draw_colored_polygon(triangle, INK if active else PALE)


func _draw_footer() -> void:
	_label("Choose a square, then a direction. Lines wrap around the board.", Vector2(340, 682), 16, PALE)
	_label("Click another square to change your choice. Esc cancels.", Vector2(340, 708), 14, MUTED)


func _label(message: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _cell_center(cell: int) -> Vector2:
	return BOARD + Vector2(cell % 5, int(cell / 5)) * PITCH + Vector2(TILE, TILE) * 0.5


func _arrow_center(direction: int) -> Vector2:
	var row := int(selected / 5)
	var column := selected % 5
	match direction:
		0:
			return Vector2(292, BOARD.y + row * PITCH + TILE * 0.5)
		1:
			return Vector2(811, BOARD.y + row * PITCH + TILE * 0.5)
		2:
			return Vector2(BOARD.x + column * PITCH + TILE * 0.5, 127)
		_:
			return Vector2(BOARD.x + column * PITCH + TILE * 0.5, 638)


func _mouse_virtual() -> Vector2:
	return _to_virtual(get_viewport().get_mouse_position())


func _to_virtual(window_point: Vector2) -> Vector2:
	var factor := minf(size.x / VIRTUAL_SIZE.x, size.y / VIRTUAL_SIZE.y)
	var origin := (size - VIRTUAL_SIZE * factor) * 0.5
	return (window_point - origin) / factor


func _cell_at(point: Vector2) -> int:
	for cell in range(25):
		if Rect2(BOARD + Vector2(cell % 5, int(cell / 5)) * PITCH, Vector2(TILE, TILE)).has_point(point):
			return cell
	return -1


func _arrow_at(point: Vector2) -> int:
	if selected < 0 or state.finished:
		return -1
	for direction in range(4):
		if Rect2(_arrow_center(direction) - Vector2(19, 19), Vector2(38, 38)).has_point(point):
			return direction
	return -1


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_ESCAPE:
			selected = -1
			hovered_arrow = -1
			queue_redraw()
	if event is InputEventMouseMotion:
		var point := _to_virtual(event.position)
		hovered_cell = _cell_at(point)
		hovered_arrow = _arrow_at(point)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := _to_virtual(event.position)
		if Rect2(850, 552, 180, 47).has_point(point):
			_restart()
			return
		if state.finished:
			return
		var direction := _arrow_at(point)
		if direction >= 0:
			var owner: int = state.player
			var row := int(selected / 5)
			var column := selected % 5
			if state.play(selected, direction):
				var label: String = ["left", "right", "up", "down"][direction]
				var line := "row %d" % (row + 1) if direction < 2 else "col %d" % (column + 1)
				last_action = ("Coral" if owner == 1 else "Teal") + ": " + line + " " + label + "."
				selected = -1
				hovered_arrow = -1
				queue_redraw()
			return
		var cell := _cell_at(point)
		if state.can_place(cell):
			selected = cell
			hovered_arrow = -1
			queue_redraw()


func _restart() -> void:
	state = GameState.new()
	selected = -1
	hovered_arrow = -1
	last_action = "Choose an empty square."
	queue_redraw()
