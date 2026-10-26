extends Control
## Draws Gnomon and turns mouse clicks into signals. Holds no game rules:
## everything it shows comes from fields that main.gd sets.

signal cell_clicked(idx: int)
signal button_pressed(id: String)
signal hover_changed(idx: int)

const Rules = preload("res://scripts/rules.gd")

# ------------------------------------------------------------------ layout
const CELL := 88.0
const N := 7
const BOARD_CENTER := Vector2(440, 410)
const BOARD_SIZE := CELL * N
const DIAL_HALF := BOARD_SIZE / 2.0 + 46.0
const PANEL_X := 868.0
const PANEL_W := 380.0

# ------------------------------------------------------------------ palette
const C_BG := Color("0e0c17")
const C_CELL_A := Color("272139")
const C_CELL_B := Color("2e2745")
const C_NIGHT := Color("08070e")
const C_EDGE := Color("403862")
const C_TEXT := Color("ece6f7")
const C_MUTED := Color("968fb0")
const C_PANEL := Color("171326")
const C_SUN := Color("ffe9a6")
const C_SUN_GLOW := Color("ffbf5e")
const C_GOOD := Color("ffd56b")
const C_BAD := Color("ff5d6c")
const C_AMBER := Color("f6b93b")
const C_AMBER_DARK := Color("a56a12")
const C_AMBER_SHADOW := Color("6b3d05")
const C_TEAL := Color("4fdcc6")
const C_TEAL_DARK := Color("15806f")
const C_TEAL_SHADOW := Color("083f54")

# ------------------------------------------------------------------ inputs from main.gd
class StoneView:
	extends RefCounted
	var pos := Vector2.ZERO
	var owner := 0
	var scale := 1.0
	var alpha := 1.0

var state = null                 # a Rules instance: what is on screen right now
var views := {}                  # cell idx -> StoneView
var sun_t := 2.0                 # continuous sun position along the dial (0..8)
var night_fade := 1.0            # 0..1: how dark the newest dark ring is
var selected := -1
var dests := PackedInt32Array()
var dest_info := {}              # dest idx -> {good, bad, text}
var hover := -1
var last_from := -1
var last_to := -1
var title_text := ""
var title_owner := 0             # 0 = neutral
var sub_text := ""
var turn_hint := ""
var log_lines: Array = []
var buttons: Array = []          # [{id, label, rect, on}]
var show_help := false
var show_hints := true
var show_next := false
var game_over := false
var banner_visible := true
var thinking := false
var fx: Array = []               # transient particles / rings

var font: Font
var font_bold: Font
var _t := 0.0
var _btn_hover := ""
var _sb_cache := {}


func _ready() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Inter", "Noto Sans", "DejaVu Sans", "Sans"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font = f
	var fb := SystemFont.new()
	fb.font_names = PackedStringArray(["Inter", "Noto Sans", "DejaVu Sans", "Sans"])
	fb.font_weight = 700
	font_bold = fb
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	# Advance particles.
	for p in fx:
		p.life -= delta
		if p.kind == "dot":
			p.pos += p.vel * delta
			p.vel *= 0.92
	fx = fx.filter(func(p): return p.life > 0.0)
	queue_redraw()


# ------------------------------------------------------------------ geometry

func board_origin() -> Vector2:
	return BOARD_CENTER - Vector2(BOARD_SIZE, BOARD_SIZE) / 2.0


func cell_center(idx: int) -> Vector2:
	return board_origin() + Vector2((idx % N) + 0.5, (idx / N) + 0.5) * CELL


func cell_rect(idx: int) -> Rect2:
	return Rect2(board_origin() + Vector2(idx % N, idx / N) * CELL, Vector2(CELL, CELL))


func pos_to_cell(p: Vector2) -> int:
	var q := (p - board_origin()) / CELL
	if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N:
		return -1
	return int(q.y) * N + int(q.x)


## Marker positions on the square dial, indexed like Rules.DX/DY.
func dial_marker(i: int) -> Vector2:
	var h := DIAL_HALF
	var pts := [Vector2(0, -h), Vector2(h, -h), Vector2(h, 0), Vector2(h, h),
		Vector2(0, h), Vector2(-h, h), Vector2(-h, 0), Vector2(-h, -h)]
	return BOARD_CENTER + pts[i % 8]


func dial_point(t: float) -> Vector2:
	var a: int = int(floorf(t)) % 8
	var f: float = t - floorf(t)
	return dial_marker(a).lerp(dial_marker(a + 1), f)


