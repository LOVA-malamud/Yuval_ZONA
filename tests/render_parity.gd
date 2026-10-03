extends SceneTree
## Render the same authoritative tick trace at 30 and 60 presentation frames/sec.
const Trace = preload("res://tests/step_parity.gd")
var reference: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures := 0
	for fps in [30, 60]:
		Engine.max_fps = fps
		var game = load("res://scenes/main/main.tscn").instantiate()
		game.pause_on_focus_loss = false
		game.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(game)
		var friends := _battle(game)
		for tick in range(240):
			if tick == 52:
				# Leave three dead nodes queued across the next 30 FPS physics tick.
				game.commanders[1].rally_cooldown = 2 * MatchSession.STEP
				for index in range(3):
					friends[index].take_damage(9999999, 2)
			game.player.controller.set_scripted_command(Vector2.RIGHT if tick < 60 else Vector2.ZERO, true)
			if tick in [0, 60, 120]:
				game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 1, {"id": &"ranged", "route": 1}))
			if tick in [20, 80, 140]:
				game.player.cancel_action()
				game.session.submit(MatchCommand.new(MatchCommand.Action.ABILITY,1,{"ability_id": [&"dash", &"guard", &"heavy"][[20,80,140].find(tick)], "direction": Vector2.RIGHT}))
				game.launch_projectile(2, Vector2(2280, 1450), game.player.position, 5.0, 1.0, 3)
			game.session.step()
			var state := Trace.snapshot(game)
			if fps == 30:
				reference.append(state)
			elif state != reference[tick]:
				push_error("Rendered trace diverged at tick %d" % tick)
				failures += 1
				break
			if (tick + 1) % (60 / fps) == 0:
				await process_frame
		game.free()
		await process_frame
	root.get_node("AudioFeedback").stop_all()
	root.get_node("AudioFeedback").queue_free()
	await create_timer(0.5).timeout
	print("RENDER PARITY 30/60 fps ticks=240 failures=", failures)
	quit(1 if failures else 0)

func _battle(game) -> Array:
	game.player.position = Vector2(2200, 1450)
	game.commanders[1].position = Vector2(2200, 1350)
	game.commanders[2].position = Vector2(2380, 1450)
	game.commanders[3].position = Vector2(2420, 1300)
	for commander in game.commanders:
		commander.max_health = 1000000
		commander.health = commander.max_health
		commander.rally_cooldown = 30
	for team in game.teams:
		team.money = 10000
	var friends := []
	var enemies := []
	for index in range(4):
		game.purchase(1, &"melee", false, 1)
		var unit = game.entities.get_child(game.entities.get_child_count() - 1)
		unit.position = Vector2(2200 + index * 20, 1350)
		unit.practice_unit = true
		unit.max_health = 1000000
		unit.health = unit.max_health
		friends.append(unit)
	for index in range(3):
		game.purchase(2, &"melee", false, 1)
		var unit = game.entities.get_child(game.entities.get_child_count() - 1)
		unit.position = Vector2(2215 + index * 20, 1350)
		unit.practice_unit = true
		unit.max_health = 1000000
		unit.health = unit.max_health
		enemies.append(unit)
	game.commanders[1].controller.scan_timer = INF
	game.commanders[1].controller.target = enemies[0]
	game.player.get_node("Camera2D").reset_smoothing()
	game.player.get_node("Camera2D").force_update_scroll()
	return friends
