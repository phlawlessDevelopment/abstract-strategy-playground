extends RefCounted
## Deterministic, bounded minimax. No threads, network, or hidden information.

const Rules = preload("res://scripts/rules.gd")
var rules: RefCounted
var nodes: int = 0
var budget: int = 9000

func _init(game_rules: RefCounted) -> void:
	rules = game_rules

func choose(state: Rules.Position, depth_override: int = 0) -> Vector2i:
	nodes = 0
	var moves: Array[Vector2i] = rules.legal_moves(state)
	if moves.is_empty():
		return Vector2i(-1, -1)
	var depth: int = depth_override
	if depth == 0:
		depth = 2 if state.ply < 16 else 4
		if moves.size() <= 8:
			depth = 7
	var ordered := _ordered(state, moves)
	var best: Vector2i = ordered[0]
	var best_value: float = -INF
	var alpha: float = -INF
	for move in ordered:
		var child: Rules.Position = rules.apply_legal(state, move)
		var value := -_search(child, depth - 1, -INF, -alpha)
		if value > best_value:
			best_value = value
			best = move
		alpha = maxf(alpha, value)
	return best

func _search(state: Rules.Position, depth: int, alpha_in: float, beta: float) -> float:
	nodes += 1
	var moves: Array[Vector2i] = rules.legal_moves(state)
	if moves.is_empty():
		var score: Vector2i = rules.scores(state)
		var diff: int = (score.x - score.y) * (1 if state.player == 1 else -1)
		if diff == 0:
			return 0.0
		return signf(diff) * 10000.0 + diff * 100.0
	if depth <= 0 or nodes >= budget:
		return _evaluate(state)
	var alpha := alpha_in
	var best: float = -INF
	for move in _ordered(state, moves):
		var value := -_search(rules.apply_legal(state, move), depth - 1, -beta, -alpha)
		best = maxf(best, value)
		alpha = maxf(alpha, value)
		if alpha >= beta:
			break
	return best

func _evaluate(state: Rules.Position) -> float:
	var score: Vector2i = rules.scores(state)
	var sign_player: int = 1 if state.player == 1 else -1
	# Currently lit stones matter most. Dark stones have a small option value:
	# a later lantern can expose them, but they never score merely for existing.
	var reserves: int = 0
	for stone in state.stones:
		if stone == 1:
			reserves += 1
		elif stone == 2:
			reserves -= 1
	return float((score.x - score.y) * 100 + reserves * 3) * sign_player

func _ordered(state: Rules.Position, moves: Array[Vector2i]) -> Array[Vector2i]:
	var ranked: Array = []
	for move in moves:
		var child: Rules.Position = rules.apply_legal(state, move)
		ranked.append({"move": move, "value": -_evaluate(child)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value > b.value)
	var result: Array[Vector2i] = []
	for entry in ranked:
		result.append(entry.move)
	return result
