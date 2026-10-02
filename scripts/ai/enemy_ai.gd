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
var order: StringName = &"auto"
var planned_purchase: StringName = &""
var reserved_gold: int = 0
var reserved_wood: int = 0
var recovering: bool = false
var ability_timer: float = 0.0
var observed_heavy_id: int = -1
var reaction_remaining: float = -1.0
var tower_id: StringName = &"guard"
var roster: Array[StringName] = [&"tank", &"melee", &"ranged", &"melee", &"ranged"]

func _ready() -> void:
	rng.seed = game.strategy_seed * 97 + actor.commander_id * 13
	roster.clear()
	for role in [&"tank", &"melee", &"ranged", &"melee", &"ranged"]:
		for id in game.unit_data:
			if game.unit_data[id].tactical_role == role:
				roster.append(id)
				break

func step_gameplay(delta: float) -> void:
	if game.tutorial_mode or roster.is_empty():
		return
	if game.match_finished or not actor.alive:
		return
	decision_timer -= delta
	if decision_timer > 0.0:
		return
	decision_timer = game.balance.aggressive_decision_seconds if personality == "aggressive" else game.balance.economic_decision_seconds
	decision_timer += rng.randf_range(-0.7, 0.7)
	decision_count += 1
	planned_purchase = &""
	if game.rules.difficulty == &"easy":
		decision_timer *= 1.65
	elif game.rules.difficulty == &"hard":
		decision_timer *= 0.8
	if is_instance_valid(build_goal) and build_goal.occupied():
		build_goal = null
	var reserve: int = game.balance.ally_money_reserve if personality == "ally" else 20
	var wood_reserve: int = game.balance.ally_wood_reserve if personality == "ally" else 0
	route_id = _deployment_lane()
	if order == &"auto" and personality != "aggressive" and decision_count % 4 == 1 and team.worker_count >= 3 and team.wood >= game.balance.tower_wood + wood_reserve:
		build_goal = _choose_pad()
		if build_goal != null:
			tower_id = _choose_tower()
	if order in [&"north", &"center", &"south"]:
		route_id = [&"north", &"center", &"south"].find(order)
	reserved_gold = _tower_money() if build_goal != null else 0
	reserved_wood = _tower_wood() if build_goal != null else 0
	if build_goal != null and not team.can_afford(reserved_gold, reserved_wood):
		build_goal = null
		reserved_gold = 0
		reserved_wood = 0
	# Both controllers respect one teammate's announced construction budget.
	var construction_pending: bool = false
	var construction_budget: int = 0
	for commander in game.commanders:
		if commander != actor and commander.team == team and commander.controller.get("build_goal") != null:
			construction_pending = true
			construction_budget = maxi(construction_budget, int(commander.controller.get("reserved_gold")))
	if construction_pending:
		reserve += construction_budget
	if team.money < reserve + 50:
		return
	if _has_gatherable_wood() and team.worker_count < (5 if personality == "economic" else 4) and (personality != "aggressive" or team.worker_count < 2):
		_recruit(&"worker")
	elif build_goal != null and team.can_afford(_tower_money() + reserve, _tower_wood() + wood_reserve) and game.nearest_pad(actor) == build_goal:
		game.build_tower(actor, build_goal, tower_id)
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
				_recruit(id)
	if decision_count % 4 == 0:
		# Grow the field economy before repeatedly fortifying an untouched King.
		var order: Array = [7, 5, 6, 4, 7, 0, 1, 2, 3]
		var definition: UpgradeDefinition = game.upgrades[order[(decision_count / 4 - 1) % order.size()]]
		var level: int = team.upgrade_level(definition.id)
		var fortification_needed: bool = definition.category != "king" or level < 2
		if fortification_needed and team.wood >= definition.cost(level) + wood_reserve + game.balance.tower_wood:
			game.session.execute(MatchCommand.new(MatchCommand.Action.UPGRADE, actor.commander_id, {"id": definition.id}))

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
	if game.tutorial_mode:
		return
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 0.45
		target = body.closest_enemy(340.0)
		base_threat = null
		if is_instance_valid(team.king):
			base_threat = team.king.closest_enemy(600.0)
	if game.rules.difficulty != &"easy" and body.alive and body.rally_cooldown <= 0.0:
		var friends := 0
		for unit in game.session.actors_in_order:
			if unit.alive and unit.category == &"army" and unit.team == team and unit.position.distance_to(body.position) <= 300.0:
				friends += 1
		if friends >= 4 and (body.valid_enemy(target) or (game.rules.difficulty == &"hard" and friends >= 6)):
			game.session.execute(MatchCommand.new(MatchCommand.Action.RALLY, actor.commander_id))
	ability_timer = maxf(0.0, ability_timer - delta)
	if reaction_remaining > 0.0:
		reaction_remaining = maxf(0.0, reaction_remaining - delta)
	if body.health < body.max_health * 0.3:
		recovering = true
	if recovering and body.health >= body.max_health:
		recovering = false
	if recovering:
		body.tactical_status = "STATUS_RESUPPLY"
		route.clear()
		if body.position.distance_to(team.base_position) >= maxf(1.0, game.balance.base_heal_radius - 10.0):
			_intent({"goal": team.base_position + Vector2(0, minf(110.0, game.balance.base_heal_radius * 0.5))}, delta)
		elif body.heal_cooldown <= 0.0:
			_intent({"interact": true}, delta)
	elif body.valid_enemy(target):
		body.tactical_status = "STATUS_ENGAGING"
		_use_combat_ability(body)
		if body.edge_distance(target) <= body.attack_range:
			_intent({"attack": true, "target": target}, delta)
		else:
			_intent({"goal": target.global_position}, delta)
	elif body.valid_enemy(base_threat):
		body.tactical_status = "STATUS_DEFENDING"
		_intent({"goal": base_threat.position}, delta)
	elif order in [&"defend", &"escort"]:
		var anchor: Vector2 = team.base_position + Vector2(100.0 if team.team_id == 1 else -100.0, -100.0)
		if order == &"escort" and game.player.alive:
			anchor = game.player.position + Vector2(-70.0, -55.0)
		body.tactical_status = "STATUS_DEFENDING" if order == &"defend" or not game.player.alive else "STATUS_ESCORTING"
		if body.position.distance_to(anchor) > 65.0:
			_intent({"goal": anchor}, delta)
	elif is_instance_valid(build_goal) and not build_goal.occupied():
		body.tactical_status = "STATUS_BUILDING"
		_intent({"goal": build_goal.position}, delta)
		var reserve: int = game.balance.ally_money_reserve if personality == "ally" else 0
		var wood_reserve: int = game.balance.ally_wood_reserve if personality == "ally" else 0
		if team.can_afford(_tower_money() + reserve, _tower_wood() + wood_reserve) and game.build_tower(actor, build_goal, tower_id):
			build_goal = null
	else:
		var defend: bool = order == &"auto" and personality != "aggressive" and fmod(game.match_seconds + actor.commander_id * 7.0, 100.0) < 52.0
		body.tactical_status = "STATUS_GUARDING" if defend else ["STATUS_NORTH", "STATUS_CENTER", "STATUS_SOUTH"][route_id]
		if defend:
			var facing: float = 1.0 if team.base_position.x < game.MAP_SIZE.x * 0.5 else -1.0
			var destination: Vector2 = team.base_position + Vector2(facing * 650, sin(game.match_seconds * 0.04 + actor.commander_id) * 380)
			if body.position.distance_to(destination) > 40.0:
				_intent({"goal": destination}, delta)
			route = PackedVector2Array()
		else:
			if route.is_empty():
				route = game.navigation.army_route(route_id, team.base_position.x > game.MAP_SIZE.x * 0.5)
				route_index = 1
			while route_index < route.size() - 1 and body.position.distance_to(route[route_index]) < 65:
				route_index += 1
				# March with the army instead of outrunning it at full commander speed.
			_intent({"goal": route[route_index], "speed_limit": 100.0}, delta)

