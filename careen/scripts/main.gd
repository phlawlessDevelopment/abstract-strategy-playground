extends Control
## Careen: window layout, controls and turn flow. Rules live in rules.gd, the computer in
## ai.gd, drawing and animation in board_view.gd.

const COL_AMBER := CarBoardView.COL_AMBER
const COL_TEAL := CarBoardView.COL_TEAL
const INK := CarBoardView.COL_INK
const DIM := CarBoardView.COL_DIM
const GOOD := CarBoardView.COL_GOOD
const BAD := CarBoardView.COL_BAD
const CARD_BG := Color("#1d232d")
const CARD_EDGE := Color("#323d4e")
const BTN_BG := Color("#2a3342")

enum Mode { YOU_AMBER, YOU_TEAL, TWO_PLAYERS }
enum Level { EASY, MEDIUM, HARD }

## The tray layout. Posts (cell indices) are fixed obstacles; this pinwheel is turned the
## same way for both players so neither seat gets a better side.
const BOARD_SIZE := 6
const STONES := 11
const POSTS: Array[int] = []

var rules: CarRules
var ai := CarAI.new()
var view: CarBoardView

var mode: int = Mode.YOU_AMBER
var level: int = Level.MEDIUM
var hints: bool = true

var thinking: bool = false     # the computer is deciding (a new game may cancel it)
var animating: bool = false    # stones are moving (input is ignored until they stop)
var game_id: int = 0           # bumped whenever pending computer work must be forgotten

var name_labels: Array[Label] = []
var role_labels: Array[Label] = []
var lost_labels: Array[Label] = []
var lost_captions: Array[Label] = []
var hand_rows: Array[Control] = []
var cards: Array[PanelContainer] = []
var card_styles: Array[StyleBoxFlat] = []
var lead_label: Label
var status_label: Label
var how_label: Label
var last_label: Label
var hover_label: RichTextLabel
var footer_label: Label
var mode_button: OptionButton
var level_button: OptionButton
var undo_button: Button
var hints_button: Button
var rules_overlay: Control


# A row of small stones: how many are still in hand.
class StoneRow extends Control:
	var who: int = 0
	var count: int = 0
	var total: int = 9

	func _init(p_who: int, p_total: int) -> void:
		who = p_who
		total = p_total
		custom_minimum_size = Vector2(total * 17.0, 20)

	func _draw() -> void:
		for i in total:
			var c := Vector2(9.0 + i * 17.0, 10.0)
			var col := CarBoardView.COL_AMBER if who == CarRules.AMBER else CarBoardView.COL_TEAL
			if i >= count:
				col = Color(col, 0.18)
			if who == CarRules.AMBER:
				draw_circle(c, 6.0, col)
			else:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7.5), c + Vector2(7.5, 0), c + Vector2(0, 7.5), c + Vector2(-7.5, 0)]), col)


# The big stone on a player card.
class StoneIcon extends Control:
	var who: int = 0

	func _init(p_who: int) -> void:
		who = p_who
		custom_minimum_size = Vector2(60, 60)

	func _draw() -> void:
		var col := CarBoardView.COL_AMBER if who == CarRules.AMBER else CarBoardView.COL_TEAL
		var c := size / 2.0
		if who == CarRules.AMBER:
			draw_circle(c, 23.0, col)
			draw_arc(c, 13.0, 0.0, TAU, 32, Color(0, 0, 0, 0.3), 3.0, true)
		else:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -28), c + Vector2(28, 0), c + Vector2(0, 28), c + Vector2(-28, 0)]), col)
			draw_polyline(PackedVector2Array([c + Vector2(0, -15), c + Vector2(15, 0), c + Vector2(0, 15), c + Vector2(-15, 0), c + Vector2(0, -15)]), Color(0, 0, 0, 0.3), 3.0, true)


func _ready() -> void:
	_build_ui()
	new_game()


# --- naming helpers -----------------------------------------------------------------

func _name(who: int) -> String:
	return "Amber" if who == CarRules.AMBER else "Teal"


func _col(who: int) -> Color:
	return COL_AMBER if who == CarRules.AMBER else COL_TEAL


func _bb(who: int) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [_col(who).to_html(false), _name(who)]


