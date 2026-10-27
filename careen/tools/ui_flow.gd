extends SceneTree
## End-to-end UI check: drives the real scene through the same handlers a human's clicks reach.
##   godot --headless --path careen -s tools/ui_flow.gd
var main: Control
var fails := 0
var rng := RandomNumberGenerator.new()


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("ok   ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", detail)


func idle() -> void:
	# Wait until nothing is animating or being thought about.
	var guard := 0
	while (main.animating or main.thinking) and guard < 3000:
		await process_frame
		guard += 1


func view_matches_rules() -> bool:
	var r: CarRules = main.rules
	var n := 0
	for i in r.cells.size():
		var v := r.cells[i]
		if v == 1 or v == 2:
			n += 1
			if not main.view.sprites.has(i) or main.view.sprites[i].get_meta("owner") != v - 1:
				return false
	return main.view.sprites.size() == n


## One human action by whoever is to move: a random allowed tilt or a random empty cell.
func human_action() -> void:
	var r: CarRules = main.rules
	if r.phase == CarRules.Phase.TILT:
		var d := rng.randi_range(0, 3)
		main._on_arrow_clicked(d)
	else:
		var empties := r.empty_cells()
		main._on_cell_clicked(empties[rng.randi_range(0, empties.size() - 1)])
	await idle()


func play_out_two_players() -> void:
	main.mode = main.Mode.TWO_PLAYERS
	main.new_game()
	var guard := 0
	while not main.rules.is_over() and guard < 200:
		await human_action()
		guard += 1


func play_out_vs_computer(seat_mode: int) -> void:
	main.mode = seat_mode
	main.level = main.Level.EASY
	main.new_game()
	var guard := 0
	while not main.rules.is_over() and guard < 4000:
		await idle()
		if main.rules.is_over():
			break
		if main.is_human(main.rules.turn):
			await human_action()
		else:
			await process_frame
		guard += 1


func _init() -> void:
	rng.seed = 12345
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.view.speed = 60.0

	await play_out_two_players()
	check("two-player game finishes", main.rules.is_over())
	check("stones conserved", main.rules.reserve == [0, 0] and main.rules.stones_on_board(0) + main.rules.lost[0] == main.rules.stones_each)
	check("view matches rules after a game", view_matches_rules())
	check("banner shown", main.view.banner_title != "")

	for seat in [main.Mode.YOU_AMBER, main.Mode.YOU_TEAL]:
		await play_out_vs_computer(seat)
		check("vs computer game finishes (mode %d)" % seat, main.rules.is_over())
		check("view matches rules (mode %d)" % seat, view_matches_rules())

	# A whole game against the Hard computer (three-turn search) through the UI.
	main.level = main.Level.HARD
	await play_out_vs_computer(main.Mode.YOU_TEAL)
	check("vs Hard computer finishes", main.rules.is_over())
	check("view matches rules after Hard game", view_matches_rules())
	main.level = main.Level.MEDIUM

	# Undo in the middle of a game: back to the start of the human's turn, view in step.
	main.mode = main.Mode.TWO_PLAYERS
	main.new_game()
	for k in 7:
		await human_action()
	var before: int = main.rules.history.size()
	main._on_undo()
	await idle()
	check("undo removes actions", main.rules.history.size() < before)
	check("undo lands on a tilt/opening", main.rules.phase == CarRules.Phase.TILT or main.rules.history.is_empty())
	check("view matches rules after undo", view_matches_rules())
	for k in 4:
		await human_action()
	check("play continues after undo", view_matches_rules())

	# Undo against the computer returns to the human's turn.
	main.mode = main.Mode.YOU_AMBER
	main.level = main.Level.EASY
	main.new_game()
	for k in 6:
		await idle()
		if main.is_human(main.rules.turn) and not main.rules.is_over():
			await human_action()
		else:
			await process_frame
	await idle()
	main._on_undo()
	await idle()
	check("undo vs computer lands on the human's turn", main.is_human(main.rules.turn) or main.thinking)
	check("view matches rules after undo vs computer", view_matches_rules())

	# Restarting while the computer is thinking forgets its pending move.
	main.mode = main.Mode.YOU_TEAL
	main.new_game()                 # Amber (computer) starts
	await process_frame
	check("computer is thinking at start", main.thinking)
	main.new_game()
	await idle()
	await process_frame
	check("restart mid-thought leaves a sane board", view_matches_rules() and main.rules.history.size() <= 1)

	print("UI FAILED: %d" % fails if fails > 0 else "UI ALL PASSED")
	quit(1 if fails > 0 else 0)