## Unit vector pointing from the board toward the sun at dial position t.
func sun_dir(t: float) -> Vector2:
	return (dial_point(t) - BOARD_CENTER).normalized()


# ------------------------------------------------------------------ helpers

func _sb(fill: Color, radius: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var key := "%s|%d|%s|%d" % [fill.to_html(true), radius, border.to_html(true), bw]
	if _sb_cache.has(key):
		return _sb_cache[key]
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = true
	_sb_cache[key] = s
	return s


func _text(pos: Vector2, s: String, size: int, col: Color, bold := false, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font_bold if bold else font, pos, s, align, width, size, col)


func _owner_col(p: int) -> Color:
	return C_AMBER if p == 1 else C_TEAL


func _owner_name(p: int) -> String:
	return "Amber" if p == 1 else "Teal"


func cell_name(idx: int) -> String:
	return "%s%d" % [char(97 + idx % N), N - idx / N]


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	_draw_glow()
	_draw_dial()
	_draw_board()
	_draw_markers()
	_draw_shadows()
	_draw_stones()
	_draw_hints()
	_draw_fx()
	_draw_panel()
	if game_over and banner_visible:
		_draw_banner()
	if show_help:
		_draw_help()


func _draw_glow() -> void:
	# A soft pool of warm light on the side the sun is on.
	var sp := dial_point(sun_t)
	for i in 9:
		var r := 620.0 - i * 62.0
		draw_circle(sp, r, Color(C_SUN_GLOW.r, C_SUN_GLOW.g, C_SUN_GLOW.b, 0.018))


func _draw_dial() -> void:
	var h := DIAL_HALF
	var rect := Rect2(BOARD_CENTER - Vector2(h, h), Vector2(h, h) * 2.0)
	draw_style_box(_sb(Color(0, 0, 0, 0), 60, Color("2a2342"), 2), rect)
	for i in 8:
		var p := dial_marker(i)
		draw_circle(p, 7.0, Color("1a1530"))
		draw_arc(p, 7.0, 0.0, TAU, 20, Color("3d3460"), 2.0, true)
	# Where the sun will be after the next round.
	var nxt := dial_marker(int(round(sun_t)) + 1)
	draw_arc(nxt, 14.0, 0.0, TAU, 28, Color(C_SUN.r, C_SUN.g, C_SUN.b, 0.45 + 0.2 * sin(_t * 3.0)), 2.0, true)
	# The sun.
	var sp := dial_point(sun_t)
	for i in 6:
		draw_circle(sp, 40.0 - i * 5.0, Color(C_SUN_GLOW.r, C_SUN_GLOW.g, C_SUN_GLOW.b, 0.06 + i * 0.03))
	for k in 8:
		var a := k * TAU / 8.0 + _t * 0.25
		var d := Vector2(cos(a), sin(a))
		draw_line(sp + d * 20.0, sp + d * 30.0, Color(C_SUN.r, C_SUN.g, C_SUN.b, 0.9), 3.0, true)
	draw_circle(sp, 15.0, C_SUN)
	draw_circle(sp, 10.0, Color("fff7d6"))


func _draw_board() -> void:
	var o := board_origin()
	# Frame.
	draw_style_box(_sb(Color("15112a"), 14, C_EDGE, 2), Rect2(o - Vector2(12, 12), Vector2(BOARD_SIZE, BOARD_SIZE) + Vector2(24, 24)))
	var sv := sun_dir(sun_t)
	var ring_alive: int = state.ring
	for idx in N * N:
		var x := idx % N
		var y := idx / N
		var r := cell_rect(idx).grow(-2.0)
		var edge := mini(mini(x, y), mini(N - 1 - x, N - 1 - y))
		var base: Color = C_CELL_A if (x + y) % 2 == 0 else C_CELL_B
		# Light falls off across the board, brighter toward the sun.
		var lit: float = clampf(((cell_center(idx) - BOARD_CENTER).dot(sv) / (BOARD_SIZE * 0.5)) * 0.5 + 0.5, 0.0, 1.0)
		base = base.lerp(Color("5a4a7a"), lit * 0.28)
		var dark := 0.0
		if edge < ring_alive - 1:
			dark = 1.0
		elif edge == ring_alive - 1:
			dark = night_fade
		draw_style_box(_sb(base.lerp(C_NIGHT, dark), 8), r)
	# The ring that falls to night at the next dusk glows a warning red.
	var rounds_to_dusk: int = state.day_len - (state.round_no % state.day_len)
	if not game_over and rounds_to_dusk <= 3 and ring_alive + state.rings_per_day < state.max_ring:
		var k := (4 - rounds_to_dusk) / 3.0
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		for idx in N * N:
			var x := idx % N
			var y := idx / N
			if mini(mini(x, y), mini(N - 1 - x, N - 1 - y)) == ring_alive:
				var col := Color(C_BAD.r, C_BAD.g, C_BAD.b, (0.07 + 0.10 * pulse) * k)
				draw_style_box(_sb(col, 8, Color(C_BAD.r, C_BAD.g, C_BAD.b, 0.25 * k), 1), cell_rect(idx).grow(-2.0))
	# Coordinates.
	for i in N:
		var c := cell_center(i)
		_text(Vector2(c.x - 5, board_origin().y + BOARD_SIZE + 31), char(97 + i), 13, C_MUTED)
		var cy := cell_center(i * N)
		_text(Vector2(board_origin().x - 30, cy.y + 5), str(N - i), 13, C_MUTED)


func _draw_markers() -> void:
	# Last move.
	if last_to >= 0:
		var col := Color(1, 1, 1, 0.10)
		draw_style_box(_sb(col, 8), cell_rect(last_to).grow(-2.0))
		if last_from >= 0:
			draw_style_box(_sb(Color(1, 1, 1, 0.05), 8), cell_rect(last_from).grow(-2.0))
	# Selection + destinations.
	if selected >= 0:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_style_box(_sb(Color(1, 1, 1, 0.06 + 0.04 * pulse), 8, _owner_col(state.turn), 3), cell_rect(selected).grow(-2.0))
		for d in dests:
			var c := cell_center(d)
			var info: Dictionary = dest_info.get(d, {})
			var col := Color(1, 1, 1, 0.55)
			var rad := 8.0
			if info.get("good", false):
				col = C_GOOD
				rad = 12.0
			elif info.get("risky", false):
				col = Color("ff9f4a")
				rad = 12.0
			elif info.get("bad", false):
				col = C_BAD
				rad = 12.0
			if d == hover:
				rad += 4.0
			draw_circle(c, rad + 3.0, Color(0, 0, 0, 0.35))
			draw_circle(c, rad, Color(col.r, col.g, col.b, 0.9))
			if info.get("good", false) or info.get("risky", false):
				_draw_sparkle(c, 7.0, Color("2a1d00"))
			elif info.get("bad", false):
				draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Color("2a0008"), 3.0, true)
				draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), Color("2a0008"), 3.0, true)


