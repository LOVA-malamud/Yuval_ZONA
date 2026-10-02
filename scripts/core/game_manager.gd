extends Node2D
## Composition root and command boundary. Controllers never spawn entities directly.

signal match_ended(winning_team_id: int)

const KING_SCENE = preload("res://scenes/king/king.tscn")
const UNIT_SCENE = preload("res://scenes/units/combat_unit.tscn")
const WORKER_SCENE = preload("res://scenes/workers/worker.tscn")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const TREE_SCENE = preload("res://scenes/environment/tree_resource.tscn")
const WORKER_COST: int = 65
var MAP_SIZE := Vector2(4600, 2600)

@export var catalog: ContentCatalog = preload("res://resources/content_catalog.tres")
@export var map_definition: MapDefinition = preload("res://resources/default_map.tres")
@export var rules: MatchRules = preload("res://resources/default_rules.tres")
var unit_data: Dictionary = {}
var upgrades: Array[UpgradeDefinition] = []
@export var strategy_seed: int = 42
var teams: Array[GameTeam] = []
var player = null
var commanders: Array = []
const HUMAN_CONTROLLER = preload("res://scripts/player/human_controller.gd")
const AI_CONTROLLER = preload("res://scripts/ai/enemy_ai.gd")
@export var presentation_enabled: bool = true
@export var pause_on_focus_loss: bool = true
var session: MatchSession
var coordination: CoordinationService
@export var force_touch_controls: bool = false
var safe_area_override := Rect2()
@export var tutorial_mode: bool = false
var tutorial: TutorialDirector
var match_finished: bool = false
var winning_team_id: int = 0
var match_seconds: float = 0.0
var spawn_sequence: int = 0
const PAD_SCRIPT = preload("res://scripts/structures/build_pad.gd")
const TOWER_SCRIPT = preload("res://scripts/structures/defense_tower.gd")
var balance = preload("res://resources/battle_balance.tres")
var simulation_config: Dictionary = {}
var worker_cost: int = WORKER_COST
var pads: Array = []
var navigation: RouteMap
var selected_route: int = 1
var route_highlight: float = 0.0
var spatial: Dictionary = {}
const EFFECT_SCRIPT = preload("res://scripts/visuals/battle_effect.gd")
const PROJECTILE_SCRIPT = preload("res://scripts/units/combat_projectile.gd")
const MAX_EFFECTS: int = 48
var effect_count: int = 0

@onready var entities: Node2D = $Entities
@onready var hud = $HUD

func _team_config(id: int) -> Dictionary:
	var result: Dictionary = simulation_config.get("shared", {}).get("team", {}).duplicate(true)
	result.merge(simulation_config.get("teams", {}).get(str(id), {}), true)
	if simulation_config.get("shared", {}).get("base_stats", {}) is Dictionary:
		var stats: Dictionary = simulation_config.get("shared", {}).get("base_stats", {}).duplicate(true)
		stats.merge(result.get("base_stats", {}), true)
		result["base_stats"] = stats
	return result

func _apply_simulation_config() -> void:
	unit_data = catalog.unit_definitions()
	upgrades = catalog.upgrades
	rules = rules.duplicate(true)
	rules.difficulty = StringName(simulation_config.get("shared", {}).get("difficulty", GameSettings.difficulty))
	for field in simulation_config.get("shared", {}).get("rules", {}):
		rules.set(field, simulation_config["shared"]["rules"][field])
	map_definition = map_definition.duplicate(true)
	MAP_SIZE = map_definition.bounds
	navigation = RouteMap.new(map_definition)
	# The scene stores preloaded resources; each match owns its mutable copies.
	balance = balance.duplicate(true)
	for field in simulation_config.get("shared", {}).get("balance", {}):
		balance.set(field, simulation_config["shared"]["balance"][field])
	var copied_units: Dictionary = {}
	for id in unit_data:
		copied_units[id] = unit_data[id].duplicate(true)
		for field in simulation_config.get("shared", {}).get("units", {}).get(String(id), {}):
			copied_units[id].set(field, simulation_config["shared"]["units"][String(id)][field])
	unit_data = copied_units
	var copied_upgrades: Array[UpgradeDefinition] = []
	for definition in upgrades:
		var copy: UpgradeDefinition = definition.duplicate(true)
		for field in simulation_config.get("shared", {}).get("upgrades", {}).get(String(copy.id), {}):
			copy.set(field, simulation_config["shared"]["upgrades"][String(copy.id)][field])
		copied_upgrades.append(copy)
	upgrades = copied_upgrades
	worker_cost = int(simulation_config.get("shared", {}).get("worker_cost", rules.worker_cost))


