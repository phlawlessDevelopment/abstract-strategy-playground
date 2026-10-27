extends SceneTree
## Exercise actual scene/input callbacks, asynchronous turns, undo, and ending.

const MainScene = preload("res://scenes/main.tscn")
var game: Control
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1200, 800)
	root.content_scale_size = Vector2i(1200, 800)
	game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.rules_dialog.popup_centered(Vector2i(620, 550))
	await process_frame
	check(game.rules_dialog.size.y <= 800, "Rules dialog fits within the game viewport")
	game.rules_dialog.hide()
	game.bot_mode = false
	game.new_game()
	var board: Control = game.board
	var move: Vector2i = game.rules.legal_moves(game.state)[0]
	board._click(game.state.lanterns[move.x])
	check(board.selected == move.x and move.y in board.legal, "Selecting highlights legal slides")
	board._hover(move.y)
	check(board.preview != null and game.state.ply == 0, "Hover previews without committing")
	check(game.deltas[0].text == "(+1)", "Preview shows the score change")
	board._click(move.y)
	check(game.state.ply == 1 and board.locked, "Click commits and locks during animation")
	game._undo()
	await create_timer(0.35).timeout
	check(game.state.ply == 0 and not game.busy, "Undo cancels an in-flight animation")
	game.bot_mode = true
	game.new_game()
	board._click(game.state.lanterns[move.x])
	board._click(move.y)
	await create_timer(0.3).timeout
	check(game.busy and game.state.ply == 1, "Computer delay starts after the human's move")
	game._undo()
	await create_timer(0.6).timeout
	check(game.state.ply == 0 and not game.busy, "Undo cancels a pending computer move")
	board._click(game.state.lanterns[move.x])
	board._click(move.y)
	await create_timer(1.5).timeout
	check(game.state.ply == 2 and game.state.player == 1, "Computer responds with a legal slide")
	game._undo()
	check(game.state.ply == 0, "Solo undo restores the full human decision")
	game.human_player = 2
	game.new_game()
	await create_timer(1.5).timeout
	check(game.state.ply == 1 and game.state.player == 2, "Solo can play the second seat")
	check(game.undo_button.disabled, "Computer opening cannot be undone without a human decision")
	game.bot_mode = false
	game.new_game()
	game._hint()
	check(board.hinted_move in game.rules.legal_moves(game.state), "Hint is legal")
	board.select(-1)
	board.navigate(1)
	check(board.hover_cell in board.legal, "Keyboard/controller navigation previews a legal slide")
	board.accept()
	await create_timer(0.3).timeout
	check(game.state.ply == 1, "Keyboard/controller accept commits the preview")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
	joy.pressed = true
	Input.parse_input_event(joy)
	await process_frame
	check(board.selected == 0 and board.hover_cell in board.legal, "Controller bumper selects a lantern and previews a destination")
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	Input.parse_input_event(joy)
	await create_timer(0.3).timeout
	check(game.state.ply == 2, "An actual controller event commits the preview")
	while not game.game_over:
		var moves: Array[Vector2i] = game.rules.legal_moves(game.state)
		move = moves[0]
		board._click(game.state.lanterns[move.x])
		board._click(move.y)
		await create_timer(0.28).timeout
	check(board.locked and game.hint_button.disabled, "Ending locks the board")
	check("wins" in game.turn_label.text or "tie" in game.turn_label.text, "Ending displays the result")
	var score: Vector2i = game.rules.scores(game.state)
	check(game.scores[0].text == str(score.x) and game.scores[1].text == str(score.y), "Final displayed scores agree with rules")
	print("UI GAME FINISHED: ", game.state.ply, " moves, ", game.turn_label.text, " ", score)
	game._undo()
	check(not game.game_over and not board.locked, "Undo reopens a finished game")
	game.new_game()
	check(game.state.ply == 0 and game.history.is_empty(), "Restart restores the opening")
	game.free()
	print("PASS UI ", checks, " checks")
	quit(0)