func _draw_sparkle(c: Vector2, r: float, col: Color) -> void:
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, 2.5, true)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, 2.5, true)


## Shadows fall directly away from the sun, `shadow_len` cells long.
func _draw_shadows() -> void:
	var sv := sun_dir(sun_t)
	_shadow_pass(sv, 1.0, false)
	if show_next:
		_shadow_pass(sun_dir(fposmod(floorf(sun_t) + 1.0, 8.0)), 0.5, true)


func _shadow_pass(sv: Vector2, strength: float, outline_only: bool) -> void:
	var away := -sv
	var m := maxf(absf(sv.x), absf(sv.y))
	var length: float = (state.shadow_len + 0.42) * CELL / m
	var perp := Vector2(-away.y, away.x)
	# Shadows are clipped to the part of the board that is still lit by day.
	var live_o := board_origin() + Vector2(state.ring, state.ring) * CELL
	var live_s := Vector2(N - 2 * state.ring, N - 2 * state.ring) * CELL
	var live := PackedVector2Array([live_o, live_o + Vector2(live_s.x, 0), live_o + live_s, live_o + Vector2(0, live_s.y)])
	for idx in views:
		var v: StoneView = views[idx]
		if v.alpha < 0.05:
			continue
		var c: Vector2 = v.pos
		var col: Color = C_AMBER_SHADOW if v.owner == 1 else C_TEAL_SHADOW
		var w0 := CELL * 0.30 * v.scale
		var w1 := CELL * 0.21 * v.scale
		var tip := c + away * length * v.scale
		var pts := PackedVector2Array([c + perp * w0])
		for k in range(0, 9):
			pts.append(tip + perp.rotated(-PI * k / 8.0) * w1)
		pts.append(c - perp * w0)
		var parts: Array = Geometry2D.intersect_polygons(pts, live)
		for poly in parts:
			if outline_only:
				var oc := Color(_owner_col(v.owner).r, _owner_col(v.owner).g, _owner_col(v.owner).b, 0.30 * v.alpha)
				var closed: PackedVector2Array = poly.duplicate()
				closed.append(poly[0])
				draw_polyline(closed, oc, 1.5, true)
			else:
				draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.70 * strength * v.alpha))


