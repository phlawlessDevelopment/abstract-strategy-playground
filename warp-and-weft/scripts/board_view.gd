class_name WWBoardView
extends Control
## Draws the board and turns the mouse into cell_clicked / cell_hovered.
## It only *reads* the rules object; all game decisions live in main.gd / rules.gd.

signal cell_clicked(cell: int)
signal cell_hovered(cell: int)   # -1 when the mouse is over no cell

const PITCH := 96.0   # distance between cell centres
const CELL := 88.0    # cell size (the rest is gap)
const PAD := 14.0     # tray margin

const COL_WEFT := Color("#b5402f")   # madder red: horizontal threads
const COL_WARP := Color("#2d4f8f")   # indigo: vertical threads
const INK := Color("#2a2521")
const LINEN := Color("#f6efdd")
const TRAY := Color("#d9cdb1")
const GOLD := Color("#e2a72e")
const SLATE := Color("#5a524c")

const TEX_FRAME := preload("res://art/rounded_square.png")
const TEX_WEFT := preload("res://art/parallel_lines.png")
const TEX_WARP := preload("res://art/vertical_lines.png")
const TEX_SHUTTLE := preload("res://art/lozenge.png")
const TEX_RING := preload("res://art/open_ring.png")
const TEX_DISC := preload("res://art/solid_disc.png")

var rules: WWRules
var hover: int = -1
var hints: bool = true          # ring the opponent's best reply when previewing a move
var can_click: bool = false     # a human may move right now
var banner_title: String = ""   # game-over banner; empty = none
var banner_sub: String = ""
var banner_color: Color = INK
var shuttle_pos: Vector2 = Vector2.ZERO   # animated centre of the shuttle

var _floaters: Array = []       # {pos, text, color, t}
var _clock: float = 0.0
var _fill := StyleBoxFlat.new()
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fill.set_corner_radius_all(14)
	_fill.anti_aliasing = true


func board_size(n: int = 7) -> float:
	return (n - 1) * PITCH + CELL + 2.0 * PAD


func set_rules(r: WWRules) -> void:
	rules = r
	custom_minimum_size = Vector2.ONE * board_size(r.n)
	size = custom_minimum_size
	snap_shuttle()
	hover = -1
	banner_title = ""
	_floaters.clear()


func snap_shuttle() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	shuttle_pos = cell_center(rules.shuttle)


func cell_center(i: int) -> Vector2:
	return cell_rect(i).get_center()


func cell_rect(i: int) -> Rect2:
	var r := i / rules.n
	var c := i % rules.n
	return Rect2(Vector2(PAD + c * PITCH, PAD + r * PITCH), Vector2(CELL, CELL))


func cell_at(p: Vector2) -> int:
	var half_gap := (PITCH - CELL) / 2.0
	var c := int(floor((p.x - PAD + half_gap) / PITCH))
	var r := int(floor((p.y - PAD + half_gap) / PITCH))
	if c < 0 or r < 0 or c >= rules.n or r >= rules.n:
		return -1
	return r * rules.n + c


## Slide the shuttle to `to`, pop the score, and remember it for the trail.
func animate_move(to: int, who: int, gain: int) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "shuttle_pos", cell_center(to), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var col := COL_WEFT if who == WWRules.WEFT else COL_WARP
	_floaters.append({"pos": cell_center(to), "text": "%+d" % gain, "color": col, "t": 0.0})