func is_human(who: int) -> bool:
	return mode == Mode.TWO_PLAYERS or (mode == Mode.YOU_AMBER and who == CarRules.AMBER) or (mode == Mode.YOU_TEAL and who == CarRules.TEAL)


func _human_turn() -> bool:
	return not rules.is_over() and is_human(rules.turn) and not thinking and not animating


# --- UI construction ----------------------------------------------------------------

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(10)
			sb.set_border_width_all(2)
			sb.border_color = Color("#3e4a5e")
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			sb.bg_color = BTN_BG
			if state == "hover":
				sb.bg_color = Color("#354055")
				sb.border_color = INK
			elif state == "pressed":
				sb.bg_color = Color("#222a37")
			elif state == "disabled":
				sb.bg_color = Color(BTN_BG, 0.5)
				sb.border_color = Color("#3e4a5e", 0.5)
			t.set_stylebox(state, type, sb)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		for cname in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(cname, type, INK)
		t.set_color("font_disabled_color", type, Color(INK, 0.4))
	return t


func _label(text: String, size: int, col: Color, x: float, y: float, w: float, h: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	add_child(l)
	return l


func _button(text: String, x: float, y: float, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(x, y)
	b.size = Vector2(w, 44)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _make_card(who: int, y: float) -> void:
	var card := PanelContainer.new()
	card.position = Vector2(790, y)
	card.size = Vector2(450, 100)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.bg_color = CARD_BG
	sb.border_color = CARD_EDGE
	sb.content_margin_left = 16
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)
	cards.append(card)
	card_styles.append(sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(StoneIcon.new(who))

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(names)
	var n := Label.new()
	n.text = _name(who)
	n.add_theme_font_size_override("font_size", 28)
	n.add_theme_color_override("font_color", _col(who))
	names.add_child(n)
	var role := Label.new()
	role.add_theme_font_size_override("font_size", 15)
	role.add_theme_color_override("font_color", DIM)
	names.add_child(role)
	var hand := StoneRow.new(who, STONES)
	names.add_child(hand)
	name_labels.append(n)
	role_labels.append(role)
	hand_rows.append(hand)

	var nums := VBoxContainer.new()
	nums.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(nums)
	var big := Label.new()
	big.add_theme_font_size_override("font_size", 46)
	big.add_theme_color_override("font_color", INK)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nums.add_child(big)
	var cap := Label.new()
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap.text = "stones lost"
	nums.add_child(cap)
	lost_labels.append(big)
	lost_captions.append(cap)


func _build_ui() -> void:
	theme = _build_theme()

	_label("Careen", 46, INK, 56, 20, 600, 60)
	_label("drop a stone, and your opponent decides which way the tray tilts", 17, DIM, 59, 78, 700, 26)

	view = CarBoardView.new()
	view.position = Vector2(30, 104)
	add_child(view)
	view.cell_clicked.connect(_on_cell_clicked)
	view.cell_hovered.connect(_on_cell_hovered)
	view.arrow_clicked.connect(_on_arrow_clicked)
	view.arrow_hovered.connect(_on_arrow_hovered)

	_make_card(CarRules.AMBER, 100)
	_make_card(CarRules.TEAL, 212)

	lead_label = _label("", 17, DIM, 790, 322, 450, 26)
	status_label = _label("", 27, INK, 790, 352, 450, 44)
	how_label = _label("", 17, DIM, 790, 396, 450, 84)
	last_label = _label("", 17, INK, 790, 478, 450, 48)
	hover_label = RichTextLabel.new()
	hover_label.bbcode_enabled = true
	hover_label.fit_content = false
	hover_label.scroll_active = false
	hover_label.position = Vector2(790, 528)
	hover_label.size = Vector2(450, 100)
	hover_label.add_theme_font_size_override("normal_font_size", 17)
	hover_label.add_theme_font_size_override("bold_font_size", 17)
	hover_label.add_theme_color_override("default_color", INK)
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hover_label)

	mode_button = OptionButton.new()
	mode_button.add_item("You: Amber")
	mode_button.add_item("You: Teal")
	mode_button.add_item("Two players")
	mode_button.position = Vector2(790, 640)
	mode_button.size = Vector2(218, 44)
	mode_button.item_selected.connect(_on_mode_selected)
	add_child(mode_button)

	level_button = OptionButton.new()
	level_button.add_item("Computer: Easy")
	level_button.add_item("Computer: Medium")
	level_button.add_item("Computer: Hard")
	level_button.select(level)
	level_button.position = Vector2(1022, 640)
	level_button.size = Vector2(218, 44)
	level_button.item_selected.connect(_on_level_selected)
	add_child(level_button)

	_button("New game", 790, 694, 142, func(): new_game())
	undo_button = _button("Undo", 944, 694, 142, _on_undo)
	hints_button = _button("Hints: on", 1098, 694, 142, _toggle_hints)
	_button("Rules  (F1)", 790, 744, 218, func(): _set_rules_open(true))
	footer_label = _label("arrow keys tilt   R new   U undo   H hints   F1 rules", 14, Color(DIM, 0.85), 1022, 754, 230, 40)

	_build_rules_overlay()


func _build_rules_overlay() -> void:
	rules_overlay = Control.new()
	rules_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules_overlay.visible = false
	add_child(rules_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules_overlay.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules_overlay.add_child(centre)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(800, 0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(20)
	sb.bg_color = Color("#1b212b")
	sb.set_border_width_all(3)
	sb.border_color = Color("#46566e")
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", sb)
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var head := Label.new()
	head.text = "How to play"
	head.add_theme_font_size_override("font_size", 32)
	head.add_theme_color_override("font_color", INK)
	col.add_child(head)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		body.add_theme_font_size_override(k, 18)
	body.add_theme_color_override("default_color", INK)
	body.text = "Two players share a tray. Each has " + str(STONES) + " stones: [color=#f2a93b][b]Amber[/b][/color] circles and [color=#46c2b5][b]Teal[/b][/color] diamonds.\n\n" \
		+ "On your turn you do two things, in order:\n" \
		+ "  [b]1. Tilt[/b] the tray north, east, south or west. Every stone slides as far as it can, stopping at a wall, a post or another stone.\n" \
		+ "  [b]2. Drop[/b] one of your stones on any empty cell. It stays exactly where you put it...\n\n" \
		+ "...until your opponent's tilt. [b]You never tilt after your own drop[/b], so every stone you drop has to survive four possible futures.\n\n" \
		+ "[b]Crushing.[/b] When a tilt settles, any stone with an [b]enemy stone straight across it on both sides[/b] (left and right, or above and below) is crushed. A wall is not an enemy. Crushed stones vanish together, everything slides again, and the check repeats until nothing more falls. A stone with a friend beside it is safe on that line.\n\n" \
		+ "[b]Winning.[/b] When every stone has been dropped, one last tilt is made, then count: [b]the player who lost fewer stones wins[/b]. Equal losses are a draw.\n\n" \
		+ "[i]Hover an arrow to see the result of a tilt. Hover an empty cell to see what each tilt would do to you if you dropped there.[/i]"
	col.add_child(body)
	var close := Button.new()
	close.text = "Got it  (Esc)"
	close.custom_minimum_size = Vector2(180, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func(): _set_rules_open(false))
	col.add_child(close)


func _set_rules_open(open: bool) -> void:
	rules_overlay.visible = open


# --- game flow ----------------------------------------------------------------------

func new_game() -> void:
	if animating:
		return
	rules = CarRules.new(BOARD_SIZE, STONES, PackedInt32Array(POSTS))
	view.set_rules(rules)
	_restart_flow()


## Forget any pending computer move, redraw, and let the computer open if it is its turn.
func _restart_flow() -> void:
	game_id += 1
	thinking = false
	_refresh()
	_maybe_computer()


func _maybe_computer() -> void:
	if not rules.is_over() and not is_human(rules.turn):
		_computer_turn()


func _ai_pick() -> Dictionary:
	# Easy looks one turn ahead but plays at random half the time. Medium looks two turns ahead
	# and Hard three (self-play: each extra turn of lookahead beats the one below it by 80% or more).
	match level:
		Level.EASY:
			return ai.choose(rules, 0 if ai.rng.randf() < 0.5 else 1)
		Level.MEDIUM:
			return ai.choose(rules, 2)
		_:
			return ai.choose(rules, 3)


func _computer_turn() -> void:
	var gid := game_id
	thinking = true
	_refresh()
	await get_tree().create_timer(0.5).timeout
	if gid != game_id:
		return
	await get_tree().process_frame   # let "thinking" paint before the search blocks
	if gid != game_id:
		return
	var pick := _ai_pick()
	thinking = false
	if rules.phase == CarRules.Phase.TILT:
		await _do_tilt(pick["tilt"])
		if gid != game_id:
			return
	if not rules.is_over() and rules.phase == CarRules.Phase.DROP:
		await _do_drop(pick["cell"])
		if gid != game_id:
			return
	_after_turn()


func _after_turn() -> void:
	if rules.is_over():
		_show_result()
	_refresh()
	_maybe_computer()


func _do_tilt(d: int) -> void:
	animating = true
	view.clear_ghost()
	var steps := rules.tilt(d)
	_refresh()
	await view.play_tilt(steps, d)
	animating = false
	if rules.is_over():
		_show_result()
	_refresh()


func _do_drop(cell: int) -> void:
	animating = true
	view.clear_ghost()
	var who := rules.turn
	rules.drop(cell)
	_refresh()
	await view.play_drop(cell, who)
	animating = false
	_refresh()


func _on_arrow_clicked(d: int) -> void:
	if rules_overlay.visible or not _human_turn() or rules.phase != CarRules.Phase.TILT or not rules.dir_ok(d):
		return
	var gid := game_id
	await _do_tilt(d)
	if gid != game_id:
		return
	if rules.is_over():
		_after_turn()


func _on_cell_clicked(cell: int) -> void:
	if not _human_turn() or rules.phase != CarRules.Phase.DROP or rules.cells[cell] != CarRules.EMPTY:
		return
	var gid := game_id
	await _do_drop(cell)
	if gid != game_id:
		return
	_after_turn()


func _on_cell_hovered(_cell: int) -> void:
	_refresh_preview()


func _on_arrow_hovered(_d: int) -> void:
	_refresh_preview()


## Undo back to the start of the human's current turn, or the one before if already there.
func _on_undo() -> void:
	if animating or rules.history.is_empty():
		return
	while rules.undo():
		if is_human(rules.turn) and (rules.phase == CarRules.Phase.TILT or rules.history.is_empty()):
			break
	view.set_rules(rules)
	_restart_flow()


func _on_mode_selected(idx: int) -> void:
	mode = idx
	new_game()


func _on_level_selected(idx: int) -> void:
	level = idx


func _toggle_hints() -> void:
	hints = not hints
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			_set_rules_open(false)
		KEY_F1, KEY_SLASH:
			_set_rules_open(not rules_overlay.visible)
		KEY_R:
			new_game()
		KEY_U:
			_on_undo()
		KEY_H:
			_toggle_hints()
		KEY_UP:
			_on_arrow_clicked(CarRules.Dir.N)
		KEY_RIGHT:
			_on_arrow_clicked(CarRules.Dir.E)
		KEY_DOWN:
			_on_arrow_clicked(CarRules.Dir.S)
		KEY_LEFT:
			_on_arrow_clicked(CarRules.Dir.W)


# --- text and state -----------------------------------------------------------------

func _show_result() -> void:
	var w := rules.winner()
	var a: int = rules.lost[CarRules.AMBER]
	var t: int = rules.lost[CarRules.TEAL]
	if w == 2:
		view.banner_title = "A draw"
		view.banner_color = INK
	else:
		view.banner_title = "%s wins" % _name(w)
		view.banner_color = _col(w)
	view.banner_sub = "Amber lost %d, Teal lost %d" % [a, t]


func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


func _refresh() -> void:
	var over := rules.is_over()
	var w := rules.winner()
	var cur := rules.turn

	for who in 2:
		lost_labels[who].text = str(rules.lost[who])
		hand_rows[who].count = rules.reserve[who]
		hand_rows[who].queue_redraw()
		var on_tray := rules.stones_on_board(who)
		role_labels[who].text = "%d in hand, %d on the tray" % [rules.reserve[who], on_tray]
		var active := (not over and cur == who) or (over and w == who)
		card_styles[who].border_color = _col(who) if active else CARD_EDGE
		card_styles[who].bg_color = CARD_BG.lerp(_col(who), 0.10) if active else CARD_BG

	var diff: int = rules.lost[CarRules.TEAL] - rules.lost[CarRules.AMBER]   # > 0: Amber is ahead
	if diff > 0:
		lead_label.text = "%s is ahead by %s" % [_name(CarRules.AMBER), _plural(diff, "stone", "stones")]
	elif diff < 0:
		lead_label.text = "%s is ahead by %s" % [_name(CarRules.TEAL), _plural(-diff, "stone", "stones")]
	else:
		lead_label.text = "Level: nobody is ahead"

	var tilting := rules.phase == CarRules.Phase.TILT
	if over:
		status_label.text = "Draw." if w == 2 else "%s wins." % _name(w)
		status_label.add_theme_color_override("font_color", INK if w == 2 else _col(w))
		how_label.text = "Fewer stones lost wins. Click the tray to show or hide the result. Press R for a new game."
	else:
		status_label.add_theme_color_override("font_color", _col(cur))
		if thinking:
			status_label.text = "The computer (%s) is thinking..." % _name(cur)
			how_label.text = ""
		elif not is_human(cur):
			status_label.text = "%s is moving..." % _name(cur)
			how_label.text = ""
		elif rules.history.is_empty():
			status_label.text = "%s: drop the first stone" % _name(cur)
			how_label.text = "The tray is empty, so there is nothing to tilt yet. Place a stone anywhere. Your opponent will tilt next."
		elif tilting and rules.finale_left > 0:
			status_label.text = "%s: the last tilt" % _name(cur)
			how_label.text = "Every stone has been dropped. Tilt once more, then the stones lost are counted."
		elif tilting:
			status_label.text = "%s: tilt the tray" % _name(cur) if mode == Mode.TWO_PLAYERS else "Your turn: tilt the tray"
			how_label.text = "Pick a direction. Everything slides, and a stone between two enemies is crushed. Then you drop a stone." + ("" if not rules.no_repeat or rules.last_dir < 0 else " (Not %s again.)" % CarRules.DIR_NAMES[rules.last_dir])
		else:
			status_label.text = "%s: drop a stone" % _name(cur) if mode == Mode.TWO_PLAYERS else "Your turn: drop a stone"
			how_label.text = "Click an empty cell. Your opponent tilts next, so hover cells to see how each tilt would treat you."

	if rules.events.is_empty():
		last_label.text = "The tray is empty."
	else:
		last_label.text = _describe_last()

	view.actor = cur
	view.arrow_owner = cur if tilting else 1 - cur
	view.can_tilt = _human_turn() and tilting
	view.can_drop = _human_turn() and rules.phase == CarRules.Phase.DROP
	for d in 4:
		view.arrow_enabled[d] = rules.dir_ok(d)
	view.last_tilt_dir = rules.last_dir
	if not over:
		view.banner_title = ""
		view.banner_hidden = false
	view.refresh()

	hints_button.text = "Hints: on" if hints else "Hints: off"
	undo_button.disabled = animating or rules.history.is_empty()
	level_button.disabled = mode == Mode.TWO_PLAYERS
	level_button.select(level)
	mode_button.select(mode)
	_refresh_preview()


func _describe_last() -> String:
	# Summarise the most recent tilt and the drop after it.
	var tilt_ev = null
	var drop_ev = null
	for k in range(rules.events.size() - 1, -1, -1):
		var e: Dictionary = rules.events[k]
		if e["kind"] == "drop" and drop_ev == null and tilt_ev == null:
			drop_ev = e
		elif e["kind"] == "tilt":
			tilt_ev = e
			break
	var parts: Array[String] = []
	if tilt_ev != null:
		var who: int = tilt_ev["who"]
		var s := "%s tilted %s" % [_name(who), CarRules.DIR_NAMES[tilt_ev["dir"]]]
		var cr: Array = tilt_ev["crushed"]
		if cr[0] + cr[1] == 0:
			s += ": nothing crushed"
		else:
			var bits: Array[String] = []
			for o in 2:
				if cr[o] > 0:
					bits.append("%d %s" % [cr[o], _name(o)])
			s += ": crushed " + " and ".join(bits)
		parts.append(s)
	if drop_ev != null:
		parts.append("%s dropped a stone" % _name(drop_ev["who"]))
	return ". ".join(parts) + "."


## Arrow numbers and ghost previews for whatever the pointer is over.
func _refresh_preview() -> void:
	view.clear_ghost()
	hover_label.text = ""
	for d in 4:
		view.arrow_text[d] = ""
		view.arrow_text_col[d] = DIM
	if rules.is_over() or not _human_turn():
		view.refresh()
		return
	var who := rules.turn
	if rules.phase == CarRules.Phase.TILT:
		for d in 4:
			if not rules.dir_ok(d):
				continue
			var swing := rules.tilt_swing(d, who)
			if hints:
				_set_arrow_swing(d, swing)
		var a := view.hover_arrow
		if a >= 0 and rules.dir_ok(a):
			var p := rules.preview_tilt(a)
			view.set_ghost(CarBoardView.trace(rules.cells, p["steps"]))
			hover_label.text = _tilt_sentence(who, a, p["lost"])
	elif rules.phase == CarRules.Phase.DROP:
		var c := view.hover_cell
		if c >= 0 and rules.cells[c] == CarRules.EMPTY:
			var worst_dir := -1
			var worst := -1000
			var results := {}
			var base := rules.cells.duplicate()
			base[c] = who + 1
			for d in 4:
				if not rules.dir_ok(d):
					continue
				var b := base.duplicate()
				var l: Array = [0, 0]
				var steps := []
				CarRules.settle(b, rules.w, rules.h, d, l, steps)
				var their: int = l[who] - l[1 - who]     # what the tilt does to them, from their side
				results[d] = [their, l, steps]
				if hints:
					_set_arrow_swing(d, -their)
				if their > worst:
					worst = their
					worst_dir = d
			if hints and worst_dir >= 0:
				view.set_ghost(CarBoardView.trace(base, results[worst_dir][2]))
				hover_label.text = _drop_sentence(who, worst_dir, worst, results[worst_dir][1])
			elif not hints:
				hover_label.text = "[color=#8793a6]Hints are off. Press H to see what each tilt would do here.[/color]"
	view.refresh()


func _set_arrow_swing(d: int, swing: int) -> void:
	view.arrow_text[d] = ("%+d" % swing) if swing != 0 else "0"
	view.arrow_text[d] = view.arrow_text[d].replace("-", "−")
	view.arrow_text_col[d] = GOOD if swing > 0 else (BAD if swing < 0 else DIM)


func _tilt_sentence(who: int, d: int, l: Array) -> String:
	var mine: int = l[who]
	var theirs: int = l[1 - who]
	var s := "[b]Tilt %s:[/b] " % CarRules.DIR_NAMES[d]
	if mine + theirs == 0:
		return s + "everything slides, nothing is crushed."
	var bits: Array[String] = []
	if theirs > 0:
		bits.append("crushes [color=#7fdc92]%s of %s's[/color]" % [_plural(theirs, "stone", "stones"), _name(1 - who)])
	if mine > 0:
		bits.append("crushes [color=#f2695b]%s of yours[/color]" % _plural(mine, "stone", "stones"))
	return s + " and ".join(bits) + "."


func _drop_sentence(who: int, d: int, worst: int, l: Array) -> String:
	var mine: int = l[who]
	var theirs: int = l[1 - who]
	if worst <= 0:
		if worst < 0:
			return "[b]Drop here:[/b] [color=#7fdc92]every tilt they can make costs them.[/color] Their least bad is %s." % CarRules.DIR_NAMES[d]
		return "[b]Drop here:[/b] no tilt can hurt you more than it hurts them."
	return "[b]Drop here:[/b] their best tilt is [b]%s[/b]: it crushes [color=#f2695b]%s of yours[/color]%s." % [
		CarRules.DIR_NAMES[d], _plural(mine, "stone", "stones"),
		"" if theirs == 0 else " and %s of theirs" % _plural(theirs, "stone", "stones")]
