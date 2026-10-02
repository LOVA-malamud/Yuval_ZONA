class_name CoordinationService
extends Node
## Tactical orders, battle alerts and result measurements belong to this match.
const ORDERS := [&"auto", &"north", &"center", &"south", &"defend", &"escort"]
var game = null
var alerts: Array[Dictionary] = []
var last_alert: Dictionary = {}
var purchases: Array[Dictionary] = []
var commander_stats: Dictionary = {}
var team_stats: Dictionary = {}
var scan_remaining: float = 0.0

func setup(owner_game) -> void:
	game = owner_game
	for commander in game.commanders:
		commander_stats[commander.commander_id] = {"gold": 0, "wood": 0, "recruits": 0, "king_damage": 0.0, "rallies": 0, "towers": 0}
	for team in game.teams:
		team_stats[team.team_id] = {"workers_lost": 0, "deposited": 0, "towers_built": 0, "towers_destroyed": 0}

func set_order(requester, order: StringName) -> bool:
	if not requester.human_controlled or not order in ORDERS:
		return false
	for ally in game.commanders:
		if ally.team == requester.team and ally != requester and ally.controller.has_method("set_order"):
			ally.controller.set_order(order)
			game.session.publish({"type": "ally_order", "team": ally.team.team_id, "commander_id": ally.commander_id, "order": String(order)})
	return true

func rally(commander) -> bool:
	if not commander.alive or commander.rally_cooldown > 0.0:
		return false
	var affected := 0
	for unit in game.entities.get_children():
		if unit is CombatEntity and unit.alive and unit.category == &"army" and unit.team == commander.team and unit.position.distance_to(commander.position) <= 300.0:
			unit.rally_buff = 8.0
			unit.queue_redraw()
			affected += 1
	commander.rally_cooldown = 30.0
	commander_stats[commander.commander_id].rallies += 1
	game.spawn_effect(commander.position, Color("edce8e"), "rally")
	game.play_sound(&"tower_upgrade", commander.position)
	game.session.publish({"type": "rally", "team": commander.team.team_id, "commander_id": commander.commander_id, "affected": affected, "position": [commander.position.x, commander.position.y]})
	return true

func regroup(commander) -> bool:
	if not commander.alive:
		return false
	var affected := 0
	for unit in game.entities.get_children():
		if unit is CombatEntity and unit.alive and unit.category == &"army" and unit.team == commander.team and unit.position.distance_to(commander.position) <= 400.0:
			var desired: Vector2 = commander.position + Vector2.from_angle(affected * 2.39996) * (55.0 + 18.0 * (affected % 4))
			if not game.navigation.walkable(desired, unit.body_radius + 8.0):
				desired = game.navigation.grid.get_point_position(game.navigation._open_cell(desired))
			if not game.navigation.walkable(desired, unit.body_radius):
				desired = unit.position
			unit.regroup_goal = desired
			unit.regroup_remaining = 8.0
			unit.travel_path.clear()
			affected += 1
	game.session.publish({"type": "regroup", "team": commander.team.team_id, "commander_id": commander.commander_id, "affected": affected, "position": [commander.position.x, commander.position.y]})
	return true

func purchase(commander, type: StringName, id: StringName, gold: int, wood: int, actor: CombatEntity = null) -> void:
	var stats: Dictionary = commander_stats[commander.commander_id]
	stats.gold += gold
	stats.wood += wood
	if type == &"recruit":
		stats.recruits += 1
	if type == &"tower_built":
		stats.towers += 1
		team_stats[commander.team.team_id].towers_built += 1
	var entry := {"type": String(type), "team": commander.team.team_id, "commander_id": commander.commander_id, "id": String(id), "gold": gold, "wood": wood}
	if type == &"upgrade":
		entry["level"] = commander.team.upgrade_level(id)
	if actor != null:
		entry["entity_id"] = actor.match_id
		entry["position"] = [actor.position.x, actor.position.y]
	purchases.push_front(entry)
	var counts := {}
	var retained: Array[Dictionary] = []
	for purchase_entry in purchases:
		counts[purchase_entry.team] = int(counts.get(purchase_entry.team, 0)) + 1
		if counts[purchase_entry.team] <= 6:
			retained.append(purchase_entry)
	purchases = retained
	game.session.publish(entry)

func actor_died(actor: CombatEntity) -> void:
	if actor.category == &"worker":
		team_stats[actor.team.team_id].workers_lost += 1
	elif actor.kind == &"tower":
		team_stats[actor.team.team_id].towers_destroyed += 1
		alert(&"tower_lost", actor.team.team_id, actor.position)

func king_damage(commander_id: int, amount: float) -> void:
	if commander_stats.has(commander_id):
		commander_stats[commander_id].king_damage += amount

func deposit(team_id: int, amount: int) -> void:
	team_stats[team_id].deposited += amount
	game.session.publish({"type": "deposit", "team": team_id, "amount": amount})

func alert(type: StringName, team_id: int, point: Vector2) -> bool:
	var lane := closest_lane(point)
	var key := "%s:%d:%d" % [type, team_id, lane]
	if game.match_seconds - float(last_alert.get(key, -100.0)) < 10.0:
		return false
	last_alert[key] = game.match_seconds
	var entry := {"type": "alert", "category": String(type), "team": team_id, "lane": lane, "position": [point.x, point.y], "t": game.match_seconds}
	alerts.push_front(entry)
	if alerts.size() > 12:
		alerts.pop_back()
	game.session.publish(entry)
	return true

func closest_lane(point: Vector2) -> int:
	var best := 0
	var distance := INF
	for lane in range(game.navigation.lanes.size()):
		var route: PackedVector2Array = game.navigation.lanes[lane]
		for index in range(route.size() - 1):
			var candidate := Geometry2D.get_closest_point_to_segment(point, route[index], route[index + 1]).distance_squared_to(point)
			if candidate < distance:
				distance = candidate
				best = lane
	return best

func step_gameplay(delta: float) -> void:
	revalidate_plans()
	scan_remaining -= delta
	if scan_remaining > 0.0:
		return
	scan_remaining = 1.0
	var groups := {}
	for unit in game.session.actors.values():
		if unit.category == &"worker" and unit.valid_enemy(unit.threat):
			alert(&"workers_threatened", unit.team.team_id, unit.position)
		elif unit.category == &"army" and unit.target == null and unit.regroup_remaining <= 0.0 and unit.route_index > 1:
			var key := Vector2i(unit.team.team_id, unit.route_id)
			if not groups.has(key):
				groups[key] = []
			groups[key].append(unit)
	for group in groups.values():
		for candidate in group:
			var nearby := 0
			for friend in group:
				if candidate.position.distance_squared_to(friend.position) <= 250.0 * 250.0:
					nearby += 1
			if nearby >= 5:
				alert(&"push_forming", candidate.team.team_id, candidate.position)
				break

func revalidate_plans() -> void:
	for commander in game.commanders:
		var bot = commander.controller
		if bot.has_method("set_order") and bot.build_goal != null:
			if not commander.alive or not is_instance_valid(bot.build_goal) or bot.build_goal.occupied() or not commander.team.can_afford(game.balance.tower_money, game.balance.tower_wood):
				bot.build_goal = null
				bot.reserved_gold = 0
				bot.reserved_wood = 0

func snapshot() -> Dictionary:
	return {"commanders": commander_stats.duplicate(true), "teams": team_stats.duplicate(true)}
