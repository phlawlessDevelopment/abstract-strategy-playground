extends SceneTree

const GAME = preload("res://Main.tscn")
const Rules = preload("res://Rules.gd")


func _initialize() -> void:
	call_deferred("_run")


func _click_hex(game: Control, index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game._position(game.board[index])
	game._gui_input(event)


func _run() -> void:
	var game := GAME.instantiate()
	root.add_child(game)
	await process_frame
	var first: Dictionary = Rules.legal_moves(game.path, game.used_vault, 0, game.board).front()
	_click_hex(game, first.to)
	assert(game.path.size() == 2)
	game._undo()
	assert(game.path.size() == 1)
	game._toggle_mode()
	_click_hex(game, first.to)
	await create_timer(0.8).timeout
	assert(game.path.size() == 3)
	assert(game.current_player == 0)
	game._toggle_mode()
	var turns := 0
	while game.winner < 0:
		var choices: Array[Dictionary] = Rules.legal_moves(game.path, game.used_vault, game.current_player, game.board)
		assert(not choices.is_empty())
		_click_hex(game, choices.front().to)
		turns += 1
		assert(turns <= 18)
	assert(game.path.size() == turns + 1)
	print("UI flow passed: click, undo, solo reply, and full game in ", turns, " moves")
	quit()
