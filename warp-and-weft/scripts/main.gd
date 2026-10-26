extends Control
## Warp & Weft: window layout, controls and turn flow. Rules live in rules.gd,
## the computer in ai.gd, drawing in board_view.gd.

const COL_WEFT := WWBoardView.COL_WEFT
const COL_WARP := WWBoardView.COL_WARP
const INK := WWBoardView.INK
const LINEN := WWBoardView.LINEN
const SLATE := WWBoardView.SLATE
const CARD_BG := Color("#f6efdd")
const BTN_BG := Color("#e6dbc0")

enum Mode { YOU_WEFT, YOU_WARP, TWO_PLAYERS }

var rules: WWRules
var ai := WWAI.new()
var view: WWBoardView

var mode: int = Mode.YOU_WEFT
var level: int = WWAI.Level.MEDIUM
var hints: bool = true
var board_seed: int = 0

var thinking: bool = false
var game_id: int = 0          # bumped whenever a pending computer move must be forgotten
var notice: String = ""       # one-off complaint, e.g. after clicking a cell that is not on your line
var hover_cell: int = -1

var score_labels: Array[Label] = []
var caption_labels: Array[Label] = []
var cards: Array[PanelContainer] = []
var card_styles: Array[StyleBoxFlat] = []
var lead_label: Label
var status_label: Label
var how_label: Label
var last_label: Label
var hover_label: Label
var footer_label: Label
var mode_button: OptionButton
var level_button: OptionButton
var undo_button: Button
var hints_button: Button
var rules_overlay: Control


# A small double arrow: sideways for Weft, up/down for Warp.
class AxisIcon extends Control:
	var who: int = 0

	func _init(p_who: int) -> void:
		who = p_who
		custom_minimum_size = Vector2(60, 60)

	func _draw() -> void:
		var col := WWBoardView.COL_WEFT if who == WWRules.WEFT else WWBoardView.COL_WARP
		var c := size / 2.0
		var d := Vector2(1, 0) if who == WWRules.WEFT else Vector2(0, 1)
		var p := Vector2(-d.y, d.x)
		draw_line(c - d * 22.0, c + d * 22.0, col, 5.0, true)
		for s in [-1.0, 1.0]:
			var tip: Vector2 = c + d * 22.0 * s
			draw_line(tip, tip - d * 11.0 * s + p * 9.0, col, 5.0, true)
			draw_line(tip, tip - d * 11.0 * s - p * 9.0, col, 5.0, true)


func _ready() -> void:
	_build_ui()
	new_game()


# --- naming helpers -----------------------------------------------------------

func _name(who: int) -> String:
	return "Weft" if who == WWRules.WEFT else "Warp"


func _line_word(who: int) -> String:
	return "row" if who == WWRules.WEFT else "column"


func _col(who: int) -> Color:
	return COL_WEFT if who == WWRules.WEFT else COL_WARP


func is_human(who: int) -> bool:
	return mode == Mode.TWO_PLAYERS or (mode == Mode.YOU_WEFT and who == WWRules.WEFT) or (mode == Mode.YOU_WARP and who == WWRules.WARP)


# --- UI construction ----------------------------------------------------------

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(10)
			sb.set_border_width_all(2)
			sb.border_color = Color("#bba983")
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			sb.bg_color = BTN_BG
			if state == "hover":
				sb.bg_color = Color("#f0e7cf")
				sb.border_color = INK
			elif state == "pressed":
				sb.bg_color = Color("#d6c8a3")
			elif state == "disabled":
				sb.bg_color = Color("#e6dbc0", 0.5)
				sb.border_color = Color("#bba983", 0.5)
			t.set_stylebox(state, type, sb)
		var focus := StyleBoxEmpty.new()
		t.set_stylebox("focus", type, focus)
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
	card.size = Vector2(434, 100)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.bg_color = CARD_BG
	sb.border_color = Color("#cfc2a2")
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
	row.add_child(AxisIcon.new(who))

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(names)
	var n := Label.new()
	n.text = _name(who)
	n.add_theme_font_size_override("font_size", 30)
	n.add_theme_color_override("font_color", _col(who))
	names.add_child(n)
	var role := Label.new()
	role.text = "slides sideways" if who == WWRules.WEFT else "slides up and down"
	role.add_theme_font_size_override("font_size", 16)
	role.add_theme_color_override("font_color", SLATE)
	names.add_child(role)

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
	cap.add_theme_color_override("font_color", SLATE)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nums.add_child(cap)
	score_labels.append(big)
	caption_labels.append(cap)


