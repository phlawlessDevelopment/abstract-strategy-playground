extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Opponent = preload("res://scripts/opponent.gd")
var rules := Rules.new()
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	var state := rules.initial()
	check(rules.cells.size() == 37, "Radius-three board has 37 spaces")
	check(rules.scores(state) == Vector2i.ZERO, "Empty board scores zero")
	var first_move: Vector2i = rules.legal_moves(state)[0]
	var next := rules.play(state, first_move)
	check(state.ply == 0 and state.stones.count(1) == 0, "Moves do not mutate their parent")
	check(next.stones[state.lanterns[first_move.x]] == 1, "Leave a stone at departure")
	check(next.player == 2 and next.ply == 1, "Turn alternates")
	check(next.lanterns[first_move.x] == first_move.y, "Lantern reaches its destination")

	# An opaque stone hides every stone behind it, even from the same player.
	var fixture := rules.initial()
	fixture.lanterns = PackedInt32Array([rules.indices[Vector2i(-3, 0)],
		rules.indices[Vector2i(0, -3)], rules.indices[Vector2i(-3, 3)]])
	fixture.stones[rules.indices[Vector2i(-2, 0)]] = 1
	fixture.stones[rules.indices[Vector2i(-1, 0)]] = 2
	var light := rules.illuminated(fixture)
	check(light[rules.indices[Vector2i(-2, 0)]] == 1, "First stone catches light")
	check(light[rules.indices[Vector2i(-1, 0)]] == 0, "Stone behind is dark")
	check(rules.destinations(fixture, 0).find(rules.indices[Vector2i(0, 0)]) == -1,
		"Lantern cannot jump a stone")
	fixture.stones.fill(0)
	fixture.lanterns = PackedInt32Array([rules.indices[Vector2i(-2, 0)],
		rules.indices[Vector2i(2, 0)], rules.indices[Vector2i(0, 2)]])
	fixture.stones[rules.indices[Vector2i(0, 0)]] = 1
	check(rules.scores(fixture) == Vector2i(1, 0), "A stone illuminated twice scores once")
	fixture.stones.fill(1)
	for lantern in fixture.lanterns:
		fixture.stones[lantern] = 0
	check(rules.is_over(fixture), "Blocked lanterns end the game")
	check(rules.winner(fixture) == 1, "Terminal winner follows lit stones")

	var rng := RandomNumberGenerator.new()
	rng.seed = 61432
	var wins := [0, 0, 0]
	var lengths: Array[int] = []
	for game in 400:
		state = rules.initial()
		var moves := rules.legal_moves(state)
		while not moves.is_empty():
			var move: Vector2i = moves[rng.randi_range(0, moves.size() - 1)]
			var before_empty := state.stones.count(0)
			state = rules.play(state, move)
			check(state.stones.count(0) == before_empty - 1, "Each move consumes one empty cell")
			check(state.stones.count(1) + state.stones.count(2) == state.ply, "One stone per move")
			check(state.ply <= 34, "Games cannot exceed 34 moves")
			for lantern in state.lanterns:
				check(state.stones[lantern] == 0, "Lantern never overlaps a stone")
			var score := rules.scores(state)
			check(score.x <= state.stones.count(1) and score.y <= state.stones.count(2), "Scores count existing stones")
			moves = rules.legal_moves(state)
		wins[rules.winner(state)] += 1
		lengths.append(state.ply)
	var total: int = 0
	for length in lengths:
		total += length
	print("RANDOM 400 games: draw/first/second=", wins,
		" mean moves=", float(total) / lengths.size(), " range=", lengths.min(), "..", lengths.max())
	var bot := Opponent.new(rules)
	var bot_wins := [0, 0, 0]
	for game in 20:
		state = rules.initial()
		var bot_player: int = game % 2 + 1
		while not rules.is_over(state):
			if state.player == bot_player:
				state = rules.play(state, bot.choose(state, 2))
			else:
				var moves := rules.legal_moves(state)
				state = rules.play(state, moves[rng.randi_range(0, moves.size() - 1)])
		var winner := rules.winner(state)
		bot_wins[0 if winner == 0 else (1 if winner == bot_player else 2)] += 1
	print("BOT vs random (10 each seat): draw/bot/random=", bot_wins)
	print("PASS ", checks, " checks")
	quit(0)