func _ready() -> void:
	if catalog == null or map_definition == null or rules == null:
		push_error("Match is missing catalog, map or rules")
		queue_free()
		return
	var definition_errors := catalog.validation_errors()
	definition_errors.append_array(map_definition.validation_errors())
	definition_errors.append_array(rules.validation_errors())
	if not definition_errors.is_empty():
		push_error("Invalid match definitions: " + "; ".join(definition_errors))
		queue_free()
		return
	_apply_simulation_config()
	session = MatchSession.new()
	add_child(session)
	session.start(self)
	if not presentation_enabled:
		$Battlefield.free()
		hud.free()
		hud = null
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Crownfront")
	get_tree().paused = false
	_create_team(1, "TEAM_AZURE", Color(0.30, 0.76, 1.0), map_definition.bases[0], 1.0)
	_create_team(2, "TEAM_EMBER", Color(1.0, 0.40, 0.35), map_definition.bases[1], -1.0)
	_create_trees()
	_create_pads()
	for team in teams:
		_create_king(team)
		for index in range(int(_team_config(team.team_id).get("workers", rules.starting_workers))):
			_spawn_worker(team)
	_create_commander(teams[0], 1, "COMMANDER_YOU", "human", Vector2(-25, 110))
	_create_commander(teams[0], 2, "COMMANDER_WARDEN", "ally", Vector2(50, -110))
	_create_commander(teams[1], 3, "COMMANDER_VANGUARD", "aggressive", Vector2(-50, 110))
	_create_commander(teams[1], 4, "COMMANDER_STEWARD", "economic", Vector2(25, -110))
	coordination = CoordinationService.new()
	add_child(coordination)
	coordination.setup(self)
	if tutorial_mode:
		tutorial = TutorialDirector.new()
		add_child(tutorial)
		tutorial.setup(self)
	$EconomyManager.teams = teams
	if presentation_enabled:
		hud.setup(self, teams[0])
		player.base_interacted.connect(hud.show_king_tab)
		match_ended.connect(hud.show_result)


func _create_commander(team: GameTeam, id: int, title: String, role: String, offset: Vector2) -> void:
	var commander = PLAYER_SCENE.instantiate()
	commander.configure(team, self)
	commander.commander_id = id
	commander.commander_name = title
	commander.human_controlled = role == "human"
	commander.spawn_position = team.base_position + offset
	commander.position = commander.spawn_position
	var controller = HUMAN_CONTROLLER.new() if role == "human" else AI_CONTROLLER.new()
	if role != "human":
		controller.game = self
		controller.team = team
		controller.actor = commander
		controller.personality = role
		controller.decision_timer = 8.0 + id * 2.0
	commander.controller = controller
	commander.add_child(controller)
	entities.add_child(commander)
	commanders.append(commander)
	if role == "human":
		player = commander


func _physics_process(_delta: float) -> void:
	session.step()

func _exit_tree() -> void:
	if session != null:
		session.stop()

func play_sound(cue: StringName, point: Vector2 = Vector2.INF) -> void:
	if presentation_enabled:
		AudioFeedback.play(cue, point)


func _create_team(id: int, title: String, tint: Color, base: Vector2, direction: float) -> void:
	var team := GameTeam.new()
	var settings: Dictionary = _team_config(id)
	team.money = int(settings.get("money", rules.starting_gold))
	team.wood = int(settings.get("wood", rules.starting_wood))
	for stat in settings.get("base_stats", {}):
		team.base_stats[StringName(stat)] = float(settings["base_stats"][stat])
	team.stats = team.base_stats.duplicate()
	team.team_id = id
	team.display_name = title
	team.color = tint
	team.base_position = base
	team.spawn_position = base + Vector2(direction * 110.0, 0)
	add_child(team)
	teams.append(team)


func _create_king(team: GameTeam) -> void:
	var king = KING_SCENE.instantiate()
	king.configure(team, self)
	king.position = team.base_position
	team.king = king
	king.died.connect(_on_king_died)
	entities.add_child(king)


func _create_trees() -> void:
	for mirrored in [false, true]:
		for grove in map_definition.groves:
			for index in range(4):
				var tree = TREE_SCENE.instantiate()
				var point: Vector2 = grove + Vector2(index % 2 * 90, index / 2 * 90)
				tree.position = Vector2(MAP_SIZE.x - point.x if mirrored else point.x, point.y)
				tree.renewable = grove.x > 1000
				tree.wood_remaining = 140
				$Trees.add_child(tree)


