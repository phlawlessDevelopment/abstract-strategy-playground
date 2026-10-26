extends SceneTree

const Rules = preload("res://Rules.gd")


func _initialize() -> void:
	var board: Array[Vector2i] = Rules.cells()
	assert(board.size() == 19)
	var wins := [0, 0]
	var moves_total := 0
	var shortest := 99
	var longest := 0
	for game in 1000:
		var path: Array[int] = [board.find(Vector2i.ZERO)]
		var vaults: Array[bool] = [false, false]
		var player := 0
		while true:
			var moves := Rules.legal_moves(path, vaults, player, board)
			if moves.is_empty():
				wins[1 - player] += 1
				break
			var move: Dictionary = moves[randi_range(0, moves.size() - 1)]
			assert(not path.has(move.to))
			if move.vault:
				assert(not vaults[player])
				assert(path.has(move.over))
			Rules.apply_move(path, vaults, player, move)
			assert(path.size() <= board.size())
			player = 1 - player
		var turns := path.size() - 1
		moves_total += turns
		shortest = min(shortest, turns)
		longest = max(longest, turns)
	print("1000 complete games; wins ", wins, "; moves min/avg/max ", shortest, "/", float(moves_total) / 1000.0, "/", longest)
	quit()
