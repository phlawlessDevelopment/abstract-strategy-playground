extends Control
## All board drawing and pointer/navigation input; no rules live here.

signal move_chosen(move: Vector2i)
signal preview_changed(move: Vector2i)
signal selection_changed(lantern: int)

const Rules = preload("res://scripts/rules.gd")
const SUN = preload("res://art/sunburst.png")
const DISC = preload("res://art/solid_disc.png")
const DIAMOND = preload("res://art/filled_diamond.png")
const INK = Color("0c141b")
const TILE = Color("14232d")
const LINE = Color("29404a")
const GOLD = Color("edd39a")
const EMBER = Color("f29b7c")
const JADE = Color("7ad5c5")
const MUTED = Color("7e99a4")

var rules: RefCounted
var state: Rules.Position
var selected: int = -1
var legal := PackedInt32Array()
var hover_cell: int = -1
var preview: Rules.Position
var show_rays: bool = true
var locked: bool = false
var last_from: int = -1
var last_to: int = -1
var hinted_move := Vector2i(-1, -1)
var moving: int = -1
var motion_from := Vector2.ZERO
var motion_t: float = 1.0
var animation: Tween
var keyboard_mode: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void: _hover(-1))
	resized.connect(queue_redraw)

func set_position_state(value: Rules.Position) -> void:
	state = value
	selected = -1
	legal.clear()
	hover_cell = -1
	preview = null
	hinted_move = Vector2i(-1, -1)
	if animation and animation.is_running():
		animation.kill()
	moving = -1
	queue_redraw()

func hex_size() -> float:
	return minf(size.x / 13.4, size.y / 11.8)

func center(cell: int) -> Vector2:
	var axial: Vector2i = rules.cells[cell]
	var radius := hex_size()
	return size * Vector2(0.5, 0.49) + Vector2(
		sqrt(3.0) * (axial.x + axial.y * 0.5), axial.y * 1.5) * radius