func team_by_id(id: int) -> GameTeam:
	for team in teams:
		if team.team_id == id:
			return team
	return null


func enemy_king(id: int) -> CombatEntity:
	for team in teams:
		if team.team_id != id and is_instance_valid(team.king) and team.king.alive:
			return team.king as CombatEntity
	return null


func clamp_to_map(point: Vector2, margin: float) -> Vector2:
	return point.clamp(Vector2.ONE * margin, MAP_SIZE - Vector2.ONE * margin)


func commander_by_id(id: int):
	for commander in commanders:
		if commander.commander_id == id:
			return commander
	return null

func _requester(team_id: int, feedback: bool) -> int:
	if feedback and player != null and player.team.team_id == team_id:
		return player.commander_id
	for commander in commanders:
		if commander.team.team_id == team_id:
			return commander.commander_id
	return 0

func recruit_availability(team: GameTeam, id: StringName, route_id: int) -> Dictionary:
	var cost: int = worker_cost if id == &"worker" else int(unit_data[id].money_cost) if unit_data.has(id) else 0
	var reason: StringName = &"ok"
	if match_finished or get_tree().paused:
		reason = &"invalid_state"
	elif id != &"worker" and not unit_data.has(id):
		reason = &"invalid_content"
	elif route_id < 0 or route_id >= navigation.lanes.size():
		reason = &"invalid_route"
	elif (id == &"worker" and team.worker_count >= rules.worker_cap) or (id != &"worker" and team.combat_count >= rules.army_cap):
		reason = &"cap"
	elif not team.can_afford(cost):
		reason = &"insufficient_gold"
	return {"allowed": reason == &"ok", "reason": reason, "gold": cost, "wood": 0}

func upgrade_availability(team: GameTeam, id: StringName) -> Dictionary:
	for definition in upgrades:
		if definition.id == id:
			var level: int = team.upgrade_level(id)
			var cost: int = definition.cost(level)
			var reason: StringName = &"ok"
			if match_finished or get_tree().paused:
				reason = &"invalid_state"
			elif level >= definition.maximum_level:
				reason = &"cap"
			elif not team.can_afford(0, cost):
				reason = &"insufficient_wood"
			return {"allowed": reason == &"ok", "reason": reason, "gold": 0, "wood": cost}
	return {"allowed": false, "reason": &"invalid_content", "gold": 0, "wood": 0}

func purchase(team_id: int, id: StringName, feedback: bool = true, route_id: int = -1) -> bool:
	var command := MatchCommand.new(MatchCommand.Action.RECRUIT, _requester(team_id, feedback), {"id": id, "feedback": feedback, "route": selected_route if route_id < 0 else route_id})
	var result := session.execute(command)
	if feedback and not result.success:
		notify("UNIT_CAP" if result.reason == &"cap" else "INSUFFICIENT_GOLD")
	return result.success

func purchase_upgrade(team_id: int, id: StringName, feedback: bool = true) -> bool:
	var result := session.execute(MatchCommand.new(MatchCommand.Action.UPGRADE, _requester(team_id, feedback), {"id": id, "feedback": feedback}))
	if feedback and not result.success:
		notify("INSUFFICIENT_WOOD")
	return result.success

func build_tower(commander, pad) -> bool:
	return session.execute(MatchCommand.new(MatchCommand.Action.BUILD, commander.commander_id, {"pad": pad})).success

func upgrade_tower(commander, pad) -> bool:
	return session.execute(MatchCommand.new(MatchCommand.Action.UPGRADE_TOWER, commander.commander_id, {"pad": pad})).success

