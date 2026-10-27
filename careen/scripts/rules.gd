class_name CarRules
extends RefCounted
## Careen: pure game logic. No nodes, no drawing, no input.
##
## A square tray holds stones. Every turn is two actions: first you TILT the whole
## tray (all stones slide until something stops them), then you DROP one stone from
## your reserve onto any empty cell. Your dropped stone sits still until your
## opponent's tilt, so every drop has to survive four possible futures.
##
## After a tilt settles, any stone with an enemy stone directly on both sides of it
## (left+right, or above+below) is crushed. Crushed stones leave at the same moment,
## everything slides again, and the check repeats until the tray is quiet.
##
## Cell values: 0 empty, 1 Amber stone, 2 Teal stone, 3 post (never moves, never an enemy).

const AMBER := 0   # player index; moves first
const TEAL := 1

const EMPTY := 0
const POST := 3

enum Dir { N, E, S, W }
const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]
const DIR_NAMES: Array[String] = ["north", "east", "south", "west"]

enum Phase { TILT, DROP, OVER }

const DEFAULT_SIZE := 6
const DEFAULT_STONES := 11
const DEFAULT_FINAL_TILTS := 1   # after the last drop: 0 = game ends, 1 = next player tilts once, 2 = both tilt

var w: int = DEFAULT_SIZE
var h: int = DEFAULT_SIZE
var cells: PackedByteArray = PackedByteArray()
var reserve: Array[int] = [DEFAULT_STONES, DEFAULT_STONES]   # stones still to drop
var lost: Array[int] = [0, 0]                                # stones crushed so far, per owner
var turn: int = AMBER
var phase: int = Phase.DROP
var finale_left: int = 0          # tilts still to be made once both reserves are empty
var final_tilts: int = DEFAULT_FINAL_TILTS
var no_repeat: bool = false       # if true, a tilt may not repeat the direction of the one before it
var last_dir: int = -1            # direction of the most recent tilt, -1 before the first
var stones_each: int = DEFAULT_STONES
var history: Array = []           # snapshots, for undo
var events: Array = []            # one Dictionary per action, for the "what just happened" line
var _posts: PackedInt32Array = PackedInt32Array()


func _init(p_w: int = DEFAULT_SIZE, p_stones: int = DEFAULT_STONES, posts: PackedInt32Array = PackedInt32Array(), p_final_tilts: int = DEFAULT_FINAL_TILTS, p_no_repeat: bool = false) -> void:
	w = p_w
	h = p_w
	stones_each = p_stones
	final_tilts = p_final_tilts
	no_repeat = p_no_repeat
	reset(posts)


func reset(posts: PackedInt32Array = PackedInt32Array()) -> void:
	if posts.is_empty() and not _posts.is_empty():
		posts = _posts
	_posts = posts
	cells = PackedByteArray()
	cells.resize(w * h)
	for p in posts:
		cells[p] = POST
	reserve = [stones_each, stones_each]
	lost = [0, 0]
	turn = AMBER
	phase = Phase.DROP       # the tray is empty, so Amber's first action is a drop
	finale_left = 0
	last_dir = -1
	history.clear()
	events.clear()



# --- the physics (static, so the computer can use it on bare boards) ----------------

## Slide every stone as far as it goes in direction d. Posts and the walls stop stones;
## stones never pass each other. Returns how many stones moved. If `moves` is an Array,
## appends [from, to] pairs.
static func slide(b: PackedByteArray, bw: int, bh: int, d: int, moves = null) -> int:
	var moved := 0
	if d == Dir.E or d == Dir.W:
		var west := d == Dir.W
		for y in bh:
			var dest := 0                          # slot index counted from the leading wall
			for k in bw:
				var i := y * bw + (k if west else bw - 1 - k)
				var v := b[i]
				if v == EMPTY:
					continue
				if v == POST:
					dest = k + 1
					continue
				if dest != k:
					var j := y * bw + (dest if west else bw - 1 - dest)
					b[j] = v
					b[i] = EMPTY
					moved += 1
					if moves != null:
						moves.append([i, j])
				dest += 1
	else:
		var north := d == Dir.N
		for x in bw:
			var dest := 0
			for k in bh:
				var i := (k if north else bh - 1 - k) * bw + x
				var v := b[i]
				if v == EMPTY:
					continue
				if v == POST:
					dest = k + 1
					continue
				if dest != k:
					var j := (dest if north else bh - 1 - dest) * bw + x
					b[j] = v
					b[i] = EMPTY
					moved += 1
					if moves != null:
						moves.append([i, j])
				dest += 1
	return moved


