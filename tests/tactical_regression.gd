extends SceneTree
var game = null
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ",message)
func _run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	for entity in get_nodes_in_group("combatants"):
		entity.remove_from_group("combatants")
	var commander = game.commanders[1]
	commander.position = Vector2(1200,900)
	commander.path_goal = Vector2(2050,900)
	commander.travel_path = PackedVector2Array([commander.path_goal])
	for step in range(500):
		commander.travel_toward(Vector2(2050,900),0.05)
	check(commander.position.distance_to(Vector2(2050,900)) < 20,"Stale direct path recovers around terrain")
	commander.position = Vector2(400,1410)
	commander.travel_path = PackedVector2Array([Vector2(400,1410)])
	commander.path_goal = Vector2(400,1410)
	for step in range(20):
		commander.travel_toward(Vector2(430,1410),0.05)
	check(commander.position.distance_to(Vector2(430,1410)) < 5,"Near moving endpoint updates instead of stalling")
	commander.position = Vector2(1150,650)
	commander.health = 30
	for step in range(800):
		commander._physics_process(0.05)
		if commander.health == commander.max_health:
			break
	check(commander.health == commander.max_health,"AI returns from forward grove and resupplies")
	commander.die()
	commander._physics_process(12.1)
	check(commander.travel_path.is_empty() and commander.controller.route.is_empty(),"Respawn resets movement and tactical path")
	var worker = game.WORKER_SCENE.instantiate()
	worker.configure(game.teams[0],game)
	worker.position = Vector2(1120,670)
	game.entities.add_child(worker)
	var threat = game.UNIT_SCENE.instantiate()
	threat.configure(game.teams[1],game,game.unit_data[&"melee"])
	threat.position = Vector2(1200,670)
	game.entities.add_child(threat)
	var distance: float = worker.position.distance_to(threat.position)
	for step in range(10):
		worker._physics_process(0.05)
	check(worker.position.distance_to(threat.position) > distance,"Worker retreats from a sensed enemy")
	check(worker.danger_timer > 0,"Worker remembers dangerous grove temporarily")
	threat.free()
	worker.free()
	var archer = game.UNIT_SCENE.instantiate()
	archer.configure(game.teams[0],game,game.unit_data[&"ranged"])
	archer.position = Vector2(2250,1660)
	game.entities.add_child(archer)
	var foe = game.UNIT_SCENE.instantiate()
	foe.configure(game.teams[1],game,game.unit_data[&"melee"])
	foe.position = Vector2(2250,1840)
	game.entities.add_child(foe)
	var hp: float = foe.health
	archer.attack(foe)
	check(foe.health == hp and archer.closest_enemy(300) == null,"Terrain blocks shots and target detection")
	archer.free()
	foe.free()
	var tank = game.UNIT_SCENE.instantiate()
	tank.configure(game.teams[0],game,game.unit_data[&"tank"])
	tank.position = Vector2(1200,1300)
	game.entities.add_child(tank)
	var tower = game.TOWER_SCRIPT.new()
	tower.configure(game.teams[1],game)
	tower.position = Vector2(1400,1300)
	game.entities.add_child(tower)
	foe = game.UNIT_SCENE.instantiate()
	foe.configure(game.teams[1],game,game.unit_data[&"melee"])
	foe.position = Vector2(1250,1300)
	game.entities.add_child(foe)
	tank._physics_process(0.05)
	check(tank.target == tower,"Tank prioritizes fortifications over nearby infantry")
	tank.position = tower.position+Vector2(-60,0)
	hp = tower.health
	tank.attack(tower)
	check(is_equal_approx(hp-tower.health,42.0),"Tank siege damage is specific to structures")
	tank.free()
	tower.free()
	foe.free()
	# Deliberately packed formation at a crossing; movement and attacks must disperse it.
	var army: Array = []
	for team in game.teams:
		for i in range(30):
			var unit = game.UNIT_SCENE.instantiate()
			unit.configure(team,game,game.unit_data[[&"tank",&"melee",&"ranged"][i%3]])
			unit.position = Vector2(2050 if team.team_id == 1 else 2470,1400) + Vector2(i%5*14,i/5*14)
			unit.formation_slot = i%5
			unit.route = game.navigation.army_route(1,team.team_id == 2)
			unit.route_index = 3
			unit.health *= 4.0
			unit.max_health = unit.health
			game.entities.add_child(unit)
			army.append(unit)
	var terrain_violations: int = 0
	for step in range(600):
		game._physics_process(0.05)
		for unit in army:
			if is_instance_valid(unit) and unit.alive:
				unit._physics_process(0.05)
				if not game.navigation.walkable(unit.position,unit.body_radius-0.1):
					terrain_violations += 1
		if step%20 == 0:
			await process_frame
	var survivors: int = 0
	var overlaps: int = 0
	var damaged: int = 0
	for unit in army:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		survivors += 1
		if unit.health < unit.max_health:
			damaged += 1
		for other in army:
			if is_instance_valid(other) and other != unit and other.alive and other.position.distance_to(unit.position) < 8:
				overlaps += 1
	print("CROWD survivors=",survivors," severe_overlap_pairs=",overlaps/2," damaged_survivors=",damaged)
	check(terrain_violations == 0,"Large battle respects terrain")
	check(overlaps < maxi(4,survivors/4),"Large battle avoids severe stacking")
	check(survivors < 60 or damaged > 10,"Packed frontlines reach and damage enemies")
	print("TACTICAL failures=",failures)
	quit(1 if failures else 0)
