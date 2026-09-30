extends Node2D
## Composition root and command boundary. Controllers never spawn entities directly.

signal match_ended(winning_team_id: int)

const KING_SCENE = preload("res://scenes/king/king.tscn")
const UNIT_SCENE = preload("res://scenes/units/combat_unit.tscn")
const WORKER_SCENE = preload("res://scenes/workers/worker.tscn")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const TREE_SCENE = preload("res://scenes/environment/tree_resource.tscn")
const WORKER_COST: int = 65
const MAP_SIZE := Vector2(4600, 2600)

var unit_data: Dictionary = {
	&"melee": preload("res://resources/units/melee.tres"),
	&"ranged": preload("res://resources/units/ranged.tres"),
	&"tank": preload("res://resources/units/tank.tres"),
}
var upgrades: Array[UpgradeDefinition] = [
	preload("res://resources/upgrades/king_health.tres"),
	preload("res://resources/upgrades/king_damage.tres"),
	preload("res://resources/upgrades/king_attack_speed.tres"),
	preload("res://resources/upgrades/king_range.tres"),
	preload("res://resources/upgrades/worker_speed.tres"),
	preload("res://resources/upgrades/worker_capacity.tres"),
	preload("res://resources/upgrades/worker_gather.tres"),
	preload("res://resources/upgrades/income.tres"),
]
@export var strategy_seed: int = 42
var teams: Array[GameTeam] = []
var player = null
var commanders: Array = []
const HUMAN_CONTROLLER = preload("res://scripts/player/human_controller.gd")
const AI_CONTROLLER = preload("res://scripts/ai/enemy_ai.gd")
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
var navigation := RouteMap.new()
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
	worker_cost = int(simulation_config.get("shared", {}).get("worker_cost", WORKER_COST))


func _ready() -> void:
	_apply_simulation_config()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Crownfront")
	get_tree().paused = false
	_create_team(1, "TEAM_AZURE", Color(0.30, 0.76, 1.0), Vector2(400, 1300), 1.0)
	_create_team(2, "TEAM_EMBER", Color(1.0, 0.40, 0.35), Vector2(4200, 1300), -1.0)
	_create_trees()
	_create_pads()
	for team in teams:
		_create_king(team)
		for index in range(int(_team_config(team.team_id).get("workers", 3))):
			_spawn_worker(team)
	_create_commander(teams[0], 1, "COMMANDER_YOU", "human", Vector2(-25, 110))
	_create_commander(teams[0], 2, "COMMANDER_WARDEN", "ally", Vector2(50, -110))
	_create_commander(teams[1], 3, "COMMANDER_VANGUARD", "aggressive", Vector2(-50, 110))
	_create_commander(teams[1], 4, "COMMANDER_STEWARD", "economic", Vector2(25, -110))
	$EconomyManager.teams = teams
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


func _process(delta: float) -> void:
	match_seconds += delta
	route_highlight = maxf(0.0, route_highlight - delta)


func _create_team(id: int, title: String, tint: Color, base: Vector2, direction: float) -> void:
	var team := GameTeam.new()
	var settings: Dictionary = _team_config(id)
	team.money = int(settings.get("money", team.money))
	team.wood = int(settings.get("wood", team.wood))
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
		for grove in [Vector2(450, 950), Vector2(450, 1650), Vector2(1150, 650), Vector2(1150, 1950)]:
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


func purchase(team_id: int, id: StringName, feedback: bool = true, route_id: int = -1) -> bool:
	if match_finished or get_tree().paused:
		return false
	var team: GameTeam = team_by_id(team_id)
	if team == null:
		return false
	var is_worker: bool = id == &"worker"
	if not is_worker and not unit_data.has(id):
		return false
	if (
		(is_worker and team.worker_count >= GameTeam.MAX_WORKERS)
		or (not is_worker and team.combat_count >= GameTeam.MAX_COMBAT_UNITS)
	):
		if feedback:
			notify("UNIT_CAP")
		return false
	var cost: int = worker_cost if is_worker else int(unit_data[id].money_cost)
	if not team.spend(cost):
		if feedback:
			notify("INSUFFICIENT_GOLD")
		return false
	if is_worker:
		_spawn_worker(team)
	else:
		var unit = UNIT_SCENE.instantiate()
		unit.configure(team, self, unit_data[id])
		unit.position = _spawn_point(team)
		unit.formation_slot = spawn_sequence % 5
		unit.route_id = selected_route if route_id < 0 else clampi(route_id, 0, 2)
		unit.route = navigation.army_route(unit.route_id, team.base_position.x > MAP_SIZE.x * 0.5)
		team.combat_count += 1
		unit.died.connect(_on_recruit_died)
		entities.add_child(unit)
	if feedback:
		notify("RECRUITED", ["UNIT_" + String(id).to_upper()])
		AudioFeedback.play(&"purchase")
	return true


func _spawn_worker(team: GameTeam) -> void:
	var worker = WORKER_SCENE.instantiate()
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


func purchase_upgrade(team_id: int, id: StringName, feedback: bool = true) -> bool:
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
					AudioFeedback.play(&"purchase")
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
	var winner: CombatEntity = enemy_king(entity.team.team_id)
	var winner_id: int = winner.team.team_id if winner != null else 0
	winning_team_id = winner_id
	AudioFeedback.play(&"victory" if winner_id == player.team.team_id else &"defeat")
	get_tree().paused = true
	match_ended.emit(winner_id)


func notify(key: String, arguments: Array = []) -> void:
	if key in ["UNIT_CAP", "INSUFFICIENT_GOLD", "INSUFFICIENT_WOOD", "BUILD_UNAVAILABLE"]:
		AudioFeedback.play(&"failed")
	hud.notify(key, arguments)


func _create_pads() -> void:
	for team in teams:
		var mirror: bool = team.base_position.x > MAP_SIZE.x * 0.5
		var points := [Vector2(750, 1250), Vector2(1090, 900), Vector2(1090, 1770)]
		for index in range(points.size()):
			var point: Vector2 = points[index]
			if mirror:
				point.x = MAP_SIZE.x - point.x
			_add_pad(point, "PAD_" + ("EMBER" if mirror else "AZURE") + "_" + ["GATE", "PINE", "WOOD"][index], team.team_id if index == 0 else 0)
	_add_pad(Vector2(2300, 810), "PAD_NORTH", 0)
	_add_pad(Vector2(2300, 1570), "PAD_CENTER", 0)
	_add_pad(Vector2(2300, 2070), "PAD_SOUTH", 0)

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

func build_tower(commander, pad) -> bool:
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
	AudioFeedback.play(&"tower_build", tower.position)
	if commander.human_controlled:
		notify("TOWER_CONSTRUCTED", [pad.pad_name])
	return true

func upgrade_tower(commander, pad) -> bool:
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
	AudioFeedback.play(&"tower_upgrade", tower.position)
	if commander.human_controlled:
		notify("TOWER_UPGRADED")
	return true


func spawn_effect(point: Vector2, tint: Color, type: String) -> void:
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

func launch_projectile(team_id: int, start: Vector2, aim: Vector2, damage: float, structure_multiplier: float) -> void:
	var projectile = PROJECTILE_SCRIPT.new()
	projectile.configure(self, team_id, start, aim, damage, structure_multiplier)
	entities.add_child(projectile)


func _physics_process(_delta: float) -> void:
	# One shared broad phase avoids a full-tree scan per moving actor per frame.
	spatial.clear()
	for entity in get_tree().get_nodes_in_group("combatants"):
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
	selected_route = clampi(index, 0, 2)
	route_highlight = 3.0
