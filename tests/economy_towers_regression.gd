extends SceneTree
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := MapDefinition.new()
	var placements := map.tree_placements()
	check(placements.size() == 56, "Expected 28 finite trees per side")
	var totals := {1: 0, 2: 0}
	var zones := {&"home": 0, &"transition": 0, &"forward": 0}
	var navigation := RouteMap.new(map)
	for entry in placements:
		totals[entry.side] += entry.wood
		zones[entry.zone] += 1
		check(navigation.walkable(entry.position, 38), "Trees must be reachable")
		var mirrored: bool = false
		for other in placements:
			if other.position == Vector2(map.bounds.x - entry.position.x, entry.position.y) and other.wood == entry.wood:
				mirrored = true
		check(mirrored, "Each tree needs a mirrored counterpart")
	check(totals[1] == 5360 and totals[2] == 5360, "Finite supply must be symmetric")
	check(zones[&"home"] == 32 and zones[&"transition"] == 16 and zones[&"forward"] == 8, "Tree density must taper toward contested territory")
	var tree := TreeResource.new()
	tree.wood_remaining = 17
	check(not tree.renewable, "Trees default to finite")
	check(tree.harvest(12) == 12 and tree.harvest(12) == 5 and tree.harvest(12) == 0, "Harvest conserves finite stock")
	check(not tree.available(), "Depleted tree unavailable")
	tree.free()
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var definitions := {"guard": preload("res://resources/towers/guard.tres"), "splash": preload("res://resources/towers/splash.tres"), "long_range": preload("res://resources/towers/long_range.tres")}
	for id in definitions:
		var definition: TowerDefinition = definitions[id]
		var tower = game.TOWER_SCRIPT.new()
		tower.configure(game.teams[0], game)
		tower.definition = definition.duplicate(true)
		tower.position = Vector2(1100, 1400)
		game.entities.add_child(tower)
		check(tower.tower_id() == StringName(id), "Tower identity preserved")
		check(tower.health == definition.max_health and tower.damage == definition.damage, "Tower definition initializes combat")
		var first = game.UNIT_SCENE.instantiate()
		first.configure(game.teams[1], game, game.unit_data[&"tank"])
		first.position = tower.position + Vector2(80, 0)
		game.entities.add_child(first)
		var hp: float = first.health
		if id == "long_range":
			tower.attack(first)
			check(first.health == hp and tower.cooldown == 0, "Long-range tower rejects targets in dead zone")
			first.position = tower.position + Vector2(220, 0)
			tower.attack(first)
			check(first.health == hp - definition.damage, "Long-range tower hits outside minimum range")
		elif id == "splash":
			first.position = tower.position + Vector2(180, 0)
			var second = game.UNIT_SCENE.instantiate()
			second.configure(game.teams[1], game, game.unit_data[&"tank"])
			second.position = first.position + Vector2(0, 40)
			game.entities.add_child(second)
			var friendly = game.UNIT_SCENE.instantiate()
			friendly.configure(game.teams[0], game, game.unit_data[&"tank"])
			friendly.position = first.position + Vector2(0, 20)
			game.entities.add_child(friendly)
			var friendly_hp: float = friendly.health
			var second_hp: float = second.health
			tower.attack(first)
			check(first.health == hp - definition.damage and second.health == second_hp - definition.damage, "Splash tower damages clustered enemies")
			check(friendly.health == friendly_hp, "Splash tower excludes friendly actors")
			game.session.unregister_actor(second)
			game.session.unregister_actor(friendly)
			second.free()
			friendly.free()
		game.session.unregister_actor(first)
		first.free()
		check(tower.upgrade_cost() == Vector2i(100,65), "Level one upgrade cost")
		tower.apply_upgrade()
		check(tower.upgrade_cost() == Vector2i(200,130), "Level two upgrade cost")
		tower.apply_upgrade()
		check(tower.level == 3, "Three upgrade levels")
		var health: float = tower.max_health
		tower.apply_upgrade()
		check(tower.max_health == health and tower.level == 3, "Maximum upgrade guard")
		if id != "guard":
			check(tower.max_health == definition.max_health + 240 and tower.damage == definition.damage * 1.5, "Alternative upgrade profile")
		game.session.unregister_actor(tower)
		tower.free()
	root.get_node("AudioFeedback").stop_all()
	game.free()
	await create_timer(0.1).timeout
	print("ECONOMY TOWERS CHECK failures=", failures)
	quit(1 if failures else 0)