func _process(delta: float) -> void:
	_clock += delta
	for f in _floaters:
		f["t"] += delta
	_floaters = _floaters.filter(func(f): return f["t"] < 1.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if rules == null:
		return
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != hover:
			hover = c
			cell_hovered.emit(c)
			_update_cursor()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if banner_title != "":
			banner_title = ""   # first click after the game ends just reveals the board
			return
		var c := cell_at(event.position)
		if c >= 0:
			cell_clicked.emit(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != -1:
		hover = -1
		cell_hovered.emit(-1)
		_update_cursor()


func refresh_cursor() -> void:
	_update_cursor()


func _update_cursor() -> void:
	var legal := can_click and hover >= 0 and rules != null and hover in rules.moves()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if legal else Control.CURSOR_ARROW


# --- drawing ---------------------------------------------------------------

func _who_color(who: int) -> Color:
	return COL_WEFT if who == WWRules.WEFT else COL_WARP


func _who_tex(who: int) -> Texture2D:
	return TEX_WEFT if who == WWRules.WEFT else TEX_WARP


func _tile_color(v: int) -> Color:
	if v < 0:
		return SLATE.lerp(Color("#3b3531"), clampf(-v / 3.0, 0.0, 1.0))
	return LINEN.lerp(GOLD, pow(clampf(v / 9.0, 0.0, 1.0), 0.85))


## A band along the row (Weft) or column (Warp) that passes through `at`.
func _band_rect(at: int, who: int) -> Rect2:
	var s := board_size(rules.n)
	var rc := cell_rect(at)
	if who == WWRules.WEFT:
		return Rect2(PAD - 8.0, rc.position.y - 7.0, s - 2.0 * PAD + 16.0, CELL + 14.0)
	return Rect2(rc.position.x - 7.0, PAD - 8.0, CELL + 14.0, s - 2.0 * PAD + 16.0)


func _draw_band(rect: Rect2, col: Color, alpha: float) -> void:
	_fill.bg_color = Color(col, alpha)
	_fill.set_corner_radius_all(20)
	draw_style_box(_fill, rect)
	_fill.set_corner_radius_all(14)


func _draw_text(text: String, centre: Vector2, size: int, col: Color) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(centre.x - w / 2.0, centre.y + size * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	if rules == null:
		return
	var over := rules.is_over()
	var mover := rules.turn
	var mv := rules.moves()
	var legal := {}
	for c in mv:
		legal[c] = true

	# Who took each used cell (the start cell has no owner).
	var owner := {}
	for h in rules.history:
		owner[h["to"]] = h["who"]

	# Tray.
	_fill.bg_color = TRAY
	_fill.set_corner_radius_all(26)
	draw_style_box(_fill, Rect2(Vector2.ZERO, Vector2.ONE * board_size(rules.n)))
	_fill.set_corner_radius_all(14)

	# The lane the player to move may use, and (when previewing) the lane they would hand over.
	if not over:
		_draw_band(_band_rect(rules.shuttle, mover), _who_color(mover), 0.16)
	var preview := can_click and hover >= 0 and legal.has(hover)
	var reply: PackedInt32Array = PackedInt32Array()
	if preview:
		reply = rules.reply_lane(hover, mover)
		_draw_band(_band_rect(hover, 1 - mover), _who_color(1 - mover), 0.13)

	# Cells.
	for i in rules.cells:
		var rc := cell_rect(i)
		var used := (rules.mask >> i) & 1 == 1
		if used:
			_draw_used(i, rc, owner)
		else:
			_fill.bg_color = _tile_color(rules.values[i])
			if over:
				_fill.bg_color = _fill.bg_color.lerp(TRAY, 0.55)
			draw_style_box(_fill, rc)
			draw_texture_rect(TEX_FRAME, rc.grow(1.0), false, Color(INK, 0.35 if not over else 0.18))

	# Trail the shuttle has woven, newest strongest.
	var pts: Array = []
	if rules.history.size() > 0:
		pts.append(cell_center(rules.history[0]["from"]))
	for h in rules.history:
		pts.append(cell_center(h["to"]))
	var segs: int = rules.history.size()
	for k in segs:
		var who: int = rules.history[k]["who"]
		var age := float(k + 1) / float(maxi(segs, 1))
		var newest := k == segs - 1
		draw_line(pts[k], pts[k + 1], Color(_who_color(who), 0.9 if newest else lerpf(0.10, 0.45, age)), 5.0 if newest else 3.0, true)

	# Numbers on unused cells (drawn above the trail so they stay readable).
	for i in rules.cells:
		if (rules.mask >> i) & 1 == 1:
			continue
		var v := rules.values[i]
		var col := INK if v >= 0 else Color("#f3ead6")
		if over:
			col = Color(col, 0.55)
		_draw_text(str(v), cell_rect(i).get_center(), 34 + int(clampf(v, 0.0, 9.0) * 0.9), col)

	# Lane cells: threads of the mover's colour.
	if not over:
		for c in mv:
			var rc := cell_rect(c)
			draw_texture_rect(_who_tex(mover), rc.grow(-3.0), false, Color(_who_color(mover), 0.38))
			draw_texture_rect(TEX_FRAME, rc.grow(3.0), false, Color(_who_color(mover), 0.95))

	# Preview of the opponent's reply.
	if preview:
		var best := -1000
		for c in reply:
			best = maxi(best, rules.values[c])
		for c in reply:
			var rc := cell_rect(c)
			draw_texture_rect(TEX_FRAME, rc.grow(2.0), false, Color(_who_color(1 - mover), 0.85))
			if hints and rules.values[c] == best:
				draw_texture_rect(TEX_RING, rc.grow(6.0), false, _who_color(1 - mover))
		var rh := cell_rect(hover)
		draw_texture_rect(TEX_FRAME, rh.grow(7.0), false, _who_color(mover))
		draw_texture_rect(TEX_FRAME, rh.grow(9.0), false, Color(_who_color(mover), 0.5))

	_draw_shuttle(over, mover)

	for f in _floaters:
		var a := 1.0 - float(f["t"])
		var p: Vector2 = f["pos"] + Vector2(0, -22.0 - 46.0 * float(f["t"]))
		_draw_text(f["text"], p + Vector2(1.5, 1.5), 40, Color(0, 0, 0, 0.25 * a))
		_draw_text(f["text"], p, 40, Color(f["color"], a))

	if banner_title != "":
		_draw_banner()


func _draw_used(i: int, rc: Rect2, owner: Dictionary) -> void:
	if not owner.has(i):
		# The starting cell.
		_fill.bg_color = Color(LINEN, 0.55)
		draw_style_box(_fill, rc)
		draw_texture_rect(TEX_RING, rc.grow(-22.0), false, Color(INK, 0.35))
		return
	var who: int = owner[i]
	var col := _who_color(who)
	_fill.bg_color = Color(col, 0.16)
	draw_style_box(_fill, rc)
	draw_texture_rect(_who_tex(who), rc.grow(-3.0), false, Color(col, 0.55))
	draw_texture_rect(TEX_FRAME, rc.grow(1.0), false, Color(col, 0.5))
	var v := rules.values[i]
	# A little tag with what was taken, so the board reads as a record of the game.
	var tag := rc.get_center()
	_fill.bg_color = Color(LINEN, 0.92)
	_fill.set_corner_radius_all(10)
	draw_style_box(_fill, Rect2(tag - Vector2(22, 14), Vector2(44, 28)))
	_fill.set_corner_radius_all(14)
	_draw_text("%+d" % v, tag, 20, col)


func _draw_shuttle(over: bool, mover: int) -> void:
	var p := shuttle_pos
	var horizontal := true
	if rules.history.size() > 0:
		horizontal = rules.history[-1]["who"] == WWRules.WEFT
	# A pulsing ring in the colour of whoever moves next.
	if not over:
		var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
		var rs := 82.0 + 5.0 * pulse
		draw_texture_rect(TEX_RING, Rect2(p - Vector2.ONE * rs / 2.0, Vector2.ONE * rs), false, Color(_who_color(mover), 0.55 + 0.35 * pulse))
	# The shuttle: a lens pointing along the way it last travelled.
	var long_r := 30.0
	var short_r := 13.0
	var poly := PackedVector2Array()
	for k in 25:
		var t := float(k) / 24.0
		var x := lerpf(-long_r, long_r, t)
		var y := short_r * sin(t * PI)
		poly.append(Vector2(x, -y))
	for k in range(24, -1, -1):
		var t := float(k) / 24.0
		var x := lerpf(-long_r, long_r, t)
		var y := short_r * sin(t * PI)
		poly.append(Vector2(x, y))
	var ang := 0.0 if horizontal else PI / 2.0
	draw_set_transform(p, ang, Vector2.ONE)
	draw_colored_polygon(poly, INK)
	draw_texture_rect(TEX_SHUTTLE, Rect2(-Vector2.ONE * 33.0, Vector2.ONE * 66.0), false, Color(LINEN, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(TEX_DISC, Rect2(p - Vector2.ONE * 4.0, Vector2.ONE * 8.0), false, LINEN)


func _draw_banner() -> void:
	var s := board_size(rules.n)
	var rc := Rect2(Vector2(s / 2.0 - 250.0, s / 2.0 - 70.0), Vector2(500.0, 140.0))
	_fill.bg_color = Color(0, 0, 0, 0.18)
	draw_style_box(_fill, Rect2(rc.position + Vector2(0, 6), rc.size))
	_fill.bg_color = Color(LINEN, 0.97)
	draw_style_box(_fill, rc)
	_draw_text(banner_title, rc.get_center() + Vector2(0, -22), 38, banner_color)
	_draw_text(banner_sub, rc.get_center() + Vector2(0, 22), 20, INK)
	_draw_text("click to see the board", rc.get_center() + Vector2(0, 52), 15, Color(INK, 0.55))
