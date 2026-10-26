extends SceneTree

const MainScene = preload("res://Main.tscn")
const State = preload("res://GameState.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.state.phase == State.MOVE)
	var first: int = main.state.legal_destinations()[0]
	_click(main, main._point(first))
	assert(main.state.phase == State.CUT)
	assert(main.history.size() == 1)
	var cut_index: int = main.state.legal_cuts()[0]
	var edge: Vector2i = main.state.edges[cut_index]
	_click(main, main._point(edge.x).lerp(main._point(edge.y), 0.55))
	assert(main.state.threads_left() == 41)
	assert(main.state.turn == 1)
	await create_timer(1.5).timeout
	assert(main.state.turn == 0 or main.state.winner != -1)
	assert(main.state.moves_played == 2 or main.state.winner != -1)
	main._undo()
	assert(main.state.moves_played == 0)
	assert(main.state.turn == 0)
	main._toggle_mode()
	assert(not main.vs_ai)
	assert(main.state.moves_played == 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8750
	while main.state.winner == -1:
		var destinations: PackedInt32Array = main.state.legal_destinations()
		var destination: int = destinations[rng.randi_range(0, destinations.size() - 1)]
		_click(main, main._point(destination))
		assert(main.state.phase == State.CUT)
		var choices: PackedInt32Array = main.state.legal_cuts()
		var selected: int = choices[rng.randi_range(0, choices.size() - 1)]
		var segment: Vector2i = main.state.edges[selected]
		_click(main, main._point(segment.x).lerp(main._point(segment.y), 0.55))
		assert(main.state.moves_played <= 42)
	assert(main.state.winner == 0 or main.state.winner == 1)
	main._new_game()
	assert(main.state.winner == -1)
	assert(main.state.moves_played == 0)
	print("UI flow: step, cut, AI reply, undo, mode switch, full game, restart passed")
	quit()


func _click(main, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	main._unhandled_input(event)