func _draw_stones() -> void:
	var sv := sun_dir(sun_t)
	for idx in views:
		var v: StoneView = views[idx]
		_draw_stone(v.pos, v.owner, v.scale, v.alpha, sv, idx == selected)


func _draw_stone(center: Vector2, owner: int, sc: float, alpha: float, sv: Vector2, lifted: bool) -> void:
	var r := CELL * 0.31 * sc
	var top: Color = _owner_col(owner)
	var base: Color = C_AMBER_DARK if owner == 1 else C_TEAL_DARK
	top.a = alpha
	base.a = alpha
	var c := center + Vector2(0, -5.0 if lifted else 0.0)
	draw_circle(center + Vector2(0, 3), r + 1.0, Color(0, 0, 0, 0.35 * alpha))
	if owner == 1:
		# Amber stones are round.
		draw_circle(c, r, base)
		draw_circle(c + sv * 3.0, r * 0.87, top)
		draw_circle(c + sv * (r * 0.38), r * 0.24, Color(1, 1, 1, 0.45 * alpha))
		draw_arc(c + sv * 3.0, r * 0.52, 0.0, TAU, 24, Color(0.35, 0.18, 0.0, 0.55 * alpha), 2.0, true)
	else:
		# Teal stones are diamonds, so the two sides never rely on colour alone.
		var rr := r * 1.18
		var pb := PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
		draw_colored_polygon(pb, base)
		var o := sv * 3.0
		var pt := PackedVector2Array()
		for p in pb:
			pt.append(c + o + (p - c) * 0.86)
		draw_colored_polygon(pt, top)
		draw_circle(c + sv * (r * 0.38), r * 0.22, Color(1, 1, 1, 0.45 * alpha))
		draw_arc(c + o, r * 0.45, 0.0, TAU, 24, Color(0.0, 0.25, 0.22, 0.55 * alpha), 2.0, true)


func _draw_hints() -> void:
	if game_over:
		return
	var now: PackedInt32Array = state.eclipsed_cells()
	# Stones already standing in an enemy shadow. They are removed when that
	# enemy next moves (unless something changes), so they are always shown.
	for i in now:
		if not views.has(i):
			continue
		var v: StoneView = views[i]
		var mine: bool = state.board[i] == state.turn
		var col: Color = C_BAD if mine else C_GOOD
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_circle(v.pos, CELL * 0.33 * v.scale, Color(0.02, 0.0, 0.06, 0.45 * v.alpha))
		draw_arc(v.pos, CELL * 0.42, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.5 + 0.4 * pulse), 3.0, true)
		var tp: Vector2 = v.pos + Vector2(CELL * 0.30, -CELL * 0.33)
		draw_circle(tp, 9.0, col)
		_text(tp + Vector2(-3.5, 5), "!" if mine else "×", 13, Color("1a0006"), true)
	if not show_hints:
		return
	# Stones that would be in shadow once the sun turns, if nothing changes.
	var nxt: PackedInt32Array = state.eclipsed_cells_for_sun((state.sun + 1) % 8)
	for i in nxt:
		if i in now or not views.has(i):
			continue
		var v: StoneView = views[i]
		var col := Color(1, 1, 1, 0.38)
		for k in 12:
			var a0 := k * TAU / 12.0
			draw_arc(v.pos, CELL * 0.42, a0, a0 + TAU / 24.0, 5, col, 2.0, true)


func _draw_fx() -> void:
	for p in fx:
		var k: float = clampf(p.life / p.max, 0.0, 1.0)
		if p.kind == "dot":
			draw_circle(p.pos, p.size * k, Color(p.col.r, p.col.g, p.col.b, k))
		elif p.kind == "ring":
			draw_arc(p.pos, p.size * (1.0 - k) + 8.0, 0.0, TAU, 40, Color(p.col.r, p.col.g, p.col.b, k * 0.9), 4.0 * k + 1.0, true)


# ------------------------------------------------------------------ panel

