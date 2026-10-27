extends SceneTree
## Rules checks with hand-worked positions. Run:
##   godot --headless --path careen -s tools/test_rules.gd
var fails := 0

func check(name: String, got, want) -> void:
	if str(got) != str(want):
		fails += 1
		print("FAIL ", name, ": got ", got, " want ", want)
	else:
		print("ok   ", name)


## Build a board from rows of text: . empty, A amber, T teal, # post.
func board(rows: Array) -> PackedByteArray:
	var b := PackedByteArray()
	for r in rows:
		for ch in r:
			b.append({".": 0, "A": 1, "T": 2, "#": 3}[ch])
	return b


func text(b: PackedByteArray, w: int) -> String:
	var out := []
	for y in b.size() / w:
		var s := ""
		for x in w:
			s += [".", "A", "T", "#"][b[y * w + x]]
		out.append(s)
	return "/".join(out)


func tilt_text(rows: Array, d: int) -> String:
	var w: int = rows[0].length()
	var b := board(rows)
	var l := [0, 0]
	CarRules.settle(b, w, rows.size(), d, l)
	return text(b, w) + " lost=" + str(l)


## Play a 1-stone-each game to the end and report whether the closing tilts behaved.
func _quick_end(final_tilts: int) -> bool:
	var r := CarRules.new(6, 1, PackedInt32Array(), final_tilts)
	r.drop(0)                       # Amber's only stone
	r.tilt(CarRules.Dir.E)
	r.drop(1)                       # Teal's only stone
	if final_tilts == 0:
		return r.is_over()
	var tilts := 0
	while not r.is_over() and tilts < 5:
		r.tilt(CarRules.Dir.W)
		tilts += 1
	return tilts == final_tilts


func _init() -> void:
	var W := CarRules.Dir.W
	var E := CarRules.Dir.E
	var N := CarRules.Dir.N
	var S := CarRules.Dir.S

	# Plain sliding, one stone per row, no crushes possible.
	check("slide west", tilt_text(["..A.", ".T.."], W), "A.../T... lost=[0, 0]")
	check("slide east", tilt_text(["A...", "..T."], E), "...A/...T lost=[0, 0]")
	check("slide north", tilt_text(["....", "A...", "...T"], N), "A..T/..../.... lost=[0, 0]")
	check("slide south", tilt_text(["A...", "....", "...T"], S), "..../..../A..T lost=[0, 0]")

	# Stones stop against each other and keep their order.
	check("order kept, ATAT crushes the inner pair", tilt_text(["A.T.AT"], W), "AT.... lost=[1, 1]")
	check("order kept, no crush", tilt_text(["A.TTA."], W), "ATTA.. lost=[0, 0]")
	# Posts stop stones; the segments pack independently.
	check("post west", tilt_text(["..#.A."], W), "..#A.. lost=[0, 0]")
	check("post east", tilt_text([".A#.A."], E), ".A#..A lost=[0, 0]")
	check("stone against post", tilt_text(["A#.A."], W), "A#A.. lost=[0, 0]")

	# A lone stone between two enemies, in its row, is crushed once packed. A T A -> T dies? No: T between two A.
	check("crush row", tilt_text(["A.T.A."], W), "AA.... lost=[0, 1]")
	# Amber crushed by two teal.
	check("crush row 2", tilt_text([".T.A.T"], E), "....TT lost=[1, 0]")
	# Column crush.
	check("crush column", tilt_text(["A", ".", "T", ".", "A"], N), "A/A/././. lost=[0, 1]")
	# Walls are not enemies: a stone at the wall is safe on that axis.
	check("wall safe", tilt_text(["TA.."], W), "TA.. lost=[0, 0]")
	# A pair is safe: A TT A does nothing.
	check("pair safe", tilt_text(["A.TT.A"], W), "ATTA.. lost=[0, 0]")
	# Posts are not enemies and break adjacency.
	check("post not enemy", tilt_text(["A.T#A"], W), "AT.#A lost=[0, 0]")
	# Chain: A T A T A, both T and middle A are 'between enemies' at once -> T, A, T all crushed at once (3 stones),
	# the two end A survive and then slide together.
	check("chain simultaneous", tilt_text(["ATATA."], W), "AA.... lost=[1, 2]")
	# A crush opens a gap, stones slide, new crush follows.
	check("chain follow-on", tilt_text(["TATAT."], W), "TT.... lost=[2, 1]")
	# Vertical crush that only appears after a horizontal tilt (both axes count).
	check("cross-axis", tilt_text(["A...", "..T.", "...A"], W), "A.../..../A... lost=[0, 1]")

	# Game flow.
	var r := CarRules.new(6, 2)
	check("starts with drop", r.phase, CarRules.Phase.DROP)
	r.drop(0)
	check("then tilt", [r.turn, r.phase], [CarRules.TEAL, CarRules.Phase.TILT])
	r.tilt(E)
	r.drop(1)
	r.tilt(S)
	r.drop(2)
	r.tilt(W)
	check("last drop pending", [r.turn, r.reserve], [CarRules.TEAL, [0, 1]])
	r.drop(3)
	check("finale", [r.finale_left, r.phase, r.turn], [1, CarRules.Phase.TILT, CarRules.AMBER])
	r.tilt(N)
	check("over", r.is_over(), true)
	# Undo all the way back.
	var n := 0
	while r.undo():
		n += 1
	check("undo count", n, 8)
	check("undo restores", [r.reserve, r.phase, r.turn, r.stones_on_board(0)], [[2, 2], CarRules.Phase.DROP, CarRules.AMBER, 0])

	# Options that were tried but are not in the shipped game still have to behave.
	var nr := CarRules.new(6, 2, PackedInt32Array(), 1, true)
	nr.drop(0)
	check("no-repeat: first tilt unrestricted", [nr.dir_ok(0), nr.dir_ok(1), nr.dir_ok(2), nr.dir_ok(3)], [true, true, true, true])
	nr.tilt(E)
	check("no-repeat: same direction banned next", [nr.dir_ok(E), nr.dir_ok(W)], [false, true])
	nr.drop(0)
	nr.undo()
	nr.undo()
	check("no-repeat: undo restores the ban state", nr.last_dir, -1)
	var pr := CarRules.new(6, 2, PackedInt32Array([14]), 0)
	check("post cell is a post", pr.cells[14], CarRules.POST)
	check("final_tilts=0 ends right after the last drop", _quick_end(0), true)
	check("final_tilts=2 needs two closing tilts", _quick_end(2), true)

	print("FAILED: %d" % fails if fails > 0 else "ALL PASSED")
	quit(1 if fails > 0 else 0)
