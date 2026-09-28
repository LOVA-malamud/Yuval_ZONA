extends SceneTree
## Render the actual viewport for repeatable screenshots (no editor-window capture).
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scenario: String = args[0] if args.size() > 0 else "base"
	var dimensions: PackedStringArray = (args[1] if args.size() > 1 else "1280x720").split("x")
	var locale: String = args[2] if args.size() > 2 else "en"
	root.get_node("Localization").set_language(locale, false)
	root.get_node("GameSettings").set_onboarding_enabled(scenario == "guidance", false)
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	if scenario in ["battle","king","economy"]:
		game.teams[0].money = 700
		game.teams[0].wood = 280
		game.player.position = game.pads[7].position + Vector2(-70,-25)
		game.build_tower(game.player, game.pads[7])
		game.player.get_node("Camera2D").reset_smoothing()
		for team in game.teams:
			for i in range(12):
				game.purchase(team.team_id, [&"melee", &"ranged", &"tank"][i%3], false, i%3)
				team.money += 150
		var count: int = 0
		for entity in get_nodes_in_group("combatants"):
			if entity.kind in [&"melee",&"ranged",&"tank"]:
				entity.position = Vector2(2180 if entity.team.team_id == 1 else 2430, 1350) + Vector2(count%4 * 24,count%5*35)
				count += 1
		game.commanders[1].position = Vector2(2120,1440)
		game.commanders[2].position = Vector2(2450,1400)
		game.commanders[3].position = Vector2(2480,1510)
	if scenario == "king":
		game.hud.tabs.current_tab = 1
	if scenario == "economy":
		game.hud.tabs.current_tab = 2
	if scenario == "pad_states":
		game.teams[0].money = 10000
		game.teams[0].wood = 10000
		game.teams[1].money = 10000
		game.teams[1].wood = 10000
		for i in range(4):
			game.pads[i].position = Vector2(1900+i*250,1410)
			game.pads[i].home_team_id = 0
		for i in [1,3]:
			game.player.position = game.pads[i].position
			game.build_tower(game.player,game.pads[i])
		game.commanders[2].position = game.pads[2].position
		game.build_tower(game.commanders[2],game.pads[2])
		game.pads[3].tower.take_damage(99999,2)
		game.player.position = Vector2(2230,1540)
	if scenario == "pads":
		game.player.position = game.pads[0].position + Vector2(-60,60)
	if scenario == "danger":
		game.player.position = game.teams[0].base_position + Vector2(100,90)
		game.teams[0].king.take_damage(500,2)
		game.teams[0].king.take_damage(150,2)
	if scenario == "base":
		game.match_seconds = 25.0
	game.player.get_node("Camera2D").reset_smoothing()
	await create_timer(2.5).timeout
	if scenario in ["victory", "defeat"]:
		game.player.position = game.teams[1].base_position + Vector2(-100,80)
		game.player.get_node("Camera2D").reset_smoothing()
		await create_timer(0.1).timeout
		game.teams[1 if scenario == "victory" else 0].king.take_damage(99999,1 if scenario == "victory" else 2)
		await create_timer(1.1).timeout
	if scenario == "respawn":
		game.player.take_damage(99999, 2)
		# Let the 10 Hz HUD and 5 Hz strategic map observe the death before freezing.
		await create_timer(0.25).timeout
	if scenario in ["pause", "settings", "help"]:
		game.hud._toggle_pause()
	if scenario == "settings":
		game.hud._open_settings()
	if scenario == "help":
		game.hud._open_help()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	RenderingServer.force_draw()
	var file: String = "res:/" + "/tests/artifacts/" + scenario + "_" + locale + "_" + str(root.size.x) + "x" + str(root.size.y) + ".png"
	var captured: Image = root.get_texture().get_image()
	var error: Error = captured.save_png(file)
	if captured.get_size() != root.size:
		push_error("Capture dimensions differ from requested dimensions")
		error = ERR_INVALID_DATA
	print("VERIFIED PIXELS ",captured.get_size())
	print("CAPTURE ", file, " error=", error)
	# Every visible control must fit inside the viewport.
	var problems: int = _check_layout(game.hud.controls, root.get_visible_rect())
	print("LAYOUT problems=", problems)
	root.get_node("AudioFeedback").stop_all()
	await create_timer(0.1, true).timeout
	quit(1 if problems > 0 or error != OK else 0)

func _check_layout(node: Node, bounds: Rect2) -> int:
	var problems: int = 0
	if node is Control and node.is_visible_in_tree() and node.size.x > 0 and node.size.y > 0:
		if not bounds.grow(2).encloses(node.get_global_rect()):
			push_error("Control outside viewport: %s %s" % [node.name,node.get_global_rect()])
			problems += 1
	for child in node.get_children():
		problems += _check_layout(child, bounds)
	return problems
