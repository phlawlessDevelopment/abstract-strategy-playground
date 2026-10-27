extends SceneTree
## Dev aid: renders the real scene in a window and saves PNGs. Run (needs a display):
##   godot --path careen -s tools/screenshot.gd -- out=/some/dir
var out := "/tmp"

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func play_turn(main: Control, ai: CarAI, depth: int) -> void:
	var pick := ai.choose(main.rules, depth)
	if main.rules.phase == CarRules.Phase.TILT:
		await main._do_tilt(pick["tilt"])
	if not main.rules.is_over():
		await main._do_drop(pick["cell"])


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.mode = main.Mode.TWO_PLAYERS
	main.new_game()
	await create_timer(0.3).timeout
	await snap("1_start")

	var ai := CarAI.new(7)
	for k in 14:
		await play_turn(main, ai, 1)
	await create_timer(0.3).timeout
	await snap("2_midgame_tilt_phase")

	# Hover each arrow in turn is a lot; show one with a ghost preview.
	var best := 0
	var best_swing := -99
	for d in 4:
		var sw: int = main.rules.tilt_swing(d, main.rules.turn)
		if sw > best_swing:
			best_swing = sw
			best = d
	main.view.hover_arrow = best
	main._refresh_preview()
	await snap("3_arrow_hover")
	main.view.hover_arrow = -1

	# Tilt, then hover a cell in the drop phase.
	await main._do_tilt(best)
	var empties: PackedInt32Array = main.rules.empty_cells()
	var pick_cell: int = empties[empties.size() / 2]
	main.view.hover_cell = pick_cell
	main._refresh_preview()
	await snap("4_drop_hover")
	main.view.hover_cell = -1

	# Finish the game.
	await main._do_drop(pick_cell)
	while not main.rules.is_over():
		await play_turn(main, ai, 1)
	main._after_turn()
	await create_timer(0.5).timeout
	await snap("5_end")

	main._set_rules_open(true)
	await snap("6_rules")
	quit()
