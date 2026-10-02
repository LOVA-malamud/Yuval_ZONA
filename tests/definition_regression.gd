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
	var invalid_catalog: ContentCatalog = game.catalog.duplicate(true)
	invalid_catalog.units = game.catalog.units.duplicate()
	invalid_catalog.units.append(game.catalog.units[0])
	if invalid_catalog.validation_errors().is_empty():
		failures += 1
	var invalid_rules := MatchRules.new()
	invalid_rules.army_speed_multiplier = NAN
	if invalid_rules.validation_errors().is_empty():
		failures += 1
	var invalid_map := MapDefinition.new()
	invalid_map.routes[0][0] = Vector2(-100, 0)
	if invalid_map.validation_errors().is_empty():
		failures += 1
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
	# Legacy balance names still configure Guard, with explicit tower values winning.
	var overridden = load("res://scenes/main/main.tscn").instantiate()
	overridden.presentation_enabled = false
	overridden.process_mode = Node.PROCESS_MODE_DISABLED
	overridden.simulation_config = {"shared": {
		"balance": {"tower_health":777.0,"tower_damage":29.0,"tower_money":170,"tower_wood":71,"tower_range":280.0,"tower_cooldown":1.8},
		"towers": {"guard":{"damage":33.0},"splash":{"max_health":550.0}},
		"groves": [{"center":[450,950],"count":2,"wood":80,"zone":"home"}]
	}}
	root.add_child(overridden)
	var guard: TowerDefinition = overridden.tower_data[&"guard"]
	if guard.max_health != 777.0 or guard.damage != 33.0 or guard.money_cost != 170 or guard.wood_cost != 71 or guard.attack_range != 280.0 or guard.attack_cooldown != 1.8:
		failures += 1
	if overridden.tower_data[&"splash"].max_health != 550.0:
		failures += 1
	var trees = overridden.get_node("Trees").get_children()
	if trees.size() != 4:
		failures += 1
	for tree in trees:
		if tree.wood_remaining != 80 or tree.renewable:
			failures += 1
	if load("res://resources/towers/guard.tres").damage != 18.0 or load("res://resources/towers/splash.tres").max_health != 420.0 or not load("res://resources/default_map.tres").tree_groves.is_empty():
		failures += 1
	overridden.free()
	await process_frame
	print("DEFINITION EXTENSION failures=", failures)
	quit(1 if failures else 0)
