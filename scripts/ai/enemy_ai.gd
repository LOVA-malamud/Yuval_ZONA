extends Node
## Local perception + a friendly base alarm, never global enemy position queries.
## Each commander spends through the same command boundary as the human.
var game = null
var team: GameTeam
var actor = null
var personality: String = "aggressive"
var decision_timer: float = 10.0
var decision_count: int = 0
var rng := RandomNumberGenerator.new()
var scan_timer: float = 0.0
var target: CombatEntity
var base_threat: CombatEntity
var build_goal = null
var route_id: int = 1
var route := PackedVector2Array()
var route_index: int = 1
var roster: Array[StringName] = [&"tank", &"melee", &"ranged", &"melee", &"ranged"]

func _ready() -> void:
	rng.seed = game.strategy_seed * 97 + actor.commander_id * 13

func _process(delta: float) -> void:
	if game.match_finished or not actor.alive:
		return
	decision_timer -= delta
	if decision_timer > 0.0:
		return
	decision_timer = game.balance.aggressive_decision_seconds if personality == "aggressive" else game.balance.economic_decision_seconds
	decision_timer += rng.randf_range(-0.7, 0.7)
	decision_count += 1
	if is_instance_valid(build_goal) and build_goal.occupied():
		build_goal = null
	var reserve: int = game.balance.ally_money_reserve if personality == "ally" else 20
	var wood_reserve: int = game.balance.ally_wood_reserve if personality == "ally" else 0
	if decision_count % 5 == 1:
		route_id = (int(game.match_seconds / 90.0) + team.team_id + game.strategy_seed % 3) % 3
		if personality == "economic" and decision_count % 10 == 1:
			route_id = (route_id + 1) % 3
		# Reinforce established pressure rather than abandoning it on a fixed rotation.
		var pressure: Array[float] = [0.0, 0.0, 0.0]
		for unit in game.entities.get_children():
			if unit is CombatEntity and unit.alive and unit.team == team and unit.kind in [&"melee", &"ranged", &"tank"]:
				pressure[unit.route_id] += 1.0 + minf(1.0,unit.position.distance_to(team.base_position)/3800.0)
		var best: int = 0
		for lane in range(1,3):
			if pressure[lane] > pressure[best]:
				best = lane
		if pressure[best] >= 4.0:
			route_id = best
		# A visible threat biases the next group toward its approach lane.
		if actor.valid_enemy(base_threat):
			route_id = 0 if base_threat.position.y < 1050 else (2 if base_threat.position.y > 1600 else 1)
	if personality != "aggressive" and decision_count % 4 == 1 and team.worker_count >= 3 and team.wood >= game.balance.tower_wood + wood_reserve:
		build_goal = _choose_pad()
	# Both controllers respect one teammate's announced construction budget.
	var construction_pending: bool = false
	for commander in game.commanders:
		if commander.team == team and commander.controller.get("build_goal") != null:
			construction_pending = true
	if construction_pending:
		reserve += game.balance.tower_money
	if team.money < reserve + 50:
		return
	if team.worker_count < (5 if personality == "economic" else 4) and (personality != "aggressive" or team.worker_count < 2):
		game.purchase(team.team_id, &"worker", false)
	elif build_goal != null and team.can_afford(reserve, game.balance.tower_wood + wood_reserve) and game.nearest_pad(actor) == build_goal:
		game.build_tower(actor, build_goal)
		build_goal = null
	else:
		var group_size: int = 5 if personality == "aggressive" else 2
		if personality == "aggressive" and team.money < reserve + 365 and not actor.valid_enemy(base_threat):
			group_size = 0
		elif personality != "aggressive" and not actor.valid_enemy(base_threat) and team.combat_count >= 3:
			for commander in game.commanders:
				if commander != actor and commander.team == team and commander.controller.get("personality") == "aggressive":
					group_size = 0
		for recruit in range(group_size):
			var id: StringName = roster[(decision_count + actor.commander_id + recruit) % roster.size()]
			if team.money >= reserve + int(game.unit_data[id].money_cost):
				game.purchase(team.team_id, id, false, route_id)
	if decision_count % 4 == 0:
		# Grow the field economy before repeatedly fortifying an untouched King.
		var order: Array = [7, 5, 6, 4, 7, 0, 1, 2, 3]
		var definition: UpgradeDefinition = game.upgrades[order[(decision_count / 4 - 1) % order.size()]]
		var level: int = team.upgrade_level(definition.id)
		var fortification_needed: bool = definition.category != "king" or level < 2
		if fortification_needed and team.wood >= definition.cost(level) + wood_reserve + game.balance.tower_wood:
			game.purchase_upgrade(team.team_id, definition.id, false)