func _polygon(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for side in 6:
		points.append(at + Vector2.from_angle(deg_to_rad(60.0 * side - 30.0)) * radius)
	return points

func _draw() -> void:
	if state == null:
		return
	var radius := hex_size()
	var shown: Rules.Position = preview if preview != null else state
	var lit: PackedByteArray = rules.illuminated(shown)
	# A quiet outer frame keeps the cells legible without a heavy checkerboard.
	for ring in [3.62, 3.75]:
		var outer := PackedVector2Array()
		for side in 6:
			outer.append(size * Vector2(0.5, 0.49) + Vector2.from_angle(deg_to_rad(side * 60.0)) * radius * ring * sqrt(3.0))
		outer.append(outer[0])
		draw_polyline(outer, Color(LINE, 0.27), 1.0, true)
	for cell in rules.cells.size():
		var at := center(cell)
		var tile_color := TILE
		if cell in legal:
			tile_color = Color("1d343b")
		if cell == hover_cell and cell in legal:
			tile_color = Color("375049")
		var polygon := _polygon(at, radius - 3.0)
		draw_colored_polygon(polygon, tile_color)
		polygon.append(polygon[0])
		draw_polyline(polygon, Color(LINE, 0.8), 1.0, true)
		if cell in legal:
			draw_circle(at, 4.0, Color(GOLD, 0.65), true, -1, true)
		elif shown.stones[cell] == 0 and not cell in shown.lanterns:
			draw_circle(at, 1.4, Color(MUTED, 0.22), true, -1, true)
	if show_rays:
		_draw_rays(shown)
	if selected >= 0:
		draw_arc(center(state.lanterns[selected]), radius * 0.68, 0, TAU, 48, GOLD, 1.8, true)
	if preview != null:
		var start := center(state.lanterns[selected])
		var finish := center(hover_cell)
		draw_line(start, finish, Color(GOLD, 0.6), 2.0, true)
		var direction := (finish - start).normalized()
		var tip := finish - direction * radius * 0.44
		draw_line(tip, tip - direction.rotated(0.6) * 12, GOLD, 2.0, true)
		draw_line(tip, tip - direction.rotated(-0.6) * 12, GOLD, 2.0, true)
	for cell in rules.cells.size():
		var owner: int = shown.stones[cell]
		if owner == 0:
			continue
		var color := EMBER if owner == 1 else JADE
		var is_lit: bool = lit[cell] != 0
		var at := center(cell)
		var tint := color if is_lit else color.darkened(0.57)
		var token_size: float = radius * 1.03
		if cell == last_from and moving >= 0:
			tint.a = motion_t
		draw_circle(at + Vector2(0, 3), radius * 0.39, Color(INK, 0.8), true, -1, true)
		var texture: Texture2D = DISC if owner == 1 else DIAMOND
		draw_texture_rect(texture, Rect2(at - Vector2.ONE * token_size / 2, Vector2.ONE * token_size), false, tint)
		if is_lit:
			draw_arc(at, radius * 0.51, 0, TAU, 36, Color(color, 0.58), 1.4, true)
			draw_circle(at, 2.2, INK, true, -1, true)
		else:
			draw_line(at + Vector2(-4, 0), at + Vector2(4, 0), Color(INK, 0.8), 2.0, true)
		if cell == last_from:
			draw_arc(at, radius * 0.64, -0.4, 0.4, 12, Color(color, 0.9), 2.0, true)
			draw_arc(at, radius * 0.64, PI - 0.4, PI + 0.4, 12, Color(color, 0.9), 2.0, true)
	for lantern in shown.lanterns.size():
		var at := center(shown.lanterns[lantern])
		if moving == lantern and preview == null:
			at = motion_from.lerp(at, motion_t)
		_draw_lantern(at, radius, lantern, shown == state)
	if hinted_move.x >= 0:
		var at := center(hinted_move.y)
		draw_arc(at, radius * 0.65, 0, TAU, 48, EMBER if state.player == 1 else JADE, 2.5, true)
		var font := ThemeDB.fallback_font
		draw_string(font, at + Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD)
	# Axial coordinates make move history and keyboard testing unambiguous.
	var font := ThemeDB.fallback_font
	for cell in rules.cells.size():
		var axial: Vector2i = rules.cells[cell]
		if axial.x == maxi(-3, -3 - axial.y):
			draw_string(font, center(cell) + Vector2(-radius - 18, 5), str(axial.y + 4),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	for q in range(-3, 4):
		var r: int = maxi(-3, -3 - q)
		var cell: int = rules.indices[Vector2i(q, r)]
		draw_string(font, center(cell) + Vector2(-4, -radius - 10), String.chr(q + 68),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)

func _draw_rays(shown: Rules.Position) -> void:
	var pieces: PackedByteArray = rules.occupied(shown)
	var radius := hex_size()
	for lantern in shown.lanterns:
		for ray in rules.rays[lantern]:
			if ray.is_empty():
				continue
			var endpoint: int = ray[-1]
			var reaches_stone: bool = false
			for cell in ray:
				endpoint = cell
				if pieces[cell] != 0:
					reaches_stone = pieces[cell] < 3
					break
			var start := center(lantern)
			var finish := center(endpoint)
			var direction := (finish - start).normalized()
			var color := Color(GOLD, 0.22 if reaches_stone else 0.09)
			draw_line(start + direction * radius * 0.35, finish, Color(GOLD, 0.025), 12.0, true)
			draw_line(start + direction * radius * 0.35, finish, color, 1.4, true)

func _draw_lantern(at: Vector2, radius: float, index: int, real_state: bool) -> void:
	var can_move: bool = not rules.destinations(state, index).is_empty()
	var tint := GOLD if can_move else GOLD.darkened(0.4)
	draw_circle(at, radius * 0.61, Color(GOLD, 0.035), true, -1, true)
	draw_circle(at, radius * 0.49, Color(GOLD, 0.06), true, -1, true)
	draw_circle(at, radius * 0.32, INK, true, -1, true)
	var icon_size: float = radius * 1.13
	draw_texture_rect(SUN, Rect2(at - Vector2.ONE * icon_size / 2, Vector2.ONE * icon_size), false, tint)
	draw_circle(at, radius * 0.14, tint, true, -1, true)
	if selected == -1 and hover_cell == state.lanterns[index] and not locked and real_state:
		draw_arc(at, radius * 0.68, 0, TAU, 48, GOLD, 1.5, true)
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(-3.5, radius * 0.84), str(index + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tint)

func _gui_input(event: InputEvent) -> void:
	if locked or state == null:
		return
	if event is InputEventMouseMotion:
		keyboard_mode = false
		_hover(_cell_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			select(-1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_click(_cell_at(event.position))

func _cell_at(point: Vector2) -> int:
	var nearest: int = -1
	var distance: float = hex_size() * 0.9
	for cell in rules.cells.size():
		var d: float = point.distance_to(center(cell))
		if d < distance:
			nearest = cell
			distance = d
	return nearest

func _click(cell: int) -> void:
	if selected >= 0 and cell in legal:
		move_chosen.emit(Vector2i(selected, cell))
		return
	var lantern: int = state.lanterns.find(cell)
	if lantern >= 0:
		select(-1 if selected == lantern else lantern)
	else:
		select(-1)

func select(lantern: int) -> void:
	selected = lantern
	legal = rules.destinations(state, selected)
	preview = null
	hover_cell = -1
	selection_changed.emit(selected)
	preview_changed.emit(Vector2i(-1, -1))
	queue_redraw()

func _hover(cell: int) -> void:
	if hover_cell == cell:
		return
	hover_cell = cell
	preview = null
	var move := Vector2i(-1, -1)
	if selected >= 0 and cell in legal:
		move = Vector2i(selected, cell)
		preview = rules.apply_legal(state, move)
	preview_changed.emit(move)
	if not locked:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if cell in legal or cell in state.lanterns else Control.CURSOR_ARROW
	queue_redraw()

func navigate(step: int) -> void:
	keyboard_mode = true
	if selected == -1:
		for lantern in 3:
			if not rules.destinations(state, lantern).is_empty():
				select(lantern)
				break
	if not legal.is_empty():
		var index: int = legal.find(hover_cell)
		_hover(legal[posmod(index + step, legal.size())])

func accept() -> void:
	if selected == -1:
		navigate(1)
	elif hover_cell in legal:
		move_chosen.emit(Vector2i(selected, hover_cell))
	else:
		navigate(1)

func animate_move(lantern: int, origin: int) -> Tween:
	moving = lantern
	motion_from = center(origin)
	motion_t = 0.0
	animation = create_tween()
	animation.tween_method(func(t: float) -> void:
		motion_t = t
		queue_redraw(), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.finished.connect(func() -> void:
		moving = -1
		queue_redraw())
	return animation
