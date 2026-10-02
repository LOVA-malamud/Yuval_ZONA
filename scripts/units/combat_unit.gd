extends CombatEntity

var practice_unit: bool = false
var regroup_remaining: float = 0.0
var regroup_goal := Vector2.ZERO
var target: CombatEntity
var scan_time: float = 0.0
var route_id: int = 1
var route := PackedVector2Array()
var route_index: int = 1
var formation_slot: int = 0
var rally_remaining: float = 6.0

func step_gameplay(delta: float) -> void:
	if not alive:
		return
	tick(delta)
	if stun_remaining > 0.0:
		return
	regroup_remaining = maxf(0.0, regroup_remaining - delta)
	if practice_unit:
		return
	scan_time -= delta
	if scan_time <= 0.0:
		scan_time = 0.35
		if tactical_role == &"tank":
			var structure: CombatEntity = null
			var distance: float = detection_range
			for candidate in game.session.actors_in_order:
				if valid_enemy(candidate) and candidate.kind in [&"king", &"tower"] and edge_distance(candidate) < distance and game.navigation.clear_line(position,candidate.position):
					structure = candidate
					distance = edge_distance(candidate)
			if structure != null:
				target = structure
		if not valid_enemy(target) or edge_distance(target) > detection_range:
			target = closest_enemy(detection_range)
	if valid_enemy(target):
		var distance: float = edge_distance(target)
		if distance <= attack_range:
			attack(target)
			var separation: Vector2 = game.separation_for(self)
			global_position = game.navigation.move(global_position, separation * effective_move_speed() * delta * 0.8, body_radius)
			if tactical_role == &"ranged" and distance < 85.0 and target.kind not in [&"king", &"tower"]:
				var away: Vector2 = target.position.direction_to(position)
				global_position = game.navigation.move(global_position, away * effective_move_speed() * delta * 0.65, body_radius)
		else:
			# Approach different points on the near arc; no rigid formations or blockers.
			var approach: Vector2 = target.position.direction_to(position).rotated((formation_slot - 2) * 0.20)
			var reach: float = body_radius + target.body_radius + attack_range * (0.80 if tactical_role == &"ranged" else 0.45)
			var destination: Vector2 = target.position + approach * reach
			if not game.navigation.walkable(destination, body_radius + 2):
				destination = target.position
			travel_toward(destination, delta)
		return
	if regroup_remaining > 0.0:
		if position.distance_to(regroup_goal) > 30.0:
			travel_toward(regroup_goal, delta)
		return
	if route.is_empty():
		return
	if route_index == 1 and position.distance_to(route[1]) < 70.0 and rally_remaining > 0:
		rally_remaining -= delta
		var nearby: int = 0
		for friend in game.session.actors.values():
			if friend.team == team and friend.category == &"army" and friend.position.distance_to(position) < 180:
				nearby += 1
		if nearby < 3:
			return
	while route_index < route.size() - 1 and global_position.distance_to(route[route_index]) < 55.0:
		route_index += 1
	travel_toward(route[mini(route_index, route.size() - 1)], delta)
