extends SceneTree
## Real 60 Hz scene-tree match with compact strategic snapshots.
const LIMIT_SECONDS := 1800.0
var game
var replay_ids: Dictionary = {}
var next_replay_id := 1

func _entity_id(entity) -> int:
	var key: int = entity.get_instance_id()
	if not replay_ids.has(key):
		replay_ids[key] = next_replay_id
		next_replay_id += 1
	return replay_ids[key]

func _map_data() -> Dictionary:
	var lanes: Array = []
	for lane in game.navigation.lanes:
		var points: Array = []
		for point in lane:
			points.append([point.x, point.y])
		lanes.append(points)
	var obstacles: Array = []
	for box in game.navigation.OBSTACLES:
		obstacles.append([box.position.x, box.position.y, box.size.x, box.size.y])
	var trees: Array = []
	for tree in get_nodes_in_group("trees"):
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
	for entity in get_nodes_in_group("combatants"):
		if is_instance_valid(entity) and entity.alive and entity.kind in [&"king", &"worker", &"melee", &"ranged", &"tank", &"tower", &"player"]:
			entities.append([entity.team.team_id, String(entity.kind), roundi(entity.position.x), roundi(entity.position.y), roundi(entity.health), _entity_id(entity), roundi(entity.max_health), entity.commander_id if entity.kind == &"player" else 0, entity.route_id if entity.kind in [&"melee", &"ranged", &"tank"] else -1])
			if entity.kind == &"tower":
				tower_counts[entity.team.team_id] += 1
	for team in teams:
		team["towers"] = tower_counts[team["id"]]
	return {"t": game.match_seconds, "teams": teams, "entities": entities}

func _effective_config() -> Dictionary:
	var result := {"version": 1, "requested": game.simulation_config.duplicate(true), "worker_cost": game.worker_cost, "teams": {}, "units": {}, "upgrades": {}, "balance": {}}
	for team in game.teams:
		result["teams"][str(team.team_id)] = {"money": team.money, "wood": team.wood, "workers": team.worker_count, "base_stats": team.base_stats.duplicate(true)}
	for id in game.unit_data:
		var unit = game.unit_data[id]
		result["units"][String(id)] = {"money_cost": unit.money_cost, "max_health": unit.max_health, "damage": unit.damage, "move_speed": unit.move_speed, "attack_range": unit.attack_range, "attack_cooldown": unit.attack_cooldown, "detection_range": unit.detection_range, "body_radius": unit.body_radius, "structure_damage_multiplier": unit.structure_damage_multiplier}
	for upgrade in game.upgrades:
		result["upgrades"][String(upgrade.id)] = {"base_cost": upgrade.base_cost, "cost_growth": upgrade.cost_growth, "amount": upgrade.amount, "maximum_level": upgrade.maximum_level}
	for field in ["tower_money", "tower_wood", "tower_health", "tower_damage", "tower_range", "tower_cooldown", "tower_rebuild_delay", "build_reach", "ally_money_reserve", "ally_wood_reserve", "aggressive_decision_seconds", "economic_decision_seconds", "commander_health", "commander_strike_windup", "commander_respawn", "base_heal_cooldown"]:
		result["balance"][field] = game.balance.get(field)
	return result

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 42
	var limit_seconds := float(args[2]) if args.size() > 2 else LIMIT_SECONDS
	var config: Dictionary = {}
	if args.size() > 1:
		var parsed: Variant = JSON.parse_string(args[1])
		if parsed is Dictionary:
			config = parsed
	game = load("res://scenes/main/main.tscn").instantiate()
	game.strategy_seed = seed
	game.simulation_config = config
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
	var peak_army := 0
	var peak_armies := {"1": 0, "2": 0}
	var snapshots: Array = [_snapshot()]
	var events: Array = []
	var deaths := {"1": 0, "2": 0}
	var seen: Dictionary = {}
	var towers := {"1": 0, "2": 0}
	var last_upgrades := {"1": {}, "2": {}}
	var last_sample := 0
	var last_progress := -1
	var started := Time.get_ticks_msec()
	while game.match_seconds < limit_seconds and not game.match_finished:
		await process_frame
		var progress_bucket := int(game.match_seconds / 30.0)
		if progress_bucket > last_progress:
			last_progress = progress_bucket
			print("LAB_MATCH_PROGRESS ", JSON.stringify({"seed": seed, "seconds": roundi(game.match_seconds), "king_health": [roundi(game.teams[0].king.health), roundi(game.teams[1].king.health)], "army": [game.teams[0].combat_count, game.teams[1].combat_count]}))
		for team in game.teams:
			peak_army = maxi(peak_army, team.combat_count)
			peak_armies[str(team.team_id)] = maxi(peak_armies[str(team.team_id)], team.combat_count)
			for id in team.upgrade_levels:
				var old_level: int = int(last_upgrades[str(team.team_id)].get(id, 0))
				var level: int = int(team.upgrade_levels[id])
				if level > old_level:
					last_upgrades[str(team.team_id)][id] = level
					events.append({"t": game.match_seconds, "type": "upgrade", "team": team.team_id, "id": String(id), "level": level})
			if first_damage < 0 and is_instance_valid(team.king) and team.king.health < team.king.max_health:
				first_damage = game.match_seconds
				events.append({"t": game.match_seconds, "type": "first_king_damage", "team": team.team_id, "position": [team.king.position.x, team.king.position.y]})
		for entity in get_nodes_in_group("combatants"):
			if not is_instance_valid(entity):
				continue
			var key := entity.get_instance_id()
			if not seen.has(key):
				seen[key] = entity.alive
				_entity_id(entity)
				entity.died.connect(func(dead):
					deaths[str(dead.team.team_id)] += 1
					events.append({"t": game.match_seconds, "type": "death", "team": dead.team.team_id, "kind": String(dead.kind), "entity_id": _entity_id(dead), "position": [dead.position.x, dead.position.y], "commander_id": dead.commander_id if dead.kind == &"player" else 0})
				)
				if entity.kind == &"tower":
					towers[str(entity.team.team_id)] += 1
					events.append({"t": game.match_seconds, "type": "tower_built", "team": entity.team.team_id, "entity_id": _entity_id(entity), "position": [entity.position.x, entity.position.y]})
			if entity.kind == &"player" and entity.alive and not seen[key]:
				events.append({"t": game.match_seconds, "type": "commander_return", "team": entity.team.team_id, "commander_id": entity.commander_id, "entity_id": _entity_id(entity), "position": [entity.position.x, entity.position.y]})
			seen[key] = entity.alive
		var second := int(game.match_seconds)
		if second > last_sample:
			last_sample = second
			snapshots.append(_snapshot())
	var outcome := "win" if game.match_finished else "timeout"
	if game.match_finished:
		events.append({"t": game.match_seconds, "type": "match_end", "team": game.winning_team_id})
	snapshots.append(_snapshot())
	var report := {"replay_version": 2, "map": replay_map, "sample_seconds": 1, "seed": seed, "effective_config": effective_config, "duration": game.match_seconds, "outcome": outcome, "finished": game.match_finished, "winning_team_id": game.winning_team_id, "first_king_damage": first_damage, "max_army_per_team": peak_army, "peak_armies": peak_armies, "towers_built": towers, "deaths": deaths, "timeline": snapshots, "events": events, "wall_seconds": (Time.get_ticks_msec() - started) / 1000.0, "failures": 0}
	print("LAB_MATCH_REPORT ", JSON.stringify(report))
	paused = false
	game.free()
	root.get_node("AudioFeedback").stop_all()
	quit()
