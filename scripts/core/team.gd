class_name GameTeam
extends Node
## Controller-independent ownership. Multiple future players can share this team.

signal resources_changed
signal upgrades_changed

const MAX_WORKERS: int = 10
const MAX_COMBAT_UNITS: int = 40

var team_id: int = 0
var display_name: String = ""
var color: Color = Color.WHITE
var money: int = 210
var wood: int = 35
var base_position: Vector2
var spawn_position: Vector2
var king = null
var worker_count: int = 0
var combat_count: int = 0
var upgrade_levels: Dictionary = {}
var base_stats: Dictionary = {
	&"king_health": 1200.0,
	&"king_damage": 32.0,
	&"king_attack_speed": 1.0,
	&"king_range": 225.0,
	&"worker_speed": 105.0,
	&"worker_health": 65.0,
	&"worker_capacity": 12.0,
	&"worker_gather": 3.0,
	&"income": 10.0,
}
var stats: Dictionary = {}


func _init() -> void:
	stats = base_stats.duplicate()


func is_enemy(other_team_id: int) -> bool:
	return team_id != other_team_id


func can_afford(money_cost: int, wood_cost: int = 0) -> bool:
	return money >= money_cost and wood >= wood_cost


func spend(money_cost: int, wood_cost: int = 0) -> bool:
	if money_cost < 0 or wood_cost < 0 or not can_afford(money_cost, wood_cost):
		return false
	money -= money_cost
	wood -= wood_cost
	resources_changed.emit()
	return true


func add_resources(money_amount: int, wood_amount: int = 0) -> void:
	money += maxi(0, money_amount)
	wood += maxi(0, wood_amount)
	resources_changed.emit()


func get_stat(stat: StringName) -> float:
	return float(stats.get(stat, 0.0))


func upgrade_level(id: StringName) -> int:
	return int(upgrade_levels.get(id, 0))


func upgrade(definition: UpgradeDefinition) -> bool:
	var level: int = upgrade_level(definition.id)
	if level >= definition.maximum_level or not spend(0, definition.cost(level)):
		return false
	upgrade_levels[definition.id] = level + 1
	stats[definition.stat] = get_stat(definition.stat) + definition.amount
	upgrades_changed.emit()
	return true


func king_level() -> int:
	var total: int = 1
	for id in upgrade_levels:
		if String(id).begins_with("king_"):
			total += int(upgrade_levels[id])
	return total
