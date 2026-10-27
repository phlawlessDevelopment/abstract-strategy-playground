class_name CarBoardView
extends Control
## Careen: draws the tray, the stones, the four tilt arrows and the previews, and plays the
## slide / crush / drop animations. It reports clicks and hovers; main.gd decides what they mean.
##
## The rules object is always already up to date when an animation starts. The sprites here
## are the *displayed* state and catch up by replaying the steps CarRules.tilt() returns.

signal cell_clicked(cell: int)
signal cell_hovered(cell: int)       # -1 when the pointer leaves the tray
signal arrow_clicked(dir: int)
signal arrow_hovered(dir: int)       # -1 when none

const COL_AMBER := Color("#f2a93b")
const COL_TEAL := Color("#46c2b5")
const COL_TRAY := Color("#222935")
const COL_TRAY_EDGE := Color("#3a4556")
const COL_CELL := Color("#2c3543")
const COL_POST := Color("#8995a8")
const COL_INK := Color("#e8ecf2")
const COL_DIM := Color("#8793a6")
const COL_GOOD := Color("#7fdc92")
const COL_BAD := Color("#f2695b")

const TEX_DISC: Texture2D = preload("res://art/solid_disc.png")
const TEX_DIAMOND: Texture2D = preload("res://art/filled_diamond.png")
const TEX_RING: Texture2D = preload("res://art/open_ring.png")
const TEX_DIAMOND_LINE: Texture2D = preload("res://art/diamond.png")
const TEX_CELL: Texture2D = preload("res://art/rounded_square.png")
const TEX_OCTAGON: Texture2D = preload("res://art/octagon.png")
const TEX_HUB: Texture2D = preload("res://art/plain_hub.png")
const TEX_CHEVRON: Texture2D = preload("res://art/double_chevron.png")
const TEX_SPARK: Texture2D = preload("res://art/spark.png")
const TEX_CROSS: Texture2D = preload("res://art/small_cross.png")
const TEX_BRACKETS: Texture2D = preload("res://art/corner_brackets.png")

const TRAY_PIXELS := 516.0        # the playing area is always about this big, whatever the board size
const ARROW_LONG := 150.0
const ARROW_SHORT := 56.0

var rules: CarRules
var n: int = 6
var cs: float = 86.0                 # cell size in pixels
var origin: Vector2 = Vector2.ZERO   # top-left corner of the playing area

var sprites: Dictionary = {}         # cell -> Sprite2D currently displayed there
var stone_layer: Node2D
var overlay: Control
var fx_layer: Node2D

# What main.gd wants shown.
var can_tilt: bool = false
var can_drop: bool = false
var actor: int = 0                         # whose colour the hover ghost and highlights use
var arrow_owner: int = 0                   # whose colour the arrows wear: the tilter (you now, or them next)
var arrow_enabled: Array[bool] = [true, true, true, true]
var arrow_text: Array[String] = ["", "", "", ""]
var arrow_text_col: Array[Color] = [COL_DIM, COL_DIM, COL_DIM, COL_DIM]
var ghost: Dictionary = {}                 # {"alive": [[cell, owner], ...], "dead": [cell, ...]}
var hover_cell: int = -1
var hover_arrow: int = -1
var last_tilt_dir: int = -1
var banner_title: String = ""
var banner_sub: String = ""
var banner_color: Color = COL_INK
var banner_hidden: bool = false             # click the tray after the game to see the final position
var speed: float = 1.0                     # animation speed multiplier


