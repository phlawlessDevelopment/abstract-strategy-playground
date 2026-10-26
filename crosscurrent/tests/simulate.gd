extends SceneTree

const GameState = preload("res://GameState.gd")


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47291
	var wins := [0, 0, 0]
	for game_number in range(1000):
		var game := GameState.new()
		while not game.finished:
			var empty: Array[int] = []
			for cell in range(25):
				if game.can_place(cell):
					empty.append(cell)
			assert(not empty.is_empty())
			var cell := empty[rng.randi_range(0, empty.size() - 1)]
			var direction := rng.randi_range(0, 3)
			assert(game.play(cell, direction))
			assert(game.board.count(1) + game.board.count(2) == game.moves)
		assert(game.moves == 20)
		assert(game.board.count(1) == 10 and game.board.count(2) == 10)
		assert(not game.can_place(game.board.find(0)))
		wins[game.winner] += 1
	print("1000 complete games: draws=%d coral=%d teal=%d" % wins)
	quit()