func _purchase(team_id: int, id: StringName, feedback: bool = true, route_id: int = -1) -> bool:
	if match_finished or get_tree().paused:
		return false
	var team: GameTeam = team_by_id(team_id)
	if team == null:
		return false
	var is_worker: bool = id == &"worker"
	if not is_worker and not unit_data.has(id):
		return false
	if (
		(is_worker and team.worker_count >= rules.worker_cap)
		or (not is_worker and team.combat_count >= rules.army_cap)
	):
		if feedback:
			notify("UNIT_CAP")
		return false
	var cost: int = worker_cost if is_worker else int(unit_data[id].money_cost)
	var scene: PackedScene = catalog.worker_scene if is_worker else catalog.army_scene
	if scene == null or not scene.can_instantiate():
		return false
	var recruit = scene.instantiate()
	if not recruit is CombatEntity or not recruit.has_method("step_gameplay"):
		recruit.free()
		return false
	if not team.spend(cost):
		recruit.free()
		return false
	if is_worker:
		recruit.configure(team, self)
		recruit.position = _spawn_point(team) + Vector2(0, 65)
		team.worker_count += 1
	else:
		recruit.configure(team, self, unit_data[id])
		recruit.position = _spawn_point(team)
		recruit.formation_slot = spawn_sequence % 5
		recruit.rally_remaining = rules.rally_wait_seconds
		recruit.move_speed *= rules.army_speed_multiplier
		recruit.route_id = route_id
		recruit.route = navigation.army_route(route_id, team.base_position.x > MAP_SIZE.x * 0.5)
		team.combat_count += 1
	recruit.died.connect(_on_recruit_died)
	entities.add_child(recruit)
	if feedback:
		notify("RECRUITED", ["UNIT_WORKER" if id == &"worker" else unit_data[id].display_name])
		play_sound(&"purchase")
	return true


func _spawn_worker(team: GameTeam) -> void:
	var worker = catalog.worker_scene.instantiate()
	worker.configure(team, self)
	worker.position = _spawn_point(team) + Vector2(0, 65)
	team.worker_count += 1
	worker.died.connect(_on_recruit_died)
	entities.add_child(worker)


func _spawn_point(team: GameTeam) -> Vector2:
	spawn_sequence += 1
	var angle: float = float(spawn_sequence) * 2.39996
	return (
		team.spawn_position + Vector2.from_angle(angle) * (20.0 + float(spawn_sequence % 4) * 12.0)
	)


func _on_recruit_died(entity: CombatEntity) -> void:
	if entity.kind == &"worker":
		entity.team.worker_count -= 1
	else:
		entity.team.combat_count -= 1


func _purchase_upgrade(team_id: int, id: StringName, feedback: bool = true) -> bool:
	if match_finished or get_tree().paused:
		return false
	var team: GameTeam = team_by_id(team_id)
	if team == null:
		return false
	for definition in upgrades:
		if definition.id == id:
			var success: bool = team.upgrade(definition)
			if feedback:
				if success:
					play_sound(&"purchase")
				notify(
					(
						"UPGRADED"
						if success
						else "INSUFFICIENT_WOOD"
					), [definition.display_name] if success else []
				)
			return success
	return false


func _on_king_died(entity: CombatEntity) -> void:
	if match_finished:
		return
	match_finished = true
	session.finish()
	var winner: CombatEntity = enemy_king(entity.team.team_id)
	var winner_id: int = winner.team.team_id if winner != null else 0
	winning_team_id = winner_id
	play_sound(&"victory" if winner_id == player.team.team_id else &"defeat")
	get_tree().paused = true
	if tutorial != null:
		tutorial.stage = TutorialDirector.Stage.COMPLETE
	session.publish({"type": "match_end", "team": winner_id})
	match_ended.emit(winner_id)


func notify(key: String, arguments: Array = []) -> void:
	if key in ["UNIT_CAP", "INSUFFICIENT_GOLD", "INSUFFICIENT_WOOD", "BUILD_UNAVAILABLE"]:
		play_sound(&"failed")
	if hud != null:
		hud.notify(key, arguments)


func _create_pads() -> void:
	for team in teams:
		var mirror: bool = team.base_position.x > MAP_SIZE.x * 0.5
		var points := map_definition.home_pads
		for index in range(points.size()):
			var point: Vector2 = points[index]
			if mirror:
				point.x = MAP_SIZE.x - point.x
			_add_pad(point, "PAD_" + ("EMBER" if mirror else "AZURE") + "_" + ["GATE", "PINE", "WOOD"][index], team.team_id if index == 0 else 0)
	for index in range(map_definition.neutral_pads.size()):
		_add_pad(map_definition.neutral_pads[index], ["PAD_NORTH", "PAD_CENTER", "PAD_SOUTH"][index], 0)

func _add_pad(point: Vector2, title: String, home_id: int) -> void:
	var pad = PAD_SCRIPT.new()
	pad.game = self
	pad.position = point
	pad.pad_name = title
	pad.home_team_id = home_id
	add_child(pad)
	move_child(pad, $Entities.get_index())
	pads.append(pad)

