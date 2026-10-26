extends RefCounted
class_name LongwayRules

const RADIUS := 2
const DIRECTIONS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

static func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r in range(-RADIUS, RADIUS + 1):
		for q in range(-RADIUS, RADIUS + 1):
			if abs(q + r) <= RADIUS:
				result.append(Vector2i(q, r))
	return result


static func legal_moves(path: Array[int], used_vault: Array[bool], player: int, board: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var head := board[path.back()]
	for direction in DIRECTIONS:
		var neighbor := board.find(head + direction)
		if neighbor < 0:
			continue
		if not path.has(neighbor):
			result.append({"to": neighbor, "vault": false, "over": -1})
		elif not used_vault[player]:
			var landing := board.find(head + direction * 2)
			if landing >= 0 and not path.has(landing):
				result.append({"to": landing, "vault": true, "over": neighbor})
	return result


static func apply_move(path: Array[int], used_vault: Array[bool], player: int, move: Dictionary) -> void:
	path.append(move.to)
	if move.vault:
		used_vault[player] = true


static func search(path: Array[int], used_vault: Array[bool], player: int, board: Array[Vector2i], depth: int) -> int:
	var moves := legal_moves(path, used_vault, player, board)
	if moves.is_empty():
		return -1000 - depth
	if depth == 0:
		# A central head leaves more routes; a live vault preserves an escape.
		return moves.size() * 4 + (2 if not used_vault[player] else 0)
	var best := -2000
	for move in moves:
		var next_path := path.duplicate()
		var next_vault := used_vault.duplicate()
		apply_move(next_path, next_vault, player, move)
		var score := -search(next_path, next_vault, 1 - player, board, depth - 1)
		if score > best:
			best = score
	return best


static func choose_move(path: Array[int], used_vault: Array[bool], player: int, board: Array[Vector2i]) -> Dictionary:
	var moves := legal_moves(path, used_vault, player, board)
	var best_move: Dictionary = moves.front()
	var best_score := -2000
	for move in moves:
		var next_path := path.duplicate()
		var next_vault := used_vault.duplicate()
		apply_move(next_path, next_vault, player, move)
		var score := -search(next_path, next_vault, 1 - player, board, 4)
		# A small preference for keeping the vault when plans tie.
		if not move.vault:
			score += 1
		if score > best_score:
			best_score = score
			best_move = move
	return best_move
