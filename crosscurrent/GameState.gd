extends RefCounted

const SIZE := 5
const TURN_LIMIT := 20

var board: Array[int] = []
var player := 1
var moves := 0
var finished := false
var winner := 0


func _init() -> void:
	board.resize(SIZE * SIZE)
	board.fill(0)


func can_place(cell: int) -> bool:
	return not finished and cell >= 0 and cell < board.size() and board[cell] == 0


func preview_move(cell: int, direction: int) -> Array[int]:
	var placed: Array[int] = board.duplicate()
	placed[cell] = player
	var shifted: Array[int] = placed.duplicate()
	var row := cell / SIZE
	var column := cell % SIZE
	if direction == 0 or direction == 1:
		var step := -1 if direction == 0 else 1
		for x in range(SIZE):
			shifted[row * SIZE + (x + step + SIZE) % SIZE] = placed[row * SIZE + x]
	else:
		var step := -1 if direction == 2 else 1
		for y in range(SIZE):
			shifted[((y + step + SIZE) % SIZE) * SIZE + column] = placed[y * SIZE + column]
	return shifted


func play(cell: int, direction: int) -> bool:
	if not can_place(cell) or direction < 0 or direction > 3:
		return false
	board = preview_move(cell, direction)
	moves += 1
	if moves >= TURN_LIMIT:
		finished = true
		var points := scores(board)
		if points[0] > points[1]:
			winner = 1
		elif points[1] > points[0]:
			winner = 2
	else:
		player = 3 - player
	return true


func scores(cells: Array[int]) -> Array[int]:
	var result: Array[int] = [0, 0]
	var seen: Array[bool] = []
	seen.resize(SIZE * SIZE)
	seen.fill(false)
	for start in range(cells.size()):
		if cells[start] == 0 or seen[start]:
			continue
		var owner := cells[start]
		var queue: Array[int] = [start]
		seen[start] = true
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			var x := cell % SIZE
			var y := cell / SIZE
			for neighbor in [cell - 1 if x > 0 else -1, cell + 1 if x < SIZE - 1 else -1, cell - SIZE if y > 0 else -1, cell + SIZE if y < SIZE - 1 else -1]:
				if neighbor >= 0 and not seen[neighbor] and cells[neighbor] == owner:
					seen[neighbor] = true
					queue.append(neighbor)
		result[owner - 1] += queue.size() * queue.size()
	return result
