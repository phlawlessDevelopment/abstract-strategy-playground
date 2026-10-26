extends RefCounted
## Pure rules for Sever. No scene, rendering, or input dependencies.

const RADIUS := 2
const MOVE := 0
const CUT := 1

var cells: Array[Vector2i] = []
var edges: Array[Vector2i] = []
var intact := PackedByteArray()
var positions := PackedInt32Array()
var turn := 0
var phase := MOVE
var departed := -1
var last_from := -1
var last_to := -1
var last_cut := -1
var winner := -1
var moves_played := 0


func _init() -> void:
	_build_graph()
	reset()


func _build_graph() -> void:
	for r in range(-RADIUS, RADIUS + 1):
		for q in range(-RADIUS, RADIUS + 1):
			if abs(q + r) <= RADIUS:
				cells.append(Vector2i(q, r))
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			var d := cells[j] - cells[i]
			if (d == Vector2i(1, 0) or d == Vector2i(0, 1)
					or d == Vector2i(-1, 1)):
				edges.append(Vector2i(i, j))


func reset() -> void:
	intact.resize(edges.size())
	intact.fill(1)
	positions = PackedInt32Array([cells.find(Vector2i(-2, 0)), cells.find(Vector2i(2, 0))])
	turn = 0
	phase = MOVE
	departed = -1
	last_from = -1
	last_to = -1
	last_cut = -1
	winner = -1
	moves_played = 0


func copy() -> RefCounted:
	var result = get_script().new()
	result.intact = intact.duplicate()
	result.positions = positions.duplicate()
	result.turn = turn
	result.phase = phase
	result.departed = departed
	result.last_from = last_from
	result.last_to = last_to
	result.last_cut = last_cut
	result.winner = winner
	result.moves_played = moves_played
	return result


func legal_destinations() -> PackedInt32Array:
	var result := PackedInt32Array()
	if winner != -1 or phase != MOVE:
		return result
	var source := positions[turn]
	for e in edges.size():
		if intact[e] == 0:
			continue
		var edge := edges[e]
		var target := -1
		if edge.x == source:
			target = edge.y
		elif edge.y == source:
			target = edge.x
		if target >= 0 and target != positions[1 - turn]:
			result.append(target)
	return result


func legal_cuts() -> PackedInt32Array:
	var result := PackedInt32Array()
	if winner != -1 or phase != CUT:
		return result
	for e in edges.size():
		if intact[e] == 1 and (edges[e].x == departed or edges[e].y == departed):
			result.append(e)
	return result


func step_to(destination: int) -> bool:
	if not legal_destinations().has(destination):
		return false
	departed = positions[turn]
	positions[turn] = destination
	last_from = departed
	last_to = destination
	phase = CUT
	return true


func cut(edge_index: int) -> bool:
	if not legal_cuts().has(edge_index):
		return false
	intact[edge_index] = 0
	last_cut = edge_index
	moves_played += 1
	phase = MOVE
	departed = -1
	turn = 1 - turn
	if legal_destinations().is_empty():
		winner = 1 - turn
	return true


func threads_left() -> int:
	var count := 0
	for value in intact:
		count += value
	return count


func degree(cell: int) -> int:
	var count := 0
	for e in edges.size():
		if intact[e] == 1 and (edges[e].x == cell or edges[e].y == cell):
			count += 1
	return count


func reachable_count(start: int, blocked: int) -> int:
	var seen := PackedByteArray()
	seen.resize(cells.size())
	seen[start] = 1
	var queue := [start]
	var head := 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for e in edges.size():
			if intact[e] == 0:
				continue
			var next := -1
			if edges[e].x == current:
				next = edges[e].y
			elif edges[e].y == current:
				next = edges[e].x
			if next >= 0 and next != blocked and seen[next] == 0:
				seen[next] = 1
				queue.append(next)
	return queue.size()