func _choose_pad():
	var best = null
	var best_distance: float = 1000.0
	for pad in game.pads:
		if pad.occupied() or pad.rebuild_remaining > 0 or (pad.home_team_id != 0 and pad.home_team_id != team.team_id):
			continue
		var distance: float = actor.position.distance_to(pad.position)
		if distance < best_distance:
			best = pad
			best_distance = distance
	return best

func drive(body, delta: float) -> void:
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 0.45
		target = body.closest_enemy(340.0)
		base_threat = null
		if is_instance_valid(team.king):
			base_threat = team.king.closest_enemy(600.0)
	if body.health < body.max_health * 0.3:
		body.tactical_status = "STATUS_RESUPPLY"
		route.clear()
		body.travel_toward(team.base_position + Vector2(0, 110), delta)
		if body.position.distance_to(team.base_position) < 180:
			body.interact()
	elif body.valid_enemy(target):
		body.tactical_status = "STATUS_ENGAGING"
		if body.edge_distance(target) <= body.attack_range:
			body.attack(target)
		else:
			body.travel_toward(target.global_position, delta)
	elif body.valid_enemy(base_threat):
		body.tactical_status = "STATUS_DEFENDING"
		body.travel_toward(base_threat.position, delta)
	elif is_instance_valid(build_goal) and not build_goal.occupied():
		body.tactical_status = "STATUS_BUILDING"
		body.travel_toward(build_goal.position, delta)
		var reserve: int = game.balance.ally_money_reserve if personality == "ally" else 0
		var wood_reserve: int = game.balance.ally_wood_reserve if personality == "ally" else 0
		if team.can_afford(game.balance.tower_money + reserve, game.balance.tower_wood + wood_reserve) and game.build_tower(actor, build_goal):
			build_goal = null
	else:
		var defend: bool = personality != "aggressive" and fmod(game.match_seconds + actor.commander_id * 7.0, 100.0) < 52.0
		body.tactical_status = "STATUS_GUARDING" if defend else ["STATUS_NORTH", "STATUS_CENTER", "STATUS_SOUTH"][route_id]
		if defend:
			var facing: float = 1.0 if team.base_position.x < game.MAP_SIZE.x * 0.5 else -1.0
			var destination: Vector2 = team.base_position + Vector2(facing * 650, sin(game.match_seconds * 0.04 + actor.commander_id) * 380)
			if body.position.distance_to(destination) > 40.0:
				body.travel_toward(destination, delta)
			route = PackedVector2Array()
		else:
			if route.is_empty():
				route = game.navigation.army_route(route_id, team.base_position.x > game.MAP_SIZE.x * 0.5)
				route_index = 1
			while route_index < route.size() - 1 and body.position.distance_to(route[route_index]) < 65:
				route_index += 1
				# March with the army instead of outrunning it at full commander speed.
			var normal_speed: float = body.move_speed
			body.move_speed = minf(normal_speed, 100.0)
			body.travel_toward(route[route_index], delta)
			body.move_speed = normal_speed

func reset_orders() -> void:
	target = null
	base_threat = null
	route.clear()
	build_goal = null
	scan_timer = 0.0
