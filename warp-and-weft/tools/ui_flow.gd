extends SceneTree
## Drives the real scene with real mouse events. Run:
##   godot --headless --path warp-and-weft -s tools/ui_flow.gd
## Exits with code 1 if anything fails.

var failures := 0
var checks := 0
var main: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


func click_cell(cell: int) -> void:
	var v: WWBoardView = main.view
	var p := v.global_position + v.cell_center(cell)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		root.push_input(ev, true)   # true: positions are already in viewport coordinates (headless window is 64x64)
	await process_frame


func move_mouse_to(cell: int) -> void:
	var v: WWBoardView = main.view
	var p := v.global_position + v.cell_center(cell)
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true)   # true: positions are already in viewport coordinates (headless window is 64x64)
	await process_frame


func press_key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev, true)
	await process_frame


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func play_out(max_wait_s: float) -> void:
	# Human clicks a random legal cell whenever it is a human's turn; the computer answers by itself.
	var t := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while not main.rules.is_over() and t < max_wait_s:
		if main.view.can_click:
			var mv: PackedInt32Array = main.rules.moves()
			await click_cell(mv[rng.randi_range(0, mv.size() - 1)])
		await wait(0.1)
		t += 0.1


func _init() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# --- starts as: you are Weft vs the Medium computer ---------------------
	ok(main.rules.history.is_empty() and main.rules.shuttle == 24, "fresh game, shuttle in the centre")
	ok(main.view.can_click, "human may click at the start")

	# --- clicking a cell off the line is refused, with a message ------------
	await click_cell(0)   # corner: not in the centre row
	ok(main.rules.history.is_empty(), "off-line click changes nothing")
	ok(main.notice != "", "off-line click explains why")

	# --- hovering a legal cell describes the consequence ---------------------
	await move_mouse_to(25)
	ok(main.hover_label.text.begins_with("Land on"), "hover on a legal cell shows a preview: '%s'" % main.hover_label.text)

	# --- a legal click plays, then the computer answers ----------------------
	await click_cell(25)
	ok(main.rules.history.size() == 1 and main.rules.shuttle == 25, "legal click plays the move")
	ok(not main.view.can_click, "no clicking while the computer thinks")
	await wait(1.6)
	ok(main.rules.history.size() == 2, "computer replied (history %d)" % main.rules.history.size())
	ok(main.view.can_click, "human may click again")

	# --- undo takes back both plies -----------------------------------------
	main._on_undo()
	ok(main.rules.history.is_empty() and main.rules.turn == WWRules.WEFT, "undo returns to the human's turn")
	ok(main.undo_button.disabled, "undo is disabled with nothing to undo")

	# --- play a whole game against each level --------------------------------
	for lv in [WWAI.Level.EASY, WWAI.Level.MEDIUM, WWAI.Level.HARD]:
		main.level = lv
		main.new_game(false)
		await process_frame
		await play_out(60.0)
		ok(main.rules.is_over(), "game vs level %d reaches the end" % lv)
		ok(main.view.banner_title != "", "result banner shown")
		ok(main.status_label.text.ends_with("wins.") or main.status_label.text == "Draw.", "status shows the result: '%s'" % main.status_label.text)

	# --- you are Warp: the computer opens as Weft ----------------------------
	main.level = WWAI.Level.EASY
	main._on_mode_selected(WWRules.WARP + 0)   # index 1 == "You: Warp"
	ok(main.mode == main.Mode.YOU_WARP, "mode switched")
	await wait(1.4)
	ok(main.rules.history.size() == 1 and main.rules.history[0]["who"] == WWRules.WEFT, "computer opened as Weft")
	ok(main.undo_button.disabled, "cannot undo the computer's opening")
	await play_out(60.0)
	ok(main.rules.is_over(), "game as Warp reaches the end")

	# --- switching mode mid-think must not let a stale computer move land -----
	main._on_mode_selected(main.Mode.YOU_WEFT)
	await click_cell(26)
	main._on_mode_selected(main.Mode.TWO_PLAYERS)   # restarts; the pending computer move must be dropped
	await wait(1.5)
	ok(main.rules.history.is_empty(), "stale computer move was discarded (history %d)" % main.rules.history.size())

	# --- two players on one screen -------------------------------------------
	await click_cell(26)
	ok(main.rules.history.size() == 1 and main.rules.turn == WWRules.WARP, "two-player: Weft moved")
	await click_cell(3 * 7 + 5 + 7)  # Warp slides down column 5
	ok(main.rules.history.size() == 2 and main.rules.turn == WWRules.WEFT, "two-player: Warp moved")
	main._on_undo()
	ok(main.rules.history.size() == 1, "two-player undo takes back one ply")
	await play_out(20.0)
	ok(main.rules.is_over(), "two-player game reaches the end")

	# --- keyboard: R starts over, same board keeps the seed -------------------
	var seed_before: int = main.board_seed
	main.new_game(true)
	ok(main.board_seed == seed_before and main.rules.history.is_empty(), "same board keeps its number")
	main.new_game(false)
	ok(main.rules.history.is_empty(), "new game clears the board")

	# --- keyboard shortcuts ---------------------------------------------------
	main.mode = main.Mode.TWO_PLAYERS
	main.new_game(false)
	await press_key(KEY_F1)
	ok(main.rules_overlay.visible, "F1 opens the rules")
	await press_key(KEY_ESCAPE)
	ok(not main.rules_overlay.visible, "Esc closes the rules")
	await press_key(KEY_H)
	ok(not main.hints, "H turns hints off")
	await press_key(KEY_H)
	ok(main.hints, "H turns hints back on")
	await click_cell(26)
	ok(main.rules.history.size() == 1, "setup: one move played")
	await press_key(KEY_U)
	ok(main.rules.history.is_empty(), "U undoes")
	await click_cell(26)
	var seed_k: int = main.board_seed
	await press_key(KEY_S)
	ok(main.rules.history.is_empty() and main.board_seed == seed_k, "S restarts on the same board")
	await press_key(KEY_R)
	ok(main.rules.history.is_empty(), "R starts a new game")

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
