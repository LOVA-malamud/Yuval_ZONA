extends SceneTree
## Real 60 Hz scene-tree match with compact strategic snapshots.
const LIMIT_SECONDS := 1800.0
var game
var replay_ids: Dictionary = {}
var next_replay_id := 1
var encounters: Dictionary = {}
var encounter_durations: Array = []
var encounter_escapes: int = 0

func _entity_id(entity) -> int:
	return entity.match_id

func _map_data() -> Dictionary:
	var lanes: Array = []
	for lane in game.navigation.lanes:
		var points: Array = []
		for point in lane:
			points.append([point.x, point.y])
		lanes.append(points)
	var obstacles: Array = []
	for box in game.navigation.obstacles:
		obstacles.append([box.position.x, box.position.y, box.size.x, box.size.y])
	var trees: Array = []
	for tree in game.get_node("Trees").get_children():
		trees.append([tree.position.x, tree.position.y])
	var pads: Array = []
	for pad in game.pads:
		pads.append([pad.position.x, pad.position.y])
	return {"size": [game.MAP_SIZE.x, game.MAP_SIZE.y], "lanes": lanes, "obstacles": obstacles, "trees": trees, "pads": pads}

func _initialize() -> void:
	_run.call_deferred()

func _snapshot() -> Dictionary:
	var teams: Array = []
	for team in game.teams:
		teams.append({"id": team.team_id, "money": team.money, "wood": team.wood, "workers": team.worker_count, "army": team.combat_count, "king_health": team.king.health if is_instance_valid(team.king) else 0, "king_max_health": team.king.max_health if is_instance_valid(team.king) else 0, "upgrades": team.upgrade_levels.duplicate(true)})
	var entities: Array = []
	# Entity tuples: team, kind, x, y, health, replay ID, max health, commander ID, route.
	var tower_counts := {1: 0, 2: 0}
	var tower_types := {}
	var commander_states := {}
	var trees: Array = []
	var wood_remaining: int = 0
	for tree in game.get_node("Trees").get_children():
		trees.append([tree.position.x, tree.position.y, tree.wood_remaining, tree.initial_wood, String(tree.zone)])
		wood_remaining += tree.wood_remaining
	for entity in game.session.actors.values():
		if is_instance_valid(entity) and entity.alive:
			entities.append([entity.team.team_id, String(entity.kind), roundi(entity.position.x), roundi(entity.position.y), roundi(entity.health), _entity_id(entity), roundi(entity.max_health), entity.commander_id if entity.category == &"commander" else 0, entity.route_id if entity.category == &"army" else -1])
			if entity.kind == &"tower":
				tower_counts[entity.team.team_id] += 1
				tower_types[str(entity.match_id)] = String(entity.tower_id())
			if entity.category == &"commander":
				commander_states[str(entity.match_id)] = {"action": String(entity.action_state), "healing": entity.healing, "stun": entity.stun_remaining, "cooldowns": entity.ability_cooldowns.duplicate()}
	for team in teams:
		team["towers"] = tower_counts[team["id"]]
	return {"t": game.match_seconds, "teams": teams, "entities": entities, "coordination": game.coordination.snapshot(), "tower_types": tower_types, "commander_states": commander_states, "trees": trees, "wood_remaining": wood_remaining, "deployment": {"1": game.deployment_policy.counts(1), "2": game.deployment_policy.counts(2)}}

func _definitions() -> Dictionary:
	var result := {}
	for id in game.unit_data:
		var definition: UnitStats = game.unit_data[id]
		result[String(id)] = {"category": "army", "role": String(definition.tactical_role), "label": tr(definition.display_name)}
	for id in ["king", "tower", "worker", "player"]:
		result[id] = {"category": "structure" if id in ["king", "tower"] else "worker" if id == "worker" else "commander", "role": id, "label": id.capitalize()}
	return result