func _init() -> void:
	custom_minimum_size = Vector2(720, 720)
	size = Vector2(720, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	stone_layer = Node2D.new()
	add_child(stone_layer)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	fx_layer = Node2D.new()
	add_child(fx_layer)


func set_rules(r: CarRules) -> void:
	rules = r
	n = r.w
	cs = floorf(TRAY_PIXELS / n)
	origin = (size - Vector2(n, n) * cs) / 2.0
	ghost = {}
	hover_cell = -1
	hover_arrow = -1
	last_tilt_dir = -1
	banner_title = ""
	banner_hidden = false
	sync()
	queue_redraw()


# --- geometry -------------------------------------------------------------------------

func cell_center(i: int) -> Vector2:
	return origin + Vector2((i % n) + 0.5, (i / n) + 0.5) * cs


func cell_at(p: Vector2) -> int:
	var q := (p - origin) / cs
	if q.x < 0.0 or q.y < 0.0 or q.x >= n or q.y >= n:
		return -1
	return int(q.y) * n + int(q.x)


func arrow_rect(d: int) -> Rect2:
	var board := Vector2(n, n) * cs
	var gap := 14.0
	match d:
		CarRules.Dir.N:
			return Rect2(origin.x + board.x / 2.0 - ARROW_LONG / 2.0, origin.y - gap - ARROW_SHORT, ARROW_LONG, ARROW_SHORT)
		CarRules.Dir.S:
			return Rect2(origin.x + board.x / 2.0 - ARROW_LONG / 2.0, origin.y + board.y + gap, ARROW_LONG, ARROW_SHORT)
		CarRules.Dir.W:
			return Rect2(origin.x - gap - ARROW_SHORT, origin.y + board.y / 2.0 - ARROW_LONG / 2.0, ARROW_SHORT, ARROW_LONG)
		_:
			return Rect2(origin.x + board.x + gap, origin.y + board.y / 2.0 - ARROW_LONG / 2.0, ARROW_SHORT, ARROW_LONG)


func arrow_at(p: Vector2) -> int:
	for d in 4:
		if arrow_rect(d).grow(4.0).has_point(p):
			return d
	return -1


func _col(owner: int) -> Color:
	return COL_AMBER if owner == CarRules.AMBER else COL_TEAL


func _stone_scale(owner: int) -> float:
	return cs * (0.74 if owner == CarRules.AMBER else 0.84) / 128.0


# --- sprites --------------------------------------------------------------------------

func _make_stone(owner: int, at: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TEX_DISC if owner == CarRules.AMBER else TEX_DIAMOND
	s.modulate = _col(owner)
	s.scale = Vector2.ONE * _stone_scale(owner)
	s.position = cell_center(at)
	s.set_meta("owner", owner)
	var shade := Sprite2D.new()           # a darker inner ring gives the stone some depth
	shade.texture = TEX_RING
	shade.modulate = Color(0, 0, 0, 0.30)
	shade.scale = Vector2.ONE * (0.5 if owner == CarRules.AMBER else 0.42)
	s.add_child(shade)
	var mark := Sprite2D.new()            # corner brackets: the stone that was dropped last
	mark.name = "Mark"
	mark.texture = TEX_BRACKETS
	mark.modulate = Color(1, 1, 1, 0.95)
	mark.scale = Vector2.ONE * (cs * 1.02 / 128.0) / s.scale.x
	mark.visible = false
	s.add_child(mark)
	stone_layer.add_child(s)
	return s


## Rebuild the displayed stones from the rules state (new game, undo, after animations).
func sync() -> void:
	for s in sprites.values():
		s.queue_free()
	sprites.clear()
	if rules == null:
		return
	for i in rules.cells.size():
		var v := rules.cells[i]
		if v == 1 or v == 2:
			sprites[i] = _make_stone(v - 1, i)


func clear_last_mark() -> void:
	for s in sprites.values():
		s.get_node("Mark").visible = false


func _t(seconds: float) -> float:
	return seconds / speed


## Replay the steps CarRules.tilt() returned: slides, then crushes, then slides again...
func play_tilt(steps: Array, dir: int) -> void:
	last_tilt_dir = dir
	for st in steps:
		if st["kind"] == "slide":
			await _anim_slide(st["moves"])
		else:
			await _anim_crush(st["cells"])
	sync_if_drifted()


func _anim_slide(moves: Array) -> void:
	var moving := {}
	for m in moves:
		moving[m[1]] = sprites[m[0]]
	for m in moves:
		sprites.erase(m[0])
	for j in moving:
		sprites[j] = moving[j]
	var tw := create_tween().set_parallel(true)
	for j in moving:
		var sp: Sprite2D = moving[j]
		var dist := sp.position.distance_to(cell_center(j)) / cs
		tw.tween_property(sp, "position", cell_center(j), _t(0.10 + 0.05 * dist)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	# A little squash as things come to rest.
	var tw2 := create_tween().set_parallel(true)
	for j in moving:
		var sp2: Sprite2D = moving[j]
		var base := Vector2.ONE * _stone_scale(sp2.get_meta("owner"))
		sp2.scale = base * 1.07
		tw2.tween_property(sp2, "scale", base, _t(0.09))
	await tw2.finished


func _anim_crush(cells: Array) -> void:
	var tw := create_tween().set_parallel(true)
	var doomed: Array[Sprite2D] = []
	for c in cells:
		var sp: Sprite2D = sprites[c]
		doomed.append(sp)
		sprites.erase(c)
		var owner: int = sp.get_meta("owner")
		var spark := Sprite2D.new()
		spark.texture = TEX_SPARK
		spark.position = sp.position
		spark.modulate = Color(1, 1, 1, 0.95)
		spark.scale = Vector2.ONE * 0.2
		fx_layer.add_child(spark)
		tw.tween_property(spark, "scale", Vector2.ONE * (cs * 1.5 / 128.0), _t(0.32)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, _t(0.32))
		tw.tween_callback(spark.queue_free).set_delay(_t(0.33))
		sp.modulate = Color.WHITE
		tw.tween_property(sp, "scale", Vector2.ONE * 0.05, _t(0.26)).set_delay(_t(0.10)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(sp, "modulate", _col(owner).darkened(0.2), _t(0.10))
		tw.tween_property(sp, "rotation", 1.2, _t(0.36))
	await tw.finished
	for sp in doomed:
		sp.queue_free()
	await get_tree().create_timer(_t(0.06)).timeout


func play_drop(cell: int, owner: int) -> void:
	clear_last_mark()
	var sp := _make_stone(owner, cell)
	sprites[cell] = sp
	sp.get_node("Mark").visible = true
	var base := sp.scale
	sp.scale = base * 1.8
	sp.modulate.a = 0.0
	var ring := Sprite2D.new()
	ring.texture = TEX_RING
	ring.position = sp.position
	ring.modulate = Color(_col(owner), 0.9)
	ring.scale = base * 0.8
	fx_layer.add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sp, "scale", base, _t(0.18)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 1.0, _t(0.12))
	tw.tween_property(ring, "scale", base * 2.2, _t(0.35)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, _t(0.35))
	tw.tween_callback(ring.queue_free).set_delay(_t(0.36))
	await tw.finished


## Safety net: if the displayed stones ever disagree with the rules, trust the rules.
func sync_if_drifted() -> void:
	var drift := sprites.size() != (rules.stones_on_board(0) + rules.stones_on_board(1))
	if not drift:
		for i in sprites:
			if rules.cells[i] != sprites[i].get_meta("owner") + 1:
				drift = true
				break
	if drift:
		sync()


# --- previews -------------------------------------------------------------------------

## Follow every stone through the steps of a tilt. Returns
## {"alive": [[final_cell, owner], ...], "dead": [cell the stone is standing on now, ...]}.
## `board` is the position the steps start from.
static func trace(board: PackedByteArray, steps: Array) -> Dictionary:
	var at := {}                         # current cell -> id (the cell it started on)
	for i in board.size():
		if board[i] == 1 or board[i] == 2:
			at[i] = i
	var dead := []
	for st in steps:
		if st["kind"] == "slide":
			var moved := {}
			for m in st["moves"]:
				moved[m[1]] = at[m[0]]
			for m in st["moves"]:
				at.erase(m[0])
			for j in moved:
				at[j] = moved[j]
		else:
			for c in st["cells"]:
				dead.append(at[c])
				at.erase(c)
	var alive := []
	for c in at:
		alive.append([c, board[at[c]] - 1])
	return {"alive": alive, "dead": dead}


func set_ghost(g: Dictionary) -> void:
	ghost = g
	overlay.queue_redraw()


func clear_ghost() -> void:
	if not ghost.is_empty():
		ghost = {}
		overlay.queue_redraw()


# --- input ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var a := arrow_at(event.position)
		var c := -1 if a >= 0 else cell_at(event.position)
		if a != hover_arrow:
			hover_arrow = a
			arrow_hovered.emit(a)
			queue_redraw()
		if c != hover_cell:
			hover_cell = c
			cell_hovered.emit(c)
			overlay.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var a := arrow_at(event.position)
		if a >= 0:
			arrow_clicked.emit(a)
		else:
			var c := cell_at(event.position)
			if c >= 0:
				if banner_title != "":
					banner_hidden = not banner_hidden
					overlay.queue_redraw()
				cell_clicked.emit(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if hover_arrow != -1:
			hover_arrow = -1
			arrow_hovered.emit(-1)
			queue_redraw()
		if hover_cell != -1:
			hover_cell = -1
			cell_hovered.emit(-1)
			overlay.queue_redraw()


func refresh() -> void:
	queue_redraw()
	if overlay != null:
		overlay.queue_redraw()


# --- drawing: tray, arrows ------------------------------------------------------------

func _draw() -> void:
	if rules == null:
		return
	var board := Vector2(n, n) * cs
	var tray := Rect2(origin - Vector2(14, 14), board + Vector2(28, 28))
	# Soft shadow, then the tray itself.
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.35)
	shadow.set_corner_radius_all(26)
	draw_style_box(shadow, Rect2(tray.position + Vector2(0, 7), tray.size))
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TRAY
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(3)
	sb.border_color = COL_TRAY_EDGE
	draw_style_box(sb, tray)
	for i in n * n:
		var v := rules.cells[i]
		var c := cell_center(i)
		draw_texture_rect(TEX_CELL, Rect2(c - Vector2.ONE * cs * 0.47, Vector2.ONE * cs * 0.94), false, COL_CELL)
		if v == CarRules.POST:
			_draw_post(c)
	for d in 4:
		_draw_arrow(d)


func _draw_post(c: Vector2) -> void:
	var r := cs * 0.40
	var pts := PackedVector2Array()
	for k in 8:
		var a := PI / 8.0 + k * TAU / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, COL_POST.darkened(0.35))
	draw_texture_rect(TEX_OCTAGON, Rect2(c - Vector2.ONE * r * 1.12, Vector2.ONE * r * 2.24), false, COL_POST)
	draw_texture_rect(TEX_HUB, Rect2(c - Vector2.ONE * r * 0.7, Vector2.ONE * r * 1.4), false, COL_POST.lightened(0.15))


func _draw_arrow(d: int) -> void:
	var rect := arrow_rect(d)
	var active := can_tilt and arrow_enabled[d]
	var hot := active and hover_arrow == d
	var col := _col(arrow_owner)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(14)
	fill.set_border_width_all(2)
	if active:
		fill.bg_color = col.darkened(0.55) if not hot else col.darkened(0.25)
		fill.border_color = col if hot else col.darkened(0.2)
	elif arrow_text[d] != "":
		# A forecast of the opponent's tilt (while you are choosing a drop): outline only.
		fill.bg_color = Color("#222a36")
		fill.border_color = col.darkened(0.35)
	else:
		fill.bg_color = Color("#262d39")
		fill.border_color = Color("#313b4b")
	if d == last_tilt_dir and not active:
		fill.border_color = Color("#4a566a")
	draw_style_box(fill, rect)
	# The chevron points the way the stones will slide. The sprite points down; rotate it.
	var angle: float = [PI, -PI / 2.0, 0.0, PI / 2.0][d]
	var c := rect.get_center()
	var icon := 38.0
	var tint := COL_INK if active else Color(COL_DIM, 0.45)
	var along := Vector2.ZERO
	var text_at := Vector2.ZERO
	match d:
		CarRules.Dir.N, CarRules.Dir.S:
			along = Vector2(-26, 0)
			text_at = c + Vector2(4, 0)
		CarRules.Dir.W, CarRules.Dir.E:
			along = Vector2(0, -26)
			text_at = c + Vector2(0, 28)
	var icon_at := c + (along if arrow_text[d] != "" else Vector2.ZERO)
	draw_set_transform(icon_at, angle, Vector2.ONE)
	draw_texture_rect(TEX_CHEVRON, Rect2(-Vector2.ONE * icon / 2.0, Vector2.ONE * icon), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if arrow_text[d] != "":
		var font := ThemeDB.fallback_font
		var fs := 20
		var ts := font.get_string_size(arrow_text[d], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos: Vector2
		if d == CarRules.Dir.N or d == CarRules.Dir.S:
			pos = Vector2(c.x + 4.0, c.y + fs * 0.36)
		else:
			pos = Vector2(c.x - ts.x / 2.0, c.y + 30.0 + fs * 0.36)
		draw_string(font, pos, arrow_text[d], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, arrow_text_col[d])


# --- drawing: overlay (ghosts, hover, banner) -----------------------------------------

func _draw_overlay() -> void:
	if rules == null:
		return
	# Where the stones would end up (outlines) and which would be crushed (red crosses).
	if not ghost.is_empty():
		for g in ghost["alive"]:
			var c := cell_center(g[0])
			var owner: int = g[1]
			var tex := TEX_RING if owner == CarRules.AMBER else TEX_DIAMOND_LINE
			var sz := cs * (0.82 if owner == CarRules.AMBER else 0.92)
			overlay.draw_texture_rect(tex, Rect2(c - Vector2.ONE * sz / 2.0, Vector2.ONE * sz), false, Color(_col(owner), 0.9))
		for dcell in ghost["dead"]:
			var c2 := cell_center(dcell)
			overlay.draw_circle(c2, cs * 0.40, Color(COL_BAD, 0.28))
			overlay.draw_texture_rect(TEX_CROSS, Rect2(c2 - Vector2.ONE * cs * 0.34, Vector2.ONE * cs * 0.68), false, COL_BAD)
	# A ghost of the stone you are about to drop.
	if can_drop and hover_cell >= 0 and rules.cells[hover_cell] == CarRules.EMPTY:
		var c3 := cell_center(hover_cell)
		var tex2 := TEX_DISC if actor == CarRules.AMBER else TEX_DIAMOND
		var sz2 := cs * (0.74 if actor == CarRules.AMBER else 0.84)
		overlay.draw_texture_rect(tex2, Rect2(c3 - Vector2.ONE * sz2 / 2.0, Vector2.ONE * sz2), false, Color(_col(actor), 0.55))
	# The result banner.
	if banner_title != "" and not banner_hidden:
		var tray := Rect2(origin, Vector2(n, n) * cs)
		var box := Rect2(tray.get_center() - Vector2(210, 70), Vector2(420, 140))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#12161d", 0.92)
		bg.set_corner_radius_all(22)
		bg.set_border_width_all(3)
		bg.border_color = banner_color
		overlay.draw_style_box(bg, box)
		var font := ThemeDB.fallback_font
		var ts := font.get_string_size(banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 44)
		overlay.draw_string(font, Vector2(box.get_center().x - ts.x / 2.0, box.position.y + 62), banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, banner_color)
		var ss := font.get_string_size(banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
		overlay.draw_string(font, Vector2(box.get_center().x - ss.x / 2.0, box.position.y + 102), banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, COL_INK)