func _build_ui() -> void:
	theme = _build_theme()

	_label("Warp & Weft", 46, INK, 56, 22, 600, 60)
	_label("one shuttle, two directions", 18, SLATE, 59, 72, 600, 26)

	view = WWBoardView.new()
	view.position = Vector2(56, 110)
	add_child(view)
	view.cell_clicked.connect(_on_cell_clicked)
	view.cell_hovered.connect(_on_hover)

	_make_card(WWRules.WEFT, 110)
	_make_card(WWRules.WARP, 222)

	lead_label = _label("", 18, SLATE, 790, 334, 434, 26)
	status_label = _label("", 27, INK, 790, 364, 434, 44)
	how_label = _label("", 18, SLATE, 790, 408, 434, 84)
	last_label = _label("", 18, INK, 790, 498, 434, 30)
	hover_label = _label("", 19, INK, 790, 540, 434, 90)

	mode_button = OptionButton.new()
	mode_button.add_item("You: Weft")
	mode_button.add_item("You: Warp")
	mode_button.add_item("Two players")
	mode_button.position = Vector2(790, 640)
	mode_button.size = Vector2(212, 44)
	mode_button.item_selected.connect(_on_mode_selected)
	add_child(mode_button)

	level_button = OptionButton.new()
	level_button.add_item("Computer: Easy")
	level_button.add_item("Computer: Medium")
	level_button.add_item("Computer: Hard")
	level_button.select(level)
	level_button.position = Vector2(1012, 640)
	level_button.size = Vector2(212, 44)
	level_button.item_selected.connect(_on_level_selected)
	add_child(level_button)

	_button("New game", 790, 694, 138, func(): new_game(false))
	_button("Same board", 938, 694, 138, func(): new_game(true))
	undo_button = _button("Undo", 1086, 694, 138, _on_undo)
	hints_button = _button("Hints: on", 790, 744, 212, _toggle_hints)
	_button("Rules  (F1)", 1012, 744, 212, func(): _set_rules_open(true))

	footer_label = _label("", 14, Color(SLATE, 0.85), 790, 794, 434, 22)

	_build_rules_overlay()