func nearest_pad(commander):
	var result = null
	var distance: float = balance.build_reach
	for pad in pads:
		var candidate: float = commander.global_position.distance_to(pad.global_position)
		if candidate <= distance:
			result = pad
			distance = candidate
	return result

func pad_access(commander, pad) -> bool:
	return not match_finished and not get_tree().paused and is_instance_valid(commander) and commanders.has(commander) and commander.alive and is_instance_valid(pad) and pads.has(pad) and commander.global_position.distance_to(pad.global_position) <= balance.build_reach and navigation.clear_line(commander.global_position, pad.global_position)

func _build_tower(commander, pad) -> bool:
	if not pad_access(commander, pad) or pad.occupied() or pad.rebuild_remaining > 0:
		return false
	if pad.home_team_id != 0 and pad.home_team_id != commander.team.team_id:
		return false
	if not commander.team.spend(balance.tower_money, balance.tower_wood):
		return false
	var tower = TOWER_SCRIPT.new()
	tower.configure(commander.team, self)
	tower.position = pad.position
	tower.pad = pad
	pad.tower = tower
	tower.died.connect(pad.released)
	entities.add_child(tower)
	spawn_effect(tower.position, tower.team.color, "build")
	play_sound(&"tower_build", tower.position)
	if commander.human_controlled:
		notify("TOWER_CONSTRUCTED", [pad.pad_name])
	return true

func _upgrade_tower(commander, pad) -> bool:
	if not pad_access(commander, pad) or not pad.occupied():
		return false
	var tower = pad.tower
	if tower.team.team_id != commander.team.team_id or tower.level >= 3:
		return false
	var cost: Vector2i = tower.upgrade_cost()
	if not commander.team.spend(cost.x, cost.y):
		return false
	tower.apply_upgrade()
	spawn_effect(tower.position, tower.team.color, "upgrade")
	play_sound(&"tower_upgrade", tower.position)
	if commander.human_controlled:
		notify("TOWER_UPGRADED")
	return true


func spawn_effect(point: Vector2, tint: Color, type: String) -> void:
	if not presentation_enabled:
		return
	# A fixed visual budget protects burst recruitment and simultaneous battles.
	# Crown destruction must remain visible even when the ordinary budget is full.
	if effect_count >= MAX_EFFECTS and type != "crownfall":
		return
	var effect = EFFECT_SCRIPT.new()
	effect.position = point
	effect.tint = tint
	effect.effect = type
	effect_count += 1
	effect.tree_exited.connect(func(): effect_count -= 1)
	add_child(effect)

func launch_projectile(team_id: int, start: Vector2, aim: Vector2, damage: float, structure_multiplier: float, commander_id: int = 0) -> void:
	var projectile = PROJECTILE_SCRIPT.new()
	projectile.configure(self, team_id, start, aim, damage, structure_multiplier, commander_id)
	entities.add_child(projectile)


func rebuild_spatial() -> void:
	# One shared broad phase avoids a full-tree scan per moving actor per frame.
	spatial.clear()
	for entity in session.actors_in_order:
		if not is_instance_valid(entity) or not entity.alive or entity.is_queued_for_deletion():
			continue
		var cell := Vector2i((entity.position / 100.0).floor())
		if not spatial.has(cell):
			spatial[cell] = []
		spatial[cell].append(entity)

func separation_for(entity: CombatEntity) -> Vector2:
	var cell := Vector2i((entity.position / 100.0).floor())
	var force := Vector2.ZERO
	for x in range(-1, 2):
		for y in range(-1, 2):
			for other in spatial.get(cell + Vector2i(x,y), []):
				if not is_instance_valid(other) or other == entity or not other.alive:
					continue
				var difference: Vector2 = entity.position - other.position
				var distance: float = difference.length()
				var spacing: float = entity.body_radius + other.body_radius + 6
				if distance > 0.01 and distance < spacing:
					force += difference / distance * (1.0 - distance / spacing)
	return force.limit_length(0.65)


func select_route(index: int) -> void:
	selected_route = clampi(index, 0, navigation.lanes.size() - 1)
	session.publish({"type": "route_selected", "team": player.team.team_id, "route": selected_route})
	route_highlight = 3.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):
		var event := InputEventAction.new()
		event.action = &"pause_match"
		event.pressed = true
		hud._unhandled_input(event)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if pause_on_focus_loss and is_instance_valid(session) and session.state == MatchSession.State.RUNNING and presentation_enabled and is_instance_valid(hud):
			hud._toggle_pause()