func _draw_panel() -> void:
	var x := PANEL_X
	_text(Vector2(x, 74), "GNOMON", 46, C_TEXT, true)
	_text(Vector2(x + 2, 104), "stand uphill. cast the shadow.", 15, C_MUTED)

	# --- turn card
	var card := Rect2(x, 128, PANEL_W, 112)
	draw_style_box(_sb(C_PANEL, 14, Color("2b2447"), 2), card)
	var col := C_TEXT if title_owner == 0 else _owner_col(title_owner)
	if title_owner != 0:
		_draw_chip(Vector2(x + 34, 170), title_owner, 18.0)
	_text(Vector2(x + (62 if title_owner != 0 else 22), 180), title_text, 28, col, true)
	_text(Vector2(x + 22, 208), sub_text, 15, C_MUTED)
	_text(Vector2(x + 22, 228), turn_hint, 15, Color("b9b1d3"))

	# --- stones
	var y := 262.0
	for p in [1, 2]:
		_text(Vector2(x, y + 20), _owner_name(p), 18, _owner_col(p), true)
		var left: int = state.counts[p]
		for i in 5:
			var c := Vector2(x + 110 + i * 40, y + 12)
			if i < left:
				_draw_chip(c, p, 14.0)
			else:
				draw_arc(c, 11.0, 0.0, TAU, 20, Color(1, 1, 1, 0.12), 2.0, true)
		y += 40.0

	# --- sun & day tracker
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var sname: String = names[state.sun]
	var fall: String = names[(state.sun + 4) % 8]
	_text(Vector2(x, 372), "Sun in the %s" % sname, 18, C_SUN, true)
	_text(Vector2(x, 394), "Shadows fall %s, %d cells." % [fall, state.shadow_len], 15, C_MUTED)

	var day: int = state.round_no / state.day_len + 1
	var in_day: int = state.round_no % state.day_len
	_text(Vector2(x, 432), "Day %d of %d" % [mini(day, state.max_ring), state.max_ring], 18, C_TEXT, true)
	var pip_w := PANEL_W / float(state.day_len)
	for i in state.day_len:
		var px: float = x + pip_w * i
		var done: bool = i < in_day
		var is_last: bool = i == state.day_len - 1
		var r := Rect2(px + 2, 444, pip_w - 6, 14)
		var fill := Color("2a2342")
		if done:
			fill = Color(C_SUN.r, C_SUN.g, C_SUN.b, 0.85)
		elif i == in_day and not game_over:
			fill = Color(C_SUN.r, C_SUN.g, C_SUN.b, 0.30 + 0.2 * sin(_t * 4.0))
		if is_last:
			fill = fill.lerp(C_BAD, 0.55)
		draw_style_box(_sb(fill, 5), r)
	var rounds_left: int = state.day_len - in_day
	var final_day: bool = state.ring + state.rings_per_day >= state.max_ring
	if final_day:
		_text(Vector2(x, 482), "Final dusk in %d round%s: most stones wins." % [rounds_left, "" if rounds_left == 1 else "s"], 15, Color("ff9aa5"))
	else:
		_text(Vector2(x, 482), "Dusk in %d round%s: the outer ring goes dark." % [rounds_left, "" if rounds_left == 1 else "s"], 15, C_MUTED)

	# --- log
	var ly := 520.0
	for i in mini(log_lines.size(), 5):
		var line: Dictionary = log_lines[log_lines.size() - 1 - i]
		var a: float = 1.0 - i * 0.17
		_text(Vector2(x, ly), line.text, 14, Color(line.col.r, line.col.g, line.col.b, a))
		ly += 21.0

	# --- buttons
	for b in buttons:
		var on: bool = b.get("on", false)
		var hov: bool = _btn_hover == b.id
		var fill := Color("231d3b")
		if on:
			fill = Color("3a2f66")
		if hov:
			fill = fill.lightened(0.12)
		draw_style_box(_sb(fill, 10, Color("4a3f7a") if on else Color("322a52"), 2), b.rect)
		var tw := font_bold.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_text(Vector2(b.rect.position.x + (b.rect.size.x - tw) / 2.0, b.rect.position.y + b.rect.size.y / 2.0 + 5), b.label, 15, C_TEXT if on or hov else Color("c9c1e2"), true)


