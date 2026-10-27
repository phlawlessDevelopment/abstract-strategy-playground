extends Control

const Rules = preload("res://scripts/rules.gd")
const Opponent = preload("res://scripts/opponent.gd")
const Board = preload("res://scripts/board.gd")
const TEXT = Color("e7ece8")
const MUTED = Color("8ca4ae")
const GOLD = Color("edd39a")
const EMBER = Color("f29b7c")
const JADE = Color("7ad5c5")
const NAMES = ["", "Ember", "Jade"]

var rules := Rules.new()
var opponent := Opponent.new(rules)
var state: Rules.Position
var history: Array = []
var board: Control
var mode: OptionButton
var turn_label: Label
var move_label: Label
var instruction: Label
var scores: Array[Label] = []
var placed: Array[Label] = []
var deltas: Array[Label] = []
var last_move: Label
var footer: Label
var undo_button: Button
var hint_button: Button
var rules_dialog: AcceptDialog
var restart_dialog: ConfirmationDialog
var busy: bool = false
var bot_mode: bool = true
var human_player: int = 1
var revision: int = 0
var game_over: bool = false

func _ready() -> void:
	_bind_controller()
	_build_theme()
	_build_ui()
	new_game()

func _bind_controller() -> void:
	# This engine's built-in ui_* actions contain keyboard events only.
	var bindings := {
		"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B,
		"ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN,
		"lantern_previous": JOY_BUTTON_LEFT_SHOULDER,
		"lantern_next": JOY_BUTTON_RIGHT_SHOULDER,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventJoypadButton.new()
		event.button_index = bindings[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)

func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font_size = 16
	skin.set_color("font_color", "Label", TEXT)
	skin.set_color("font_color", "Button", TEXT)
	skin.set_color("font_hover_color", "Button", GOLD)
	skin.set_color("font_pressed_color", "Button", GOLD)
	skin.set_color("font_disabled_color", "Button", Color("516670"))
	for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("182a34") if kind == "normal" else Color("223b45")
		if kind == "disabled":
			style.bg_color = Color("101e27")
		if kind == "focus":
			style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color("405862") if kind in ["hover", "focus"] else Color("2a414d")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		skin.set_stylebox(kind, "Button", style)
		skin.set_stylebox(kind, "OptionButton", style)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("111f28")
	panel.border_color = Color("29404a")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(9)
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 17
	panel.content_margin_bottom = 17
	skin.set_stylebox("panel", "PanelContainer", panel)
	theme = skin

func _label(text_value: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	return button

func _stack(separation: int = 10) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", separation)
	return stack

func _row(separation: int = 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	return row

func _expand(parent: Node) -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer

func _card(parent: Node, separation: int = 8) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var content := _stack(separation)
	panel.add_child(content)
	return content

func _build_ui() -> void:
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 32)
	margins.add_theme_constant_override("margin_right", 32)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_bottom", 20)
	add_child(margins)
	var root := _stack(16)
	margins.add_child(root)
	var header := _row(20)
	root.add_child(header)
	var title := _stack(1)
	header.add_child(title)
	title.add_child(_label("A GAME OF SHARED LANTERNS", 11, GOLD))
	title.add_child(_label("Borrowed Light", 42))
	title.add_child(_label("Slide a lantern. Leave a stone. Only light scores.", 15, MUTED))
	_expand(header)
	var controls := _row(10)
	controls.alignment = BoxContainer.ALIGNMENT_END
	controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(controls)
	controls.add_child(_button("How to play  ?", func() -> void: rules_dialog.popup_centered(Vector2i(620, 550))))
	controls.add_child(_button("New game  R", _request_restart))
	var line := HSeparator.new()
	line.modulate = Color("34505c")
	root.add_child(line)
	var content := _row(24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var board_column := _stack(8)
	board_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(board_column)
	board = Board.new()
	board.rules = rules
	board.custom_minimum_size = Vector2(650, 500)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_column.add_child(board)
	board.move_chosen.connect(_perform_move)
	board.preview_changed.connect(_update_preview)
	board.selection_changed.connect(func(_lantern: int) -> void: _update_instruction())
	var legend := _row(18)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	board_column.add_child(legend)
	for entry in [[Board.SUN, "Shared lantern", GOLD], [Board.DISC, "Ember", EMBER], [Board.DIAMOND, "Jade", JADE]]:
		var group := _row(4)
		legend.add_child(group)
		var icon := TextureRect.new()
		icon.texture = entry[0]
		icon.modulate = entry[2]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(19, 19)
		group.add_child(icon)
		group.add_child(_label(entry[1], 13, entry[2]))
	legend.add_child(_label("Bright = scores · dim = shadow", 12, MUTED))
	var side := _stack(12)
	side.custom_minimum_size.x = 320
	content.add_child(side)
	var mode_row := _row(8)
	side.add_child(mode_row)
	mode = OptionButton.new()
	mode.add_item("Solo · play first as Ember")
	mode.add_item("Solo · play second as Jade")
	mode.add_item("Two players · same screen")
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode.focus_mode = Control.FOCUS_NONE
	mode.item_selected.connect(func(index: int) -> void:
		bot_mode = index < 2
		human_player = index + 1 if bot_mode else 1
		new_game())
	mode_row.add_child(mode)
	var turn := _card(side, 5)
	move_label = _label("MOVE 01", 11, GOLD)
	turn.add_child(move_label)
	turn_label = _label("Your turn", 26, EMBER)
	turn.add_child(turn_label)
	instruction = _label("", 14, MUTED)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size.y = 44
	turn.add_child(instruction)
	var score_card := _card(side, 8)
	score_card.add_child(_label("IN THE LIGHT", 11, GOLD))
	var score_row := _row(24)
	score_card.add_child(score_row)
	for player in [1, 2]:
		var column := _stack(0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score_row.add_child(column)
		var color := EMBER if player == 1 else JADE
		column.add_child(_label(NAMES[player], 15, color))
		var number_row := _row(8)
		column.add_child(number_row)
		var score := _label("0", 44, color)
		scores.append(score)
		number_row.add_child(score)
		var delta := _label("", 17, GOLD)
		delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		deltas.append(delta)
		number_row.add_child(delta)
		var count := _label("0 placed", 12, MUTED)
		placed.append(count)
		column.add_child(count)
	score_card.add_child(_label("One point per lit stone. Counted once.", 12, MUTED))
	last_move = _label("Choose any of the three lanterns.", 13, MUTED)
	last_move.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_move.custom_minimum_size.y = 38
	side.add_child(last_move)
	var action_row := _row(8)
	side.add_child(action_row)
	undo_button = _button("Undo  U", _undo)
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(undo_button)
	hint_button = _button("Hint  H", _hint)
	hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(hint_button)
	var rays_button := CheckButton.new()
	rays_button.text = "Show light rays"
	rays_button.button_pressed = true
	rays_button.focus_mode = Control.FOCUS_NONE
	rays_button.add_theme_font_size_override("font_size", 13)
	rays_button.toggled.connect(func(value: bool) -> void:
		board.show_rays = value
		board.queue_redraw())
	side.add_child(rays_button)
	var foot_row := _row()
	root.add_child(foot_row)
	footer = _label("", 12, MUTED)
	foot_row.add_child(footer)
	_expand(foot_row)
	foot_row.add_child(_label("1 / 2 / 3 select · arrows preview · Enter move · Esc cancel", 11, MUTED))
	_build_dialogs()

func _build_dialogs() -> void:
	rules_dialog = AcceptDialog.new()
	rules_dialog.title = "Borrowed Light · how to play"
	rules_dialog.dialog_autowrap = true
	rules_dialog.ok_button_text = "Let there be light"
	var help := RichTextLabel.new()
	help.custom_minimum_size = Vector2(560, 430)
	help.bbcode_enabled = true
	help.add_theme_font_size_override("normal_font_size", 15)
	help.add_theme_color_override("default_color", TEXT)
	help.text = "[color=#edd39a]MOVE THE LIGHT. LEAVE YOUR MARK.[/color]\n\nEmber plays circles; Jade plays diamonds. All three golden lanterns are shared.\n\n[color=#edd39a]ON YOUR TURN[/color]\n1. Click any lantern that can move.\n2. Slide to a highlighted space in one of its six straight directions. You cannot jump stones or lanterns.\n3. Leave your stone in the space the lantern started from.\n\n[color=#edd39a]ONLY LIGHT SCORES[/color]\nEach lantern shines in six directions. The first stone in each ray scores one point. Stones and lanterns block light. A stone lit several times still scores just once. Dark stones score zero.\n\nHover over a destination to preview the lighting and score changes. Moving a different lantern may relight an old stone.\n\n[color=#edd39a]ALL THREE TRAPPED = GAME OVER[/color]\nMost lit stones wins. Equal scores draw. The score during play is provisional. Every move fills a space, so the game always ends.\n\n[color=#edd39a]CONTROLS[/color]\nR: new game / U: undo / H: hint / ?: rules\n1-3 or LB/RB: select lantern / Arrows or D-pad: preview destinations\nEnter or A: move / Escape, right-click, or B: cancel"
	rules_dialog.add_child(help)
	add_child(rules_dialog)
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "Start a fresh board?"
	restart_dialog.dialog_text = "The current game will be replaced."
	restart_dialog.ok_button_text = "New game"
	restart_dialog.confirmed.connect(new_game)
	add_child(restart_dialog)

func new_game() -> void:
	revision += 1
	state = rules.initial()
	history.clear()
	busy = false
	game_over = false
	board.last_from = -1
	board.last_to = -1
	board.set_position_state(state)
	last_move.text = "Choose any of the three lanterns."
	_update()
	_maybe_bot()

func _request_restart() -> void:
	if state.ply == 0 or game_over:
		new_game()
	else:
		restart_dialog.popup_centered()

func _perform_move(move: Vector2i) -> void:
	if busy or game_over or not move in rules.legal_moves(state):
		return
	var from: int = state.lanterns[move.x]
	var player: int = state.player
	history.append({"state": state, "from": board.last_from, "to": board.last_to, "text": last_move.text})
	state = rules.play(state, move)
	board.set_position_state(state)
	board.last_from = from
	board.last_to = move.y
	last_move.text = "%s moved lantern %d\n%s to %s · a %s stone left behind." % [
		NAMES[player], move.x + 1, rules.cell_name(from), rules.cell_name(move.y), NAMES[player].to_lower()]
	busy = true
	game_over = rules.is_over(state)
	var token: int = revision
	_update()
	board.animate_move(move.x, from)
	# A separate timer also finishes if Undo cancels the visual tween.
	await get_tree().create_timer(0.25).timeout
	if token != revision:
		return
	busy = false
	_update()
	_maybe_bot()

func _maybe_bot() -> void:
	if not bot_mode or state.player == human_player or game_over:
		return
	busy = true
	_update()
	var token: int = revision
	await get_tree().create_timer(0.4).timeout
	if token != revision:
		return
	var move: Vector2i = opponent.choose(state)
	busy = false
	_perform_move(move)

func _update() -> void:
	var score: Vector2i = rules.scores(state)
	scores[0].text = str(score.x)
	scores[1].text = str(score.y)
	for i in 2:
		placed[i].text = "%d placed" % state.stones.count(i + 1)
		deltas[i].text = ""
	var color := EMBER if state.player == 1 else JADE
	turn_label.add_theme_color_override("font_color", color)
	move_label.text = "MOVE %02d  ·  %s" % [state.ply + 1, NAMES[state.player].to_upper()]
	var bot_turn: bool = bot_mode and state.player != human_player
	turn_label.text = "%s to move" % NAMES[state.player]
	if bot_mode:
		turn_label.text = "Thinking…" if bot_turn else "Your turn"
	if game_over:
		var winner: int = rules.winner(state)
		move_label.text = "ALL THREE LANTERNS ARE TRAPPED"
		turn_label.text = "A perfect tie" if winner == 0 else "%s wins" % NAMES[winner]
		turn_label.add_theme_color_override("font_color", GOLD if winner == 0 else (EMBER if winner == 1 else JADE))
	board.locked = busy or game_over or bot_turn
	undo_button.disabled = history.is_empty() or (bot_mode and not _has_human_decision())
	hint_button.disabled = busy or game_over or bot_turn
	_update_instruction()
	var moves: Array[Vector2i] = rules.legal_moves(state)
	footer.text = "%d / 34 stones placed  ·  %s" % [state.ply,
		"Final score" if game_over else "%d legal slides" % moves.size()]
	board.queue_redraw()

func _update_instruction() -> void:
	if game_over:
		instruction.text = "Final light: %d – %d. Start a new game to try another approach." % [rules.scores(state).x, rules.scores(state).y]
	elif busy and bot_mode and state.player != human_player:
		instruction.text = "The computer is finding a way through the shadows."
	elif board.selected >= 0:
		instruction.text = "Lantern %d · %d destinations. Hover to preview, click to move." % [board.selected + 1, board.legal.size()]
	else:
		instruction.text = "Choose a golden lantern. Both players can move all three."

func _update_preview(move: Vector2i) -> void:
	for delta in deltas:
		delta.text = ""
	if move.x < 0:
		return
	var before: Vector2i = rules.scores(state)
	var after: Vector2i = rules.scores(rules.apply_legal(state, move))
	var change: Vector2i = after - before
	for i in 2:
		var value: int = change.x if i == 0 else change.y
		deltas[i].text = "(%+d)" % value if value != 0 else "(=)"

func _undo() -> void:
	if history.is_empty() or (bot_mode and not _has_human_decision()):
		return
	revision += 1
	var previous: Dictionary = history.pop_back()
	# In solo play, return to the human's previous decision, including when
	# undo is pressed during the computer's delay or after the ending.
	while bot_mode and previous.state.player != human_player and not history.is_empty():
		previous = history.pop_back()
	state = previous.state
	board.set_position_state(state)
	board.last_from = previous.from
	board.last_to = previous.to
	last_move.text = previous.text
	busy = false
	game_over = false
	_update()
	_maybe_bot()

func _has_human_decision() -> bool:
	for entry in history:
		if entry.state.player == human_player:
			return true
	return false

func _hint() -> void:
	if busy or game_over:
		return
	var move: Vector2i = opponent.choose(state, 2)
	board.select(move.x)
	board.hinted_move = move
	board._hover(move.y)
	instruction.text = "Try lantern %d to %s. This is a suggestion, not a forced win." % [move.x + 1, rules.cell_name(move.y)]
	board.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if rules_dialog.visible or restart_dialog.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_request_restart()
			KEY_U:
				_undo()
			KEY_H:
				_hint()
			KEY_SLASH, KEY_QUESTION:
				rules_dialog.popup_centered(Vector2i(620, 550))
			KEY_1, KEY_2, KEY_3:
				if not board.locked:
					board.select(event.keycode - KEY_1)
				return
	if board.locked:
		return
	if event.is_action_pressed("ui_cancel"):
		board.select(-1)
	elif event.is_action_pressed("lantern_next") or event.is_action_pressed("lantern_previous"):
		var direction: int = 1 if event.is_action_pressed("lantern_next") else -1
		board.select(posmod(board.selected + direction, 3))
		board.navigate(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		board.navigate(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		board.navigate(1)
	elif event.is_action_pressed("ui_accept"):
		board.accept()
