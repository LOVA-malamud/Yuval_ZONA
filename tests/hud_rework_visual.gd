extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var dimensions = (args[0] if args.size() > 0 else "960x540").split("x")
	var locale: String = args[1] if args.size() > 1 else "en"
	root.get_node("Localization").set_language(locale, false)
	root.get_node("GameSettings").set_onboarding_enabled(false, false)
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.force_touch_controls = true
	game.safe_area_override = Rect2(24, 10, root.size.x - 48, root.size.y - 20)
	viewport.add_child(game)
	current_scene = viewport
	await process_frame
	if args.size() > 2 and args[2] == "drawer":
		game.hud.shop_dock.show()
	if args.size() > 2 and args[2] == "tower":
		game.player.position = game.pads[0].position
		game.hud._refresh()
	if args.size() > 2 and args[2] == "healing":
		game.player.position = game.player.team.base_position
		game.player.health = 30.0
		game.player.interact()
	if args.size() > 2 and args[2] == "combat":
		game.player.position = Vector2(2250, 1410)
		game.commanders[2].position = Vector2(2315, 1410)
		game.player.activate_ability(&"heavy", Vector2.RIGHT)
	game.player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var destination: String = "/private/tmp/hud-" + str(root.size.x) + "-" + locale + ("-" + args[2] if args.size() > 2 else "") + ".png"
	viewport.get_texture().get_image().save_png(destination)
	print("CAPTURE: ", destination)
	quit()
