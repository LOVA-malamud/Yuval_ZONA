extends SceneTree
## A real-time opening using ordinary starting resources and actual input.
## No controller replacement, forced income, teleports or spawned enemies.
var game = null
var failures: int = 0
var checks: int = 0
var started: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("OPENING PASS: ", message)
	else:
		failures += 1
		push_error("OPENING FAIL: " + message)

func _run() -> void:
	var settings = root.get_node("GameSettings")
	var localization = root.get_node("Localization")
	var original_language: String = localization.language
	var original_guidance: bool = settings.onboarding_enabled
	localization.set_language("en", false)
	settings.set_onboarding_enabled(true, false)
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	started = Time.get_ticks_msec()
	await create_timer(0.5).timeout
	check(game.hud.guidance_panel.visible and not paused, "First launch explains the objective inside a live match")
	await _capture("opening_first")
	await _click(game.hud.army_buttons[&"worker"])
	check(game.teams[0].worker_count == 4, "Opening gold recruits a worker through the shop")
	await _click(game.hud.army_buttons[&"melee"])
	check(game.teams[0].combat_count >= 1, "Opening gold recruits a frontline unit")
	var origin: Vector2 = game.player.position
	Input.action_press("move_right")
	await create_timer(1.5).timeout
	Input.action_release("move_right")
	Input.action_press("move_up")
	await create_timer(0.5).timeout
	Input.action_release("move_up")
	check(game.player.position.distance_to(origin) > 300, "WASD reaches the friendly Gate pad without teleporting")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await create_timer(0.3).timeout
	check(game.hud.structure_panel.visible and game.hud.active_pad == game.pads[0], "Approaching a pad exposes its contextual build action")
	var found_carrying: bool = false
	while game.hud.structure_button.disabled and game.match_seconds < 45:
		for entity in get_nodes_in_group("combatants"):
			if entity.kind == &"worker" and entity.team == game.teams[0] and entity.carried > 0:
				found_carrying = true
		await create_timer(0.25).timeout
	check(game.teams[0].wood >= game.balance.tower_wood and found_carrying, "Ordinary workers carry and deposit enough wood for a tower")
	await _click(game.hud.structure_button)
	check(game.pads[0].occupied(), "First tower is built with the real opening economy")
	await _capture("opening_tower")
	while game.match_seconds < 60:
		await create_timer(0.25).timeout
	check(game.commanders.size() == 4 and not game.match_finished, "The first real-time minute remains a live four-commander match")
	check(game.teams[0].combat_count > 0 and game.teams[1].combat_count > 0, "Both teams develop real army pressure during the opening")
	check(game.teams[0].wood > 0, "Worker gathering continues after construction")
	await _capture("opening_minute")
	print("OPENING COMPLETE checks=", checks, " failures=", failures, " match_seconds=", game.match_seconds, " wall_seconds=", (Time.get_ticks_msec()-started)/1000.0)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	settings.set_onboarding_enabled(original_guidance, false)
	localization.set_language(original_language, false)
	root.get_node("AudioFeedback").stop_all()
	await create_timer(0.1).timeout
	quit(1 if failures else 0)

func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	RenderingServer.force_draw()
	var picture: Image = root.get_texture().get_image()
	picture.save_png("res:/" + "/tests/artifacts/" + label + ".png")
