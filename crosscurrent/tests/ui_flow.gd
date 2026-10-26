extends SceneTree

const GAME_SCENE = preload("res://Main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	assert(game.size == Vector2(1100, 740))
	for turn in range(20):
		var cell: int = game.state.board.find(0)
		_click(game, game._cell_center(cell))
		assert(game.selected == cell)
		var direction := turn % 4
		var arrow: Vector2 = game._arrow_center(direction)
		var motion := InputEventMouseMotion.new()
		motion.position = arrow
		game._input(motion)
		assert(game.hovered_arrow == direction)
		_click(game, arrow)
		assert(game.state.moves == turn + 1)
		assert(game.selected == -1)
	assert(game.state.finished)
	_click(game, Vector2(900, 580))
	assert(game.state.moves == 0 and not game.state.finished)
	print("UI flow: 20 placements, arrow previews, finished state, and restart passed")
	quit()


func _click(game: Control, point: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	game._input(click)