func _draw_chip(c: Vector2, p: int, r: float) -> void:
	if p == 1:
		draw_circle(c, r, C_AMBER_DARK)
		draw_circle(c + Vector2(1.5, -1.5), r * 0.86, C_AMBER)
	else:
		var rr := r * 1.15
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)]), C_TEAL_DARK)
		var q := rr * 0.86
		draw_colored_polygon(PackedVector2Array([c + Vector2(1.5, -1.5 - q), c + Vector2(1.5 + q, -1.5), c + Vector2(1.5, -1.5 + q), c + Vector2(1.5 - q, -1.5)]), C_TEAL)


func _draw_banner() -> void:
	var r := Rect2(BOARD_CENTER + Vector2(-230, -90), Vector2(460, 180))
	draw_style_box(_sb(Color(0.04, 0.03, 0.09, 0.92), 22, Color("5a4d8a"), 3), r)
	var col := C_TEXT if title_owner == 0 else _owner_col(title_owner)
	if title_owner != 0:
		_draw_chip(Vector2(r.position.x + 62, r.position.y + 62), title_owner, 26.0)
	_text(Vector2(r.position.x, r.position.y + 76), title_text, 44, col, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(r.position.x, r.position.y + 110), sub_text, 18, C_MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(r.position.x, r.position.y + 150), "Click the board to hide this   ·   R: new game", 15, Color("b9b1d3"), false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# ------------------------------------------------------------------ help

const HELP_TEXT := [
	["THE SUN", "A sun circles the board. It sits on the dial around the edge, and every stone casts a shadow 2 cells long, straight away from it."],
	["ECLIPSE", "A stone standing in an ENEMY shadow is in danger. After you move, every enemy stone in one of your shadows is eclipsed and removed. Stand uphill of an enemy (nearer the sun, in line, within 2 cells) and you take them. Your own shadows never hurt you."],
	["YOUR TURN", "Move one stone one step in any of 8 directions onto an empty cell. A stone in an enemy shadow is marked ! (yours) or × (theirs). Move it, or deal with the stone casting the shadow, before they move."],
	["THE SUN TURNS", "After each round (one move by each player) the sun advances one notch clockwise, 45°. Its next place is ringed on the dial, and dashed rings mark stones that will be in shadow then. Teal's move is the last before the sun turns, Amber's the first after, so plan for the new angle."],
	["DUSK", "Every 8 rounds (one full circuit of the sun) the outer ring of cells goes dark and any stone standing there is lost. The board shrinks 7×7, 5×5, 3×3. When the third dusk falls the game ends: more stones wins."],
	["WINNING", "Remove all the enemy stones, or have more stones when the last night falls. If both players lose their last stones together it is a draw."],
]


func _draw_help() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.07, 0.86))
	var r := Rect2(190, 70, 900, 680)
	draw_style_box(_sb(Color("171326"), 20, Color("43396b"), 2), r)
	_text(Vector2(r.position.x + 44, r.position.y + 70), "How to play Gnomon", 38, C_TEXT, true)
	var y := r.position.y + 118.0
	for h in HELP_TEXT:
		_text(Vector2(r.position.x + 44, y), h[0], 15, C_SUN, true)
		draw_multiline_string(font, Vector2(r.position.x + 190, y), h[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 240, 17, -1, Color("d4cde8"))
		y += 88.0
	_text(Vector2(r.position.x + 44, r.end.y - 34), "Click anywhere to begin.   H hints   S next shadows   U undo   R new game   F1 this page", 15, C_MUTED)


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position
		var nb := ""
		for b in buttons:
			if b.rect.has_point(p):
				nb = b.id
		_btn_hover = nb
		var c := pos_to_cell(p)
		if c != hover:
			hover = c
			hover_changed.emit(c)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (nb != "" or c >= 0) else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed:
		var p: Vector2 = event.position
		if show_help:
			button_pressed.emit("close_help")
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cell_clicked.emit(-1)
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		for b in buttons:
			if b.rect.has_point(p):
				button_pressed.emit(b.id)
				return
		var c := pos_to_cell(p)
		cell_clicked.emit(c)


## Particle helpers (called by main.gd).
func burst(at: Vector2, col: Color, n := 14) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(60.0, 220.0)
		fx.append({"kind": "dot", "pos": at, "vel": Vector2(cos(a), sin(a)) * sp, "life": 0.7, "max": 0.7, "size": randf_range(3.0, 7.0), "col": col})
	fx.append({"kind": "ring", "pos": at, "life": 0.6, "max": 0.6, "size": 60.0, "col": col})
