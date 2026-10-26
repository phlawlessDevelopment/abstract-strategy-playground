extends SceneTree

const State = preload("res://GameState.gd")
const Opponent = preload("res://Opponent.gd")


func _initialize() -> void:
	var first_wins := 0
	var second_wins := 0
	var total_turns := 0
	for seed_value in 2000:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var state = State.new()
		assert(state.cells.size() == 19)
		assert(state.edges.size() == 42)
		while state.winner == -1:
			var destinations: PackedInt32Array = state.legal_destinations()
			assert(not destinations.is_empty())
			var previous_threads: int = state.threads_left()
			var destination: int = destinations[rng.randi_range(0, destinations.size() - 1)]
			assert(state.step_to(destination))
			var cuts: PackedInt32Array = state.legal_cuts()
			assert(not cuts.is_empty())
			assert(state.cut(cuts[rng.randi_range(0, cuts.size() - 1)]))
			assert(state.threads_left() == previous_threads - 1)
			assert(state.moves_played <= 42)
		first_wins += int(state.winner == 0)
		second_wins += int(state.winner == 1)
		total_turns += state.moves_played
	print("Random games: 2000 | Amber: %d | Teal: %d | Average turns: %.1f" % [first_wins, second_wins, float(total_turns) / 2000.0])

	# Exercise the solo opponent in complete games, including its search code.
	var ai_wins := 0
	for seed_value in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 4000
		var state = State.new()
		while state.winner == -1:
			var action := Vector2i(-1, -1)
			if state.turn == 1:
				action = Opponent.choose_turn(state)
			else:
				var destinations: PackedInt32Array = state.legal_destinations()
				var destination: int = destinations[rng.randi_range(0, destinations.size() - 1)]
				var step = state.copy()
				step.step_to(destination)
				var cuts: PackedInt32Array = step.legal_cuts()
				action = Vector2i(destination, cuts[rng.randi_range(0, cuts.size() - 1)])
			assert(state.step_to(action.x))
			assert(state.cut(action.y))
			assert(state.moves_played <= 42)
		ai_wins += int(state.winner == 1)
	print("Compass vs random: %d/40 wins" % ai_wins)
	quit()