func _build_rules_overlay() -> void:
	rules_overlay = Control.new()
	rules_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules_overlay.visible = false
	add_child(rules_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.06, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules_overlay.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules_overlay.add_child(centre)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(780, 0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(20)
	sb.bg_color = LINEN
	sb.set_border_width_all(3)
	sb.border_color = INK
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
	body.add_theme_font_size_override("normal_font_size", 18)
	body.add_theme_font_size_override("bold_font_size", 18)
	body.add_theme_font_size_override("italics_font_size", 18)
	body.add_theme_color_override("default_color", INK)
	body.text = "One [b]shuttle[/b] rests in the middle of a grid of numbers.\n\n" \
		+ "[color=#b5402f][b]Weft[/b][/color] may only slide it [b]sideways[/b], along its row.\n" \
		+ "[color=#2d4f8f][b]Warp[/b][/color] may only slide it [b]up or down[/b], along its column.\n\n" \
		+ "On your turn, slide the shuttle to any unused cell on your line (hopping over used cells is fine). You [b]score that number[/b] and the cell is used up. A few numbers are negative.\n\n" \
		+ "[b]Where you land decides your opponent's options:[/b] they must pick from the line that crosses your cell. Take the big number, or leave them a poor line?\n\n" \
		+ "The game ends the moment the player to move has [b]no unused cell on their line[/b]. Most points wins. Cells left on the board are worth nothing, so ending the game early is a weapon.\n\n" \
		+ "Weft moves first, so Warp starts with a [b]4.5-point komi[/b]. The board mirrors across its diagonal, so both sides see the same world.\n\n" \
		+ "[i]Hover a lit cell to preview the line you would hand over.[/i]"
	col.add_child(body)
	var close := Button.new()
	close.text = "Got it  (Esc)"
	close.custom_minimum_size = Vector2(180, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func(): _set_rules_open(false))
	col.add_child(close)


func _set_rules_open(open: bool) -> void:
	rules_overlay.visible = open


# --- game flow ----------------------------------------------------------------

func new_game(same_board: bool = false) -> void:
	if not same_board or board_seed == 0:
		board_seed = randi() % 900000 + 100000
	rules = WWRules.new(WWRules.make_board(board_seed))
	notice = ""
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


func _computer_turn() -> void:
	var gid := game_id
	thinking = true
	_refresh()
	await get_tree().create_timer(0.55).timeout
	if gid != game_id:
		return
	await get_tree().process_frame   # let "thinking" paint before the search blocks
	if gid != game_id:
		return
	var pick := ai.choose(rules, level)
	thinking = false
	_play(pick)


func _play(cell: int) -> void:
	var who := rules.turn
	var gain := rules.values[cell]
	rules.play(cell)
	notice = ""
	view.animate_move(cell, who, gain)
	if rules.is_over():
		_show_result()
	_refresh()
	_maybe_computer()


func _on_cell_clicked(cell: int) -> void:
	if rules.is_over() or thinking or not is_human(rules.turn):
		return
	if rules.is_legal(cell):
		_play(cell)
	else:
		var who := rules.turn
		notice = "%s can only slide along the %s. Pick a lit cell." % [_name(who), _line_word(who)]
		_refresh()


func _on_hover(cell: int) -> void:
	hover_cell = cell
	_refresh_hover()


func _plies_to_undo() -> int:
	if rules.history.is_empty():
		return 0
	if mode == Mode.TWO_PLAYERS:
		return 1
	# Take back the human's last move and everything after it.
	var human := WWRules.WEFT if mode == Mode.YOU_WEFT else WWRules.WARP
	for k in range(rules.history.size() - 1, -1, -1):
		if rules.history[k]["who"] == human:
			return rules.history.size() - k
	return 0


func _on_undo() -> void:
	var count := _plies_to_undo()
	if count == 0:
		return
	for i in count:
		rules.undo()
	notice = ""
	view.snap_shuttle()
	_restart_flow()


func _on_mode_selected(idx: int) -> void:
	mode = idx
	new_game(true)   # same board, so the other seat can be tried


func _on_level_selected(idx: int) -> void:
	level = idx


func _toggle_hints() -> void:
	hints = not hints
	view.hints = hints
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
			new_game(false)
		KEY_S:
			new_game(true)
		KEY_U:
			_on_undo()
		KEY_H:
			_toggle_hints()


# --- text and state -------------------------------------------------------------

func _show_result() -> void:
	var w := rules.winner()
	var stranded := rules.turn
	var total_weft := float(rules.score[WWRules.WEFT])
	var total_warp := rules.score[WWRules.WARP] + rules.komi
	if w == 2:
		view.banner_title = "A draw"
		view.banner_color = INK
	else:
		view.banner_title = "%s wins" % _name(w)
		view.banner_color = _col(w)
	view.banner_sub = "%d to %.1f  -  %s has no cell left on their %s" % [int(total_weft), total_warp, _name(stranded), _line_word(stranded)]


func _refresh() -> void:
	var over := rules.is_over()
	var w := rules.winner()

	score_labels[WWRules.WEFT].text = str(rules.score[WWRules.WEFT])
	score_labels[WWRules.WARP].text = "%.1f" % (rules.score[WWRules.WARP] + rules.komi)
	caption_labels[WWRules.WEFT].text = "moves first"
	caption_labels[WWRules.WARP].text = "includes %.1f komi" % rules.komi

	for who in 2:
		var active := (not over and rules.turn == who) or (over and w == who)
		card_styles[who].border_color = _col(who) if active else Color("#cfc2a2")
		card_styles[who].bg_color = CARD_BG.lerp(_col(who), 0.10) if active else CARD_BG

	var margin := rules.margin()
	if rules.history.is_empty():
		lead_label.text = "Warp starts %.1f ahead (komi)   -   %d cells left" % [rules.komi, rules.cells_left()]
	elif margin > 0.0:
		lead_label.text = "Weft leads by %.1f   -   %d cells left" % [margin, rules.cells_left()]
	elif margin < 0.0:
		lead_label.text = "Warp leads by %.1f   -   %d cells left" % [-margin, rules.cells_left()]
	else:
		lead_label.text = "Level   -   %d cells left" % rules.cells_left()

	if over:
		var stranded := rules.turn
		if w == 2:
			status_label.text = "Draw."
		else:
			status_label.text = "%s wins." % _name(w)
		how_label.text = "%s has no unused cell on their %s, so the game is over. Press R for a new game." % [_name(stranded), _line_word(stranded)]
		status_label.add_theme_color_override("font_color", _col(w) if w != 2 else INK)
	else:
		var who := rules.turn
		status_label.add_theme_color_override("font_color", _col(who))
		if thinking:
			status_label.text = "The computer (%s) is thinking..." % _name(who)
		elif mode == Mode.TWO_PLAYERS:
			status_label.text = "%s to move" % _name(who)
		else:
			status_label.text = "Your move, %s" % _name(who)
		var n_lane := rules.moves().size()
		how_label.text = "Slide to one of the %d lit cells on this %s. Where you land chooses the %s your opponent must use." % [n_lane, _line_word(who), _line_word(1 - who)]
		if notice != "":
			how_label.text = notice

	if rules.history.is_empty():
		last_label.text = "The shuttle waits in the centre. Weft begins."
	else:
		var h: Dictionary = rules.history[-1]
		last_label.text = "%s slid %s and took %d." % [_name(h["who"]), _direction_word(h), h["gain"]]

	view.can_click = not over and not thinking and is_human(rules.turn)
	view.hints = hints
	view.refresh_cursor()
	if not over:
		view.banner_title = ""

	hints_button.text = "Hints: on" if hints else "Hints: off"
	undo_button.disabled = _plies_to_undo() == 0
	level_button.disabled = mode == Mode.TWO_PLAYERS
	level_button.select(level)
	mode_button.select(mode)
	footer_label.text = "Board #%d   R new  S same board  U undo  H hints" % board_seed
	_refresh_hover()


func _direction_word(h: Dictionary) -> String:
	var n := rules.n
	var a: int = h["from"]
	var b: int = h["to"]
	if h["who"] == WWRules.WEFT:
		return "right" if (b % n) > (a % n) else "left"
	return "down" if (b / n) > (a / n) else "up"


## What would happen if the player to move landed on the hovered cell?
func _refresh_hover() -> void:
	hover_label.text = ""
	var c := hover_cell
	if c < 0 or rules.is_over() or not view.can_click:
		return
	var who := rules.turn
	if not rules.is_legal(c):
		return
	var gain := rules.values[c]
	var other := 1 - who
	var text := "Land on %d." % gain if gain >= 0 else "Land on %d (it costs you %d)." % [gain, -gain]
	var reply := rules.reply_lane(c, who)
	if reply.is_empty():
		# The opponent would be stranded: the game ends on this move.
		var m := rules.margin() + (gain if who == WWRules.WEFT else -gain)
		var winner := WWRules.WEFT if m > 0.0 else WWRules.WARP
		text += " %s would have no cell left, so the game ends here. %s wins." % [_name(other), _name(winner)]
		if winner == who:
			hover_label.add_theme_color_override("font_color", Color("#2f7a3a"))
		else:
			hover_label.add_theme_color_override("font_color", Color("#a02a2a"))
	else:
		hover_label.add_theme_color_override("font_color", INK)
		if hints:
			var best := -1000
			for r in reply:
				best = maxi(best, rules.values[r])
			text += " %s's best reply: %d  (you net %+d)." % [_name(other), best, gain - best]
		else:
			text += " %s would choose from %d cells." % [_name(other), reply.size()]
	hover_label.text = text
