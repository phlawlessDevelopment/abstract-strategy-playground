extends RefCounted
## Pure game rules. Geometry is shared; each position owns only its pieces.

const DIRECTIONS = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
const RADIUS = 3

class Position extends RefCounted:
	var stones := PackedByteArray()
	var lanterns := PackedInt32Array()
	var player: int = 1
	var ply: int = 0

	func copy() -> Position:
		var result := Position.new()
		result.stones = stones.duplicate()
		result.lanterns = lanterns.duplicate()
		result.player = player
		result.ply = ply
		return result

var cells: Array[Vector2i] = []
var indices: Dictionary = {}
# rays[cell][direction] lists cells in order, nearest first.
var rays: Array = []

func _init() -> void:
	for r in range(-RADIUS, RADIUS + 1):
		for q in range(-RADIUS, RADIUS + 1):
			if absi(q + r) <= RADIUS:
				indices[Vector2i(q, r)] = cells.size()
				cells.append(Vector2i(q, r))
	for cell in cells:
		var cell_rays: Array = []
		for direction in DIRECTIONS:
			var ray := PackedInt32Array()
			var next: Vector2i = cell + direction
			while indices.has(next):
				ray.append(indices[next])
				next += direction
			cell_rays.append(ray)
		rays.append(cell_rays)

func initial() -> Position:
	var state := Position.new()
	state.stones.resize(cells.size())
	state.stones.fill(0)
	for cell in [Vector2i(-2, 0), Vector2i(2, -2), Vector2i(0, 2)]:
		state.lanterns.append(indices[cell])
	return state

func occupied(state: Position) -> PackedByteArray:
	var result: PackedByteArray = state.stones.duplicate()
	for cell in state.lanterns:
		result[cell] = 3
	return result

func destinations(state: Position, lantern: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if lantern < 0 or lantern >= state.lanterns.size():
		return result
	var pieces := occupied(state)
	for ray in rays[state.lanterns[lantern]]:
		for cell in ray:
			if pieces[cell] != 0:
				break
			result.append(cell)
	return result

# A move is (lantern index, destination cell index).
func legal_moves(state: Position) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for lantern in state.lanterns.size():
		for cell in destinations(state, lantern):
			result.append(Vector2i(lantern, cell))
	return result

func play(state: Position, move: Vector2i) -> Position:
	assert(move.y in destinations(state, move.x), "Illegal lantern slide")
	return apply_legal(state, move)

func apply_legal(state: Position, move: Vector2i) -> Position:
	# Callers with a generated legal move can skip checking geometry again.
	var result := state.copy()
	result.stones[result.lanterns[move.x]] = result.player
	result.lanterns[move.x] = move.y
	result.player = 3 - result.player
	result.ply += 1
	return result

func illuminated(state: Position) -> PackedByteArray:
	var lit := PackedByteArray()
	lit.resize(cells.size())
	lit.fill(0)
	var pieces := occupied(state)
	for lantern in state.lanterns:
		for ray in rays[lantern]:
			for cell in ray:
				if pieces[cell] == 0:
					continue
				if pieces[cell] < 3:
					lit[cell] = pieces[cell]
				break
	return lit

func scores(state: Position) -> Vector2i:
	var result := Vector2i.ZERO
	for owner in illuminated(state):
		if owner == 1:
			result.x += 1
		elif owner == 2:
			result.y += 1
	return result

func is_over(state: Position) -> bool:
	return legal_moves(state).is_empty()

func winner(state: Position) -> int:
	var score := scores(state)
	if score.x == score.y:
		return 0
	return 1 if score.x > score.y else 2

func cell_name(cell: int) -> String:
	var axial := cells[cell]
	return "%s%d" % [String.chr(68 + axial.x), axial.y + 4]