## Cells holding a stone that has an enemy stone straight across it on both sides.
static func find_crushed(b: PackedByteArray, bw: int, bh: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in bw * bh:
		var v := b[i]
		if v != 1 and v != 2:
			continue
		var e := 3 - v
		var x := i % bw
		var y := i / bw
		if (x > 0 and x < bw - 1 and b[i - 1] == e and b[i + 1] == e) \
				or (y > 0 and y < bh - 1 and b[i - bw] == e and b[i + bw] == e):
			out.append(i)
	return out


## Tilt: slide, then repeat {crush, slide} until nothing is crushed. Adds to `lost`
## (indexed by owner). If `steps` is an Array, appends the animation script:
##   {"kind": "slide", "moves": [[from, to], ...]}
##   {"kind": "crush", "cells": [i, ...], "owners": [o, ...]}
## Returns the total number of stones crushed.
static func settle(b: PackedByteArray, bw: int, bh: int, d: int, lost_out: Array, steps = null) -> int:
	var total := 0
	var mv = [] if steps != null else null
	slide(b, bw, bh, d, mv)
	if steps != null and not mv.is_empty():
		steps.append({"kind": "slide", "moves": mv})
	while true:
		var dead := find_crushed(b, bw, bh)
		if dead.is_empty():
			break
		var owners := []
		for i in dead:
			owners.append(b[i] - 1)
			lost_out[b[i] - 1] += 1
			b[i] = EMPTY
		total += dead.size()
		if steps != null:
			steps.append({"kind": "crush", "cells": dead, "owners": owners})
		mv = [] if steps != null else null
		slide(b, bw, bh, d, mv)
		if steps != null and not mv.is_empty():
			steps.append({"kind": "slide", "moves": mv})
	return total


# --- queries ------------------------------------------------------------------------

func is_over() -> bool:
	return phase == Phase.OVER


func stones_on_board(who: int) -> int:
	var n := 0
	for v in cells:
		if v == who + 1:
			n += 1
	return n


func empty_cells() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w * h:
		if cells[i] == EMPTY:
			out.append(i)
	return out


## Result of tilting right now, without changing anything: {board, lost (gained crushes per owner), steps}.
func preview_tilt(d: int) -> Dictionary:
	var b := cells.duplicate()
	var l: Array[int] = [0, 0]
	var steps := []
	settle(b, w, h, d, l, steps)
	return {"board": b, "lost": l, "steps": steps}


## Net swing of a tilt for `who`: stones the opponent loses minus stones `who` loses.
func tilt_swing(d: int, who: int) -> int:
	var p := preview_tilt(d)
	return p["lost"][1 - who] - p["lost"][who]


## May the player about to tilt choose direction d?
func dir_ok(d: int) -> bool:
	return not (no_repeat and d == last_dir)


func winner() -> int:
	## AMBER, TEAL, or 2 for a draw. Only meaningful once the game is over.
	if lost[AMBER] < lost[TEAL]:
		return AMBER
	if lost[TEAL] < lost[AMBER]:
		return TEAL
	return 2


# --- actions ------------------------------------------------------------------------

func _snapshot() -> void:
	history.append({
		"cells": cells.duplicate(), "reserve": reserve.duplicate(), "lost": lost.duplicate(),
		"turn": turn, "phase": phase, "finale_left": finale_left, "last_dir": last_dir, "events_size": events.size(),
	})


func undo() -> bool:
	if history.is_empty():
		return false
	var s: Dictionary = history.pop_back()
	cells = s["cells"]
	reserve = s["reserve"]
	lost = s["lost"]
	turn = s["turn"]
	phase = s["phase"]
	finale_left = s["finale_left"]
	last_dir = s["last_dir"]
	events.resize(s["events_size"])
	return true


## Tilt the tray. Returns the animation steps. Only legal in the TILT phase.
func tilt(d: int) -> Array:
	assert(phase == Phase.TILT and dir_ok(d))
	_snapshot()
	last_dir = d
	var steps := []
	var before: Array[int] = lost.duplicate()
	settle(cells, w, h, d, lost, steps)
	events.append({"kind": "tilt", "who": turn, "dir": d, "crushed": [lost[0] - before[0], lost[1] - before[1]]})
	if finale_left > 0:
		finale_left -= 1
		if finale_left == 0:
			phase = Phase.OVER
		else:
			turn = 1 - turn          # both players tilt once at the end
	else:
		phase = Phase.DROP
	return steps


func drop(cell: int) -> void:
	assert(phase == Phase.DROP and cells[cell] == EMPTY and reserve[turn] > 0)
	_snapshot()
	cells[cell] = turn + 1
	reserve[turn] -= 1
	events.append({"kind": "drop", "who": turn, "cell": cell})
	turn = 1 - turn
	phase = Phase.TILT
	if reserve[AMBER] == 0 and reserve[TEAL] == 0:
		finale_left = final_tilts
		if final_tilts == 0:
			phase = Phase.OVER


## Fingerprint for repetition-free searching and tests.
func key() -> String:
	return "%s|%d%d|%d|%d" % [cells.hex_encode(), reserve[0], reserve[1], turn, phase]
