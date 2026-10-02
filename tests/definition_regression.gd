extends SceneTree
## A renamed ranged recruit and modified map/rules must work without controller edits.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.presentation_enabled = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.catalog = game.catalog.duplicate(true)
	var copied_units: Array[UnitStats] = []
	for original in game.catalog.units:
		var unit: UnitStats = original.duplicate(true)
		if unit.tactical_role == &"ranged":
			unit.id = &"archer_fixture"
		copied_units.append(unit)
	game.catalog.units = copied_units
	game.map_definition = game.map_definition.duplicate(true)
	game.map_definition.bounds.x += 200
	game.map_definition.routes[1][2] += Vector2(80, 0)
	game.rules = game.rules.duplicate(true)
	game.rules.worker_cost = 70
	root.add_child(game)
	var failures := 0
	if game.MAP_SIZE.x != 4800 or game.navigation.bounds.x != 4800:
		failures += 1
	if game.worker_cost != 70:
		failures += 1
	if not game.commanders[1].controller.roster.has(&"archer_fixture"):
		failures += 1
	if not game.purchase(1, &"archer_fixture", false, 1):
		failures += 1
	else:
		var recruit = game.entities.get_child(game.entities.get_child_count() - 1)
		if recruit.kind != &"archer_fixture" or recruit.tactical_role != &"ranged":
			failures += 1
		game.session.step()
	if load("res://resources/default_map.tres").bounds.x != 4600 or load("res://resources/units/ranged.tres").id != &"ranged":
		failures += 1
	game.free()
	await process_frame
	print("DEFINITION EXTENSION failures=", failures)
	quit(1 if failures else 0)
