extends SceneTree
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var dimensions = (args[0] if args.size() > 0 else "960x540").split("x")
	root.get_node("Localization").set_language(args[1] if args.size() > 1 else "en", false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.add_child(viewport)
	root.get_node("AudioFeedback").stop_all()
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.force_touch_controls = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.safe_area_override = Rect2(24, 10, viewport.size.x - 48, viewport.size.y - 20)
	viewport.add_child(game)
	current_scene = viewport
	await process_frame
	await process_frame
	var hud = game.hud
	check(hud.compact_mode and not hud.shop_dock.visible, "Mobile economy drawer starts collapsed")
	check(hud.minimap_column.visible and hud.minimap_column.get_parent() == hud.controls, "Minimap remains visible independently of drawer")
	check(game.player.controller.mobile_auto_attack, "Mobile auto attack is independent of movement finger")
	for id in hud.ability_buttons:
		var button = hud.ability_buttons[id]
		check(button.size.x >= 64 and button.size.y >= 64, "Primary action has 64 pixel target: " + String(id))
		check(not button.get_global_rect().intersects(hud.mobile_interact_button.get_global_rect()), "Action does not overlap interact: " + String(id))
	check(hud.tower_buttons.size() == 3, "Contextual construction offers all three tower types")
	hud.drawer_button.pressed.emit()
	await process_frame
	check(hud.shop_dock.visible and not paused, "Opening economy drawer preserves running match")
	var movement_area := Rect2(hud.controls.global_position + Vector2(42, hud.controls.size.y * 0.57 - 74), Vector2(148, 148))
	check(not hud.shop_dock.get_global_rect().intersects(movement_area), "Economy drawer leaves movement stick area clear")
	for action in hud.ability_buttons.values():
		check(not hud.shop_dock.get_global_rect().intersects(action.get_global_rect()), "Economy drawer leaves combat action area clear")
	check(hud.shop_pages[0] is GridContainer and hud.shop_pages[2].get_parent() is ScrollContainer, "Mobile recruitment uses grid and upgrades scroll")
	hud.drawer_button.pressed.emit()
	game.player.position = game.player.team.base_position
	game.player.health = 60.0
	game.player.heal_cooldown = 0.0
	hud.mobile_interact_button.pressed.emit()
	game.session.step()
	check(game.player.healing, "Actual mobile Interact button starts healing through validated session command")
	game.player.cancel_action()
	var button = hud.ability_buttons[&"dash"]
	var press := InputEventScreenTouch.new()
	press.index = 4
	press.pressed = true
	press.position = button.get_global_rect().get_center()
	button._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = press.position + Vector2(70, 0)
	button._input(drag)
	drag.position = press.position
	button._input(drag)
	press.pressed = false
	button._input(press)
	check(game.player.controller.pending_abilities.size() == 1, "Returning inside action button restores activation")
	game.player.controller.reset_touch()
	press.pressed = true
	button._input(press)
	press.pressed = false
	button._input(press)
	check(game.player.controller.pending_abilities.size() == 1, "Quick tap queues one shared ability command")
	game.player.controller.reset_touch()
	var movement := InputEventScreenTouch.new()
	movement.index = 2
	movement.pressed = true
	movement.position = Vector2(100, 300)
	game.player.controller._unhandled_input(movement)
	press.pressed = true
	button._input(press)
	drag.position = press.position + Vector2(70, 0)
	button._input(drag)
	press.pressed = false
	press.position = drag.position
	button._input(press)
	check(game.player.controller.touch_index == 2 and game.player.controller.pending_abilities.is_empty(), "Outside action release cancels independently of held movement finger")
	press.position = button.get_global_rect().get_center()
	press.pressed = true
	button._input(press)
	press.pressed = false
	button._input(press)
	check(game.player.controller.touch_index == 2 and game.player.controller.pending_abilities.size() == 1 and not game.player.controller.pending_abilities[0].has("direction"), "Action release queues facing-based ability independently of movement finger")
	game.player.controller.reset_touch()
	check(game.player.controller.pending_abilities.is_empty(), "Input cleanup clears queued abilities")
	viewport.size = Vector2i(540, 960)
	hud._apply_safe_area()
	check(paused and hud.portrait_notice.visible, "Portrait pauses match and displays rotation instruction")
	viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	hud._apply_safe_area()
	check(not paused and not hud.portrait_notice.visible, "Landscape clears rotation pause")
	movement = null
	press = null
	drag = null
	# Drain manually stepped audio starts before teardown.
	await physics_frame
	await physics_frame
	root.get_node("AudioFeedback").stop_all()
	game.free()
	viewport.free()
	await process_frame
	root.get_node("AudioFeedback").queue_free()
	await create_timer(0.5).timeout
	quit(1 if failures else 0)