func _effective_config() -> Dictionary:
	var result := {"version": 1, "requested": game.simulation_config.duplicate(true), "worker_cost": game.worker_cost, "teams": {}, "units": {}, "upgrades": {}, "balance": {}, "rules": {"rally_wait_seconds": game.rules.rally_wait_seconds, "army_speed_multiplier": game.rules.army_speed_multiplier, "difficulty": String(game.rules.difficulty)}}
	for team in game.teams:
		result["teams"][str(team.team_id)] = {"money": team.money, "wood": team.wood, "workers": team.worker_count, "base_stats": team.base_stats.duplicate(true)}
	for id in game.unit_data:
		var unit = game.unit_data[id]
		result["units"][String(id)] = {"money_cost": unit.money_cost, "max_health": unit.max_health, "damage": unit.damage, "move_speed": unit.move_speed, "attack_range": unit.attack_range, "attack_cooldown": unit.attack_cooldown, "detection_range": unit.detection_range, "body_radius": unit.body_radius, "structure_damage_multiplier": unit.structure_damage_multiplier}
	for upgrade in game.upgrades:
		result["upgrades"][String(upgrade.id)] = {"base_cost": upgrade.base_cost, "cost_growth": upgrade.cost_growth, "amount": upgrade.amount, "maximum_level": upgrade.maximum_level}
	for field in ["tower_money", "tower_wood", "tower_health", "tower_damage", "tower_range", "tower_cooldown", "tower_rebuild_delay", "build_reach", "ally_money_reserve", "ally_wood_reserve", "aggressive_decision_seconds", "economic_decision_seconds", "commander_health", "commander_strike_windup", "commander_respawn", "base_heal_cooldown"]:
		result["balance"][field] = game.balance.get(field)
	for property in game.balance.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
			result["balance"][property.name] = game.balance.get(property.name)
	result["deployment"] = {"window_size": game.deployment_policy.window_size, "tolerance": game.deployment_policy.tolerance}
	result["towers"] = {}
	for id in game.tower_data:
		var definition = game.tower_data[id]
		var values := {}
		for field in ["money_cost", "wood_cost", "max_health", "damage", "attack_cooldown", "attack_range", "minimum_range", "splash_radius"]:
			values[field] = definition.get(field)
		result["towers"][String(id)] = values
	result["groves"] = []
	for tree in game.get_node("Trees").get_children():
		result["groves"].append({"position": [tree.position.x, tree.position.y], "wood": tree.initial_wood, "zone": String(tree.zone)})
	return result

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 42
	var limit_seconds := float(args[2]) if args.size() > 2 else LIMIT_SECONDS
	var sample_seconds := int(args[3]) if args.size() > 3 and args[3].is_valid_int() else 1
	var config: Dictionary = {}
	if args.size() > 1:
		var parsed: Variant = JSON.parse_string(args[1])
		if parsed is Dictionary:
			config = parsed
	game = load("res://scenes/main/main.tscn").instantiate()
	game.strategy_seed = seed
	game.simulation_config = config
	game.presentation_enabled = "--watch" in args
	game.process_mode = Node.PROCESS_MODE_INHERIT if game.presentation_enabled else Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	game.player.controller.free()
	var controller = game.AI_CONTROLLER.new()
	controller.game = game
	controller.team = game.player.team
	controller.actor = game.player
	controller.personality = "aggressive"
	game.player.human_controlled = false
	game.player.controller = controller
	game.player.add_child(controller)
	var effective_config := _effective_config()
	var replay_map := _map_data()
	var first_damage := -1.0
	encounters.clear()
	encounter_durations.clear()
	encounter_escapes = 0
	var peak_army := 0
	var peak_armies := {"1": 0, "2": 0}
	var snapshots: Array = [_snapshot()]
	var events: Array = []
	game.session.match_event.connect(func(event): events.append(event))
	var deaths := {"1": 0, "2": 0}
	var seen: Dictionary = {}
	var towers := {"1": 0, "2": 0}
	var last_upgrades := {"1": {}, "2": {}}
	var last_sample := 0
	var inspected_tick := -1
	var last_progress := -1
	var started := Time.get_ticks_msec()
	while game.match_seconds < limit_seconds and not game.match_finished:
		if game.presentation_enabled:
			await process_frame
		else:
			game.session.step()
			# Queued nodes are unavailable immediately and are freed by the engine.
			# Yield regularly without advancing automatic gameplay callbacks.
			if game.session.ticks % 60 == 0:
				await process_frame
		var progress_bucket := int(game.match_seconds / 30.0)
		if progress_bucket > last_progress:
			last_progress = progress_bucket
			print("LAB_MATCH_PROGRESS ", JSON.stringify({"seed": seed, "seconds": roundi(game.match_seconds), "king_health": [roundi(game.teams[0].king.health), roundi(game.teams[1].king.health)], "army": [game.teams[0].combat_count, game.teams[1].combat_count]}))
		if game.session.ticks == inspected_tick:
			continue
		inspected_tick = game.session.ticks
		_measure_encounters(events)
		for team in game.teams:
			peak_army = maxi(peak_army, team.combat_count)
			peak_armies[str(team.team_id)] = maxi(peak_armies[str(team.team_id)], team.combat_count)
			if first_damage < 0 and is_instance_valid(team.king) and team.king.health < team.king.max_health:
				first_damage = game.match_seconds
				events.append({"t": game.match_seconds, "type": "first_king_damage", "team": team.team_id, "position": [team.king.position.x, team.king.position.y]})
		var second := int(game.match_seconds / sample_seconds)
		if second > last_sample:
			last_sample = second
			snapshots.append(_snapshot())
	var outcome := "win" if game.match_finished else "timeout"
	for event in events:
		if event.type == "death":
			deaths[str(event.team)] += 1
		elif event.type == "tower_built":
			towers[str(event.team)] += 1
	snapshots.append(_snapshot())
	var report := {"replay_version": 4, "map": replay_map, "sample_seconds": sample_seconds, "seed": seed, "effective_config": effective_config, "duration": game.match_seconds, "outcome": outcome, "finished": game.match_finished, "winning_team_id": game.winning_team_id, "first_king_damage": first_damage, "max_army_per_team": peak_army, "peak_armies": peak_armies, "towers_built": towers, "deaths": deaths, "timeline": snapshots, "events": events, "wall_seconds": (Time.get_ticks_msec() - started) / 1000.0, "entity_definitions": _definitions(), "recap": game.coordination.snapshot(), "ticks": game.session.ticks}
	report["metrics"] = _metrics(events, snapshots)
	print("LAB_MATCH_REPORT ", JSON.stringify(report))
	paused = false
	game.free()
	root.get_node("AudioFeedback").stop_all()
	await process_frame
	quit()

