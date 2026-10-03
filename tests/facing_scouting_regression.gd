extends SceneTree
## Exercise facing commands and real viewport input ownership independently of game ticks.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.pause_on_focus_loss = false
	game.force_touch_controls = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(game)
	await process_frame
	await process_frame
	var actor = game.player
	var controller = actor.controller
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	for action_button in game.hud.ability_buttons.values():
		action_button.process_mode = Node.PROCESS_MODE_ALWAYS
	var camera: Camera2D = actor.get_node("Camera2D")
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	var minimap = game.hud.minimap_column.get_child(1)
	controller.mobile_auto_attack = false
	controller.set_scripted_command(Vector2.ZERO, false)
	actor.position = Vector2(650, 1410)
	var foe = game.commanders[2]
	foe.position = actor.position + Vector2.RIGHT * 60
	controller.focus_target = foe
	for id in [&"dash", &"guard", &"heavy"]:
		actor.cancel_action()
		actor.ability_cooldowns[id] = 0.0
		actor.update_movement_facing(Vector2.UP)
		var result = game.session.execute(MatchCommand.new(MatchCommand.Action.ABILITY, actor.commander_id, {"ability_id": id, "direction": Vector2.DOWN}))
		check(result.success and actor.facing == Vector2.UP, "Legacy opposite heading cannot redirect " + String(id))
		actor.apply_input({"direction": Vector2.LEFT, "delta": MatchSession.STEP})
		check(actor.facing == Vector2.UP, "Active ability retains commitment: " + String(id))
	actor.cancel_action()
	actor.ability_cooldowns[&"dash"] = 0.0
	controller.set_scripted_command(Vector2(-1, -1), false)
	controller.request_ability(&"dash")
	controller.drive(actor, MatchSession.STEP)
	check(actor.action_state == &"dash" and actor.facing.is_equal_approx(Vector2(-1, -1).normalized()), "Same-tick movement supplies ability facing")
	actor.cancel_action()
	controller.set_scripted_command(Vector2.ZERO, false)
	controller.drive(actor, MatchSession.STEP)
	check(actor.facing.is_equal_approx(Vector2(-1, -1).normalized()), "Stationary commander retains movement facing despite focus target")
	actor.character_visual.cancel_attack()
	actor.step_presentation(MatchSession.STEP, true)
	check(actor.character_visual.direction == 5, "Idle sprite agrees with retained diagonal facing")
	foe.cancel_action()
	foe.apply_input({"goal": foe.position + Vector2.UP * 100, "delta": MatchSession.STEP})
	check(foe.facing == Vector2.UP, "AI goal movement updates gameplay facing")
	var ai = foe.controller
	ai.target = actor
	ai._request_ability(&"dash", Vector2.DOWN)
	ai._use_combat_ability(foe)
	check(foe.action_state == &"ready" and not ai.pending_ability.is_empty(), "AI cannot turn during ability activation")
	foe.apply_input({"direction": Vector2.DOWN, "delta": MatchSession.STEP})
	game.session.ticks += 1
	ai._use_combat_ability(foe)
	check(foe.action_state == &"dash" and foe.facing == Vector2.DOWN and ai.pending_ability.is_empty(), "AI activates only after movement on an earlier tick")
	# Use viewport dispatch rather than calling handlers to detect world-input leakage.
	controller.clear_scripted_command()
	controller.reset_touch()
	var movement := InputEventScreenTouch.new()
	movement.index = 2
	movement.position = Vector2(100, 300)
	movement.pressed = true
	viewport.push_input(movement, true)
	check(controller.touch_index == 2, "Movement finger acquired before scouting")
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = minimap.get_global_rect().get_center()
	var player_position: Vector2 = actor.position
	var ticks: int = game.session.ticks
	viewport.push_input(touch, true)
	check(actor.scouting and minimap.scouting_finger == 7 and controller.touch_index == 2 and controller.focus_target == null, "Scouting captures its finger without movement or targeting leakage")
	check(actor.position == player_position and game.session.ticks == ticks, "Scouting leaves gameplay unchanged")
	var view_center: Vector2 = camera.global_position
	actor.position += Vector2(30, 0)
	minimap._process(0.01)
	check(camera.global_position.is_equal_approx(view_center), "Scouting camera stays fixed while commander moves")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = minimap.get_global_rect().end + Vector2(500, 500)
	viewport.push_input(drag, true)
	for zoom in [0.7, 0.9, 1.1]:
		camera.zoom = Vector2.ONE * zoom
		minimap._process(0.01)
		var half := Vector2(viewport.size) / camera.zoom * 0.5
		check(camera.global_position.is_equal_approx(game.MAP_SIZE - half), "Camera clamps far corner at zoom " + str(zoom))
	# The action finger remains independent; scouting does not change ability facing.
	var button = game.hud.ability_buttons[&"guard"]
	button.disabled = false
	var action := InputEventScreenTouch.new()
	action.index = 4
	action.position = button.get_global_rect().get_center()
	action.pressed = true
	viewport.push_input(action, true)
	action.pressed = false
	viewport.push_input(action, true)
	check(controller.pending_abilities.size() == 1 and minimap.scouting_finger == 7 and controller.touch_index == 2, "Movement, scouting and ability fingers coexist")
	touch.pressed = false
	touch.position = drag.position
	viewport.push_input(touch, true)
	check(not actor.scouting and camera.position == Vector2.ZERO and controller.touch_index == 2, "Outside release restores follow without releasing movement")
	movement.pressed = false
	viewport.push_input(movement, true)
	check(controller.touch_index == -1 and controller.pending_abilities.size() == 1, "Movement release preserves another finger's queued ability")
	controller.reset_touch()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = minimap.get_global_rect().get_center()
	viewport.push_input(mouse, true)
	check(minimap.scouting_mouse and actor.scouting, "Mouse press starts scouting")
	var motion := InputEventMouseMotion.new()
	motion.position = minimap.global_position - Vector2(100, 100)
	viewport.push_input(motion, true)
	var half := Vector2(viewport.size) / camera.zoom * 0.5
	check(camera.global_position.is_equal_approx(half), "Outside mouse drag clamps near corner")
	mouse.pressed = false
	mouse.position = motion.position
	viewport.push_input(mouse, true)
	check(not actor.scouting and not minimap.scouting_mouse, "Outside mouse release restores follow")
	for dimensions in [Vector2i(960, 540), Vector2i(1600, 720), Vector2i(1280, 800)]:
		viewport.size = dimensions
		game.safe_area_override = Rect2(24, 10, dimensions.x - 48, dimensions.y - 20)
		game.hud._apply_safe_area()
		await process_frame
		for locale in ["en", "ru"]:
			root.get_node("Localization").set_language(locale, false)
			minimap._process(0.01)
			touch.pressed = true
			touch.position = minimap.get_global_rect().get_center()
			viewport.push_input(touch, true)
			check(actor.scouting and actor.scouting_target.is_equal_approx(game.MAP_SIZE * 0.5), "Safe-area map coordinates at " + str(dimensions) + " / " + locale)
			check(minimap.tooltip_text == TranslationServer.translate("MINIMAP_SCOUT_HINT"), "Localized scouting guidance: " + locale)
			if DisplayServer.get_name() != "headless":
				camera.reset_smoothing()
				camera.force_update_scroll()
				await RenderingServer.frame_post_draw
				check(camera.get_screen_center_position().is_equal_approx(camera.global_position), "Rendered viewport matches scouting region")
				var capture: Image = viewport.get_texture().get_image()
				check(capture.save_png("res:/" + "/tests/artifacts/scouting_%dx%d_%s.png" % [dimensions.x, dimensions.y, locale]) == OK, "Scouting screenshot saved")
				capture = null
			touch.pressed = false
			viewport.push_input(touch, true)
	game.safe_area_override = Rect2()
	for reason in ["pause", "focus", "cancel", "layout", "hidden", "death", "finish"]:
		touch.pressed = true
		touch.position = minimap.get_global_rect().get_center()
		viewport.push_input(touch, true)
		check(actor.scouting, "Scouting starts before " + reason)
		match reason:
			"pause":
				game.session.pause()
				minimap._process(0.01)
				game.session.resume()
			"focus": minimap._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"cancel":
				touch.pressed = false
				touch.canceled = true
				viewport.push_input(touch, true)
				touch.canceled = false
			"layout":
				viewport.size = Vector2i(960, 540)
				game.hud._apply_safe_area()
				await process_frame
				minimap._process(0.01)
			"hidden":
				minimap.hide()
				minimap._process(0.01)
				minimap.show()
			"death":
				actor.die()
				minimap._process(0.01)
				actor.alive = true
			"finish":
				game.session.finish()
				minimap._process(0.01)
		check(not actor.scouting and minimap.scouting_finger < 0 and camera.position == Vector2.ZERO, "Scouting cancels cleanly on " + reason)
	# Oversized view must center instead of producing inverted clamp bounds.
	viewport.size = Vector2i(8000, 8000)
	actor.scout_camera(Vector2.ZERO)
	check(camera.global_position.is_equal_approx(game.MAP_SIZE * 0.5), "View larger than map centers both axes")
	actor.end_camera_scouting(true)
	movement = null
	touch = null
	drag = null
	action = null
	mouse = null
	motion = null
	await physics_frame
	await physics_frame
	root.get_node("AudioFeedback").stop_all()
	game.free()
	viewport.free()
	await process_frame
	root.get_node("AudioFeedback").queue_free()
	await create_timer(0.5).timeout
	quit(1 if failures else 0)