func reset_orders() -> void:
	recovering = false
	ability_timer = 0.0
	observed_heavy_id = -1
	reaction_remaining = -1.0
	target = null
	base_threat = null
	route.clear()
	build_goal = null
	reserved_gold = 0
	reserved_wood = 0
	planned_purchase = &""
	scan_timer = 0.0

func set_order(value: StringName) -> void:
	order = value
	route.clear()
	build_goal = null
	reserved_gold = 0
	reserved_wood = 0
	planned_purchase = &""
	decision_timer = minf(decision_timer, 0.1)
	if order in [&"north", &"center", &"south"]:
		route_id = [&"north", &"center", &"south"].find(order)

func _recruit(id: StringName) -> bool:
	planned_purchase = id
	if id != &"worker":
		route_id = _deployment_lane()
	return game.session.execute(MatchCommand.new(MatchCommand.Action.RECRUIT, actor.commander_id, {"id": id, "route": route_id})).success

func _intent(payload: Dictionary, delta: float) -> void:
	payload["delta"] = delta
	game.session.execute(MatchCommand.new(MatchCommand.Action.INPUT, actor.commander_id, payload))

func _deployment_lane() -> int:
	if order in [&"north", &"center", &"south"]:
		return [&"north", &"center", &"south"].find(order)
	if actor.valid_enemy(base_threat):
		return game.coordination.closest_lane(base_threat.position)
	return game.deployment_policy.choose_lane(team.team_id, rng)