func _metrics(events: Array, snapshots: Array) -> Dictionary:
	var totals := {}
	var abilities := {}
	var guarded_heavy: int = 0
	for event in events:
		totals[event.type] = int(totals.get(event.type, 0)) + 1
		if event.type == "heavy_hit" and bool(event.get("guarded", false)):
			guarded_heavy += 1
		if event.type == "ability":
			var id: String = event.get("ability_id", "unknown")
			abilities[id] = int(abilities.get(id, 0)) + 1
	return {"event_counts": totals, "ability_uses": abilities, "heavy_hits": totals.get("heavy_hit", 0), "heavy_guarded": guarded_heavy, "heavy_unguarded": int(totals.get("heavy_hit", 0)) - guarded_heavy, "healing_interruptions": totals.get("healing_interrupt", 0), "depleted_trees": totals.get("tree_depleted", 0), "wood_initial": snapshots[0].wood_remaining, "wood_remaining": snapshots[-1].wood_remaining, "final_deployment": snapshots[-1].deployment, "commander_encounter_durations": encounter_durations, "commander_escapes": encounter_escapes}

func _measure_encounters(events: Array) -> void:
	for first_index in range(game.commanders.size()):
		var first = game.commanders[first_index]
		for second_index in range(first_index + 1, game.commanders.size()):
			var second = game.commanders[second_index]
			if first.team == second.team:
				continue
			var key: String = str(first.commander_id) + ":" + str(second.commander_id)
			var distance: float = first.position.distance_to(second.position)
			if not encounters.has(key):
				if first.alive and second.alive and distance <= 175.0 and game.navigation.clear_line(first.position, second.position):
					encounters[key] = game.match_seconds
			elif not first.alive or not second.alive or distance > 340.0:
				var elapsed: float = game.match_seconds - float(encounters[key])
				encounter_durations.append(elapsed)
				var escaped: bool = first.alive and second.alive
				if escaped:
					encounter_escapes += 1
				events.append({"type": "commander_encounter_end", "t": game.match_seconds, "commanders": [first.commander_id, second.commander_id], "duration": elapsed, "escaped": escaped})
				encounters.erase(key)
