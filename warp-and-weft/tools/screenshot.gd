extends SceneTree
## Dev aid: renders the real scene in a window and saves PNGs. Run (needs a display):
##   godot --path warp-and-weft -s tools/screenshot.gd -- out=/some/dir
var out := "/tmp"

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.mode = main.Mode.TWO_PLAYERS
	main.board_seed = 424242
	main.new_game(true)
	await create_timer(0.4).timeout
	await snap("1_start")

	# Mid-game: a few sensible moves, then hover a legal cell.
	var ai := WWAI.new(3)
	for k in 9:
		main._play(ai.choose(main.rules, WWAI.Level.MEDIUM))
		await create_timer(0.05).timeout
	await create_timer(0.6).timeout
	var mv: PackedInt32Array = main.rules.moves()
	var pick := mv[mv.size() / 2]
	main.view.hover = pick
	main._on_hover(pick)
	await snap("2_midgame_hover")

	# Finish the game.
	main.view.hover = -1
	main._on_hover(-1)
	while not main.rules.is_over():
		main._play(ai.choose(main.rules, WWAI.Level.MEDIUM))
	await create_timer(0.8).timeout
	await snap("3_end_banner")
	main.view.banner_title = ""
	await snap("4_end_board")

	main._set_rules_open(true)
	await snap("5_rules")
	quit()
