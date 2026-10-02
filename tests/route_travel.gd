extends SceneTree
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	for entity in get_nodes_in_group("combatants"):
		game.session.unregister_actor(entity)
	for team in game.teams:
		for lane in range(3):
			for type in [&"melee", &"ranged", &"tank"]:
				var unit = game.UNIT_SCENE.instantiate()
				unit.configure(team, game, game.unit_data[type])
				unit.position = team.spawn_position
				unit.route = game.navigation.army_route(lane, team.team_id == 2)
				game.entities.add_child(unit)
				game.session.unregister_actor(unit)
				var elapsed: float = 0.0
				var destination: Vector2 = unit.route[-1]
				while elapsed < 100.0 and unit.position.distance_to(destination) > 75.0:
					unit.step_gameplay(1.0 / 60.0)
					elapsed += 1.0 / 60.0
					if not game.navigation.walkable(unit.position, unit.body_radius - 0.1):
						failures += 1
						break
				if unit.position.distance_to(destination) > 75.0:
					failures += 1
					push_error("Stuck: %s lane %d team %d at %s" % [type, lane, team.team_id, unit.position])
				print("TRAVEL team=%d lane=%d unit=%s seconds=%.1f" % [team.team_id, lane, type, elapsed])
				unit.free()
	# Cross-island pursuit/worker detour rather than lane-only movement.
	var body = game.WORKER_SCENE.instantiate()
	body.configure(game.teams[0], game)
	body.position = Vector2(1200, 900)
	game.entities.add_child(body)
	for step in range(800):
		body.travel_toward(Vector2(2050, 900), 0.05)
	if body.position.distance_to(Vector2(2050, 900)) > 30:
		failures += 1
	root.get_node("AudioFeedback").stop_all()
	await create_timer(0.1).timeout
	print("ROUTE CHECK failures=", failures)
	quit(1 if failures else 0)