func _use_combat_ability(body) -> void:
	if not body.valid_enemy(target):
		observed_heavy_id = -1
		reaction_remaining = -1.0
		return
	var direction: Vector2 = body.position.direction_to(target.position)
	var visible_heavy: bool = target.category == &"commander" and target.get("action_state") == &"heavy" and body.edge_distance(target) < 140.0 and game.navigation.clear_line(body.position, target.position)
	if visible_heavy:
		if observed_heavy_id != target.match_id:
			observed_heavy_id = target.match_id
			reaction_remaining = rng.randf_range(0.15, 0.30)
			if game.rules.difficulty == &"easy":
				reaction_remaining = rng.randf_range(0.35, 0.55)
			elif game.rules.difficulty == &"hard":
				reaction_remaining = rng.randf_range(0.12, 0.22)
		if reaction_remaining == 0.0 and body.action_state == &"ready" and body.stun_remaining <= 0.0:
			reaction_remaining = -1.0
			var opponent_facing: Vector2 = target.get("facing")
			var incoming: bool = absf(opponent_facing.angle_to(-direction)) <= deg_to_rad(40.0)
			if incoming and float(body.ability_cooldowns.get(&"guard", 0.0)) <= 0.0:
				_request_ability(&"guard", direction)
			elif float(body.ability_cooldowns.get(&"dash", 0.0)) <= 0.0:
				_request_ability(&"dash", direction.orthogonal() * (-1.0 if rng.randf() < 0.5 else 1.0))
		return
	observed_heavy_id = -1
	reaction_remaining = -1.0
	if ability_timer > 0.0 or body.action_state != &"ready" or body.stun_remaining > 0.0:
		return
	ability_timer = 0.35 if game.rules.difficulty == &"hard" else 0.65
	if game.rules.difficulty == &"easy":
		ability_timer = 1.1
	if body.edge_distance(target) <= body.attack_range and rng.randf() < 0.40 and float(body.ability_cooldowns.get(&"heavy", 0.0)) <= 0.0:
		_request_ability(&"heavy", direction)
	elif body.edge_distance(target) > body.attack_range + 110.0 and rng.randf() < 0.25 and float(body.ability_cooldowns.get(&"dash", 0.0)) <= 0.0:
		_request_ability(&"dash", direction)

func _request_ability(id: StringName, direction: Vector2) -> void:
	game.session.execute(MatchCommand.new(MatchCommand.Action.ABILITY, actor.commander_id, {"ability_id": id, "direction": direction}))

func _tower_money() -> int:
	return int(game.tower_data[tower_id].money_cost)

func _tower_wood() -> int:
	return int(game.tower_data[tower_id].wood_cost)

func _choose_tower() -> StringName:
	var nearby_enemies: int = 0
	for unit in game.entities.get_children():
		if unit is CombatEntity and actor.valid_enemy(unit) and unit.position.distance_to(actor.position) <= 340.0 and game.navigation.clear_line(actor.position, unit.position):
			nearby_enemies += 1
	var preferred: StringName = &"splash" if nearby_enemies >= 3 else &"long_range" if personality == "economic" else &"guard"
	if game.tower_data.has(preferred):
		var definition = game.tower_data[preferred]
		if team.can_afford(definition.money_cost, definition.wood_cost):
			return preferred
	return &"guard"

func _has_gatherable_wood() -> bool:
	for tree in game.get_node("Trees").get_children():
		if tree.wood_remaining > 0:
			return true
	return false
