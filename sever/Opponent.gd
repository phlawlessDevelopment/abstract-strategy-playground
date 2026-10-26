extends RefCounted
## A small two-ply opponent: it considers each step/cut pair and the best reply.

const State = preload("res://GameState.gd")


static func choose_turn(state) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -1000000.0
	var player: int = state.turn
	for destination in state.legal_destinations():
		var after_step = state.copy()
		after_step.step_to(destination)
		for edge in after_step.legal_cuts():
			var after_cut = after_step.copy()
			after_cut.cut(edge)
			var score := _worst_reply_score(after_cut, player)
			# A tiny central preference breaks otherwise exact ties predictably.
			var axial: Vector2i = state.cells[destination]
			score -= 0.01 * float(abs(axial.x) + abs(axial.y) + abs(axial.x + axial.y))
			if score > best_score:
				best_score = score
				best = Vector2i(destination, edge)
	return best


static func _worst_reply_score(state, player: int) -> float:
	if state.winner != -1:
		return 10000.0 if state.winner == player else -10000.0
	var worst := 1000000.0
	for destination in state.legal_destinations():
		var after_step = state.copy()
		after_step.step_to(destination)
		for edge in after_step.legal_cuts():
			var reply = after_step.copy()
			reply.cut(edge)
			worst = minf(worst, _evaluate(reply, player))
	return worst


static func _evaluate(state, player: int) -> float:
	if state.winner != -1:
		return 10000.0 if state.winner == player else -10000.0
	var enemy := 1 - player
	var my_moves := _mobility(state, player)
	var enemy_moves := _mobility(state, enemy)
	var my_space: int = state.reachable_count(state.positions[player], state.positions[enemy])
	var enemy_space: int = state.reachable_count(state.positions[enemy], state.positions[player])
	return 14.0 * float(my_moves - enemy_moves) + 3.0 * float(my_space - enemy_space)


static func _mobility(state, player: int) -> int:
	var source: int = state.positions[player]
	var blocked: int = state.positions[1 - player]
	var count := 0
	for e in state.edges.size():
		if state.intact[e] == 0:
			continue
		var edge: Vector2i = state.edges[e]
		if edge.x == source and edge.y != blocked:
			count += 1
		elif edge.y == source and edge.x != blocked:
			count += 1
	return count
