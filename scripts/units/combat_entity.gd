class_name CombatEntity
extends Node2D
## Shared targeting, friendly-fire guard, damage, death and procedural presentation.
## All moving entities share terrain-safe pathing; actors do not form solid roadblocks.

signal died(entity: CombatEntity)

var team: GameTeam
var game = null
var match_id: int = 0
var owner_commander_id: int = 0
var rally_buff: float = 0.0
var max_health: float = 100.0
var health: float = 100.0
var damage: float = 10.0
var structure_damage_multiplier: float = 1.0
var move_speed: float = 100.0
var attack_range: float = 30.0
var attack_cooldown: float = 1.0
var detection_range: float = 260.0
var body_radius: float = 13.0
var cooldown: float = 0.0
var alive: bool = true
var category: StringName = &"army"
var tactical_role: StringName = &"melee"
var kind: StringName = &"melee"
var shot_time: float = 0.0
var shot_end: Vector2
var travel_path := PackedVector2Array()
var path_goal := Vector2(INF, INF)
var blocked_time: float = 0.0
var hit_flash: float = 0.0
var visual_time: float = 0.0
var presentation_visible: bool = false
const ART = preload("res://scripts/visuals/entity_art.gd")


func _ready() -> void:
	match_id = game.session.register_actor(self)
	add_to_group("combatants")
	game.spawn_effect(global_position, team.color, "spawn")
	queue_redraw()


func configure(owner_team: GameTeam, manager, data: UnitStats = null) -> void:
	team = owner_team
	game = manager
	if data != null:
		kind = data.id
		tactical_role = data.tactical_role
		max_health = data.max_health
		damage = data.damage
		structure_damage_multiplier = data.structure_damage_multiplier
		move_speed = data.move_speed
		attack_range = data.attack_range
		attack_cooldown = data.attack_cooldown
		detection_range = data.detection_range
		body_radius = data.body_radius
	health = max_health


func tick(delta: float) -> void:
	var fading_feedback: bool = hit_flash > 0.0 or shot_time > 0.0 or (rally_buff > 0.0 and rally_buff <= delta)
	visual_time += delta
	rally_buff = maxf(0.0, rally_buff - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	cooldown = maxf(0.0, cooldown - delta * (1.2 if rally_buff > 0.0 else 1.0))
	shot_time = maxf(0.0, shot_time - delta)
	var was_visible: bool = presentation_visible
	presentation_visible = _presentation_in_view()
	# Node movement transforms cached draw commands automatically. Only workers,
	# commander capes and transient combat feedback animate their local geometry.
	# Offscreen actors still simulate fully; redraw on re-entry refreshes any
	# cached health, animation or flash that changed while their art was culled.
	if presentation_visible and (not was_visible or fading_feedback or kind in [&"worker", &"player"]):
		queue_redraw()


func _presentation_in_view() -> bool:
	if not game.presentation_enabled:
		return false
	var canvas: Transform2D = get_canvas_transform()
	var screen_position: Vector2 = canvas * global_position
	var bounds: Rect2 = get_viewport_rect()
	if bounds.grow(120.0 * canvas.get_scale().length()).has_point(screen_position):
		return true
	# An arrow can enter the viewport even while its shooter remains outside it.
	return shot_time > 0.0 and Rect2(screen_position, Vector2.ZERO).expand(canvas * shot_end).grow(24.0).intersects(bounds)


func valid_enemy(candidate) -> bool:
	return (
		typeof(candidate) == TYPE_OBJECT and is_instance_valid(candidate) and candidate is CombatEntity
		and candidate.alive and team.is_enemy(candidate.team.team_id)
	)

func effective_move_speed() -> float:
	return move_speed * (1.15 if rally_buff > 0.0 else 1.0)


func closest_enemy(radius: float) -> CombatEntity:
	var best: CombatEntity = null
	var best_distance: float = radius
	for node in game.session.actors.values():
		if not is_instance_valid(node):
			continue
		var candidate := node as CombatEntity
		if not is_instance_valid(candidate) or not valid_enemy(candidate):
			continue
		var distance: float = edge_distance(candidate)
		if distance <= best_distance and game.navigation.clear_line(global_position, candidate.global_position):
			best_distance = distance
			best = candidate
	return best


func edge_distance(other: CombatEntity) -> float:
	return maxf(
		0.0, global_position.distance_to(other.global_position) - body_radius - other.body_radius
	)


func attack(target: CombatEntity) -> void:
	if not alive or cooldown > 0.0 or not valid_enemy(target):
		return
	if edge_distance(target) > attack_range or not game.navigation.clear_line(global_position, target.global_position):
		return
	cooldown = attack_cooldown
	shot_time = 0.22
	shot_end = target.global_position
	queue_redraw()
	var sound: StringName = &"melee"
	if tactical_role == &"ranged":
		sound = &"ranged"
	elif tactical_role == &"tank":
		sound = &"tank"
		game.spawn_effect(target.global_position, Color("e6c28b"), "impact")
	elif kind in [&"tower", &"king"]:
		sound = &"tower_fire"
	game.play_sound(sound, global_position)
	if tactical_role == &"ranged":
		game.launch_projectile(team.team_id, global_position, target.global_position, damage, structure_damage_multiplier, owner_commander_id)
	else:
		var dealt: float = damage * (structure_damage_multiplier if target.kind in [&"king", &"tower"] else 1.0)
		target.take_damage(dealt, team.team_id, owner_commander_id)


func take_damage(amount: float, attacker_team_id: int, source_commander_id: int = 0) -> void:
	if not alive or not team.is_enemy(attacker_team_id) or amount <= 0.0:
		return
	if kind == &"king" and game.coordination != null:
		game.coordination.king_damage(source_commander_id, minf(health, amount))
	hit_flash = 0.16
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		die()
	queue_redraw()


func die() -> void:
	game.spawn_effect(global_position, team.color, "death")
	alive = false
	if game.coordination != null:
		game.coordination.actor_died(self)
	game.session.publish({"type": "death", "team": team.team_id, "kind": String(kind), "entity_id": match_id, "position": [position.x, position.y], "commander_id": owner_commander_id})
	remove_from_group("combatants")
	died.emit(self)
	queue_free()


func travel_toward(destination: Vector2, delta: float) -> void:
	# A cached path may be stale after a respawn or a moving target changes direction.
	var endpoint_reached: bool = travel_path.size() == 1 and global_position.distance_to(travel_path[0]) < 24.0
	var segment_blocked: bool = not travel_path.is_empty() and not game.navigation.clear_line(global_position, travel_path[0], body_radius + 1.0)
	if path_goal.distance_to(destination) > 40.0 or travel_path.is_empty() or segment_blocked or blocked_time > 0.75 or (endpoint_reached and path_goal.distance_to(destination) > 4.0):
		path_goal = destination
		travel_path = game.navigation.path(global_position, destination)
		blocked_time = 0.0
	while travel_path.size() > 1 and global_position.distance_to(travel_path[0]) < 22.0:
		travel_path.remove_at(0)
	if travel_path.is_empty():
		return
	var waypoint: Vector2 = travel_path[0]
	# Skip grid corners only with full body clearance.
	while travel_path.size() > 1 and game.navigation.clear_line(global_position, travel_path[1], body_radius + 8.0):
		travel_path.remove_at(0)
		waypoint = travel_path[0]
	var heading: Vector2 = global_position.direction_to(waypoint)
	var direction: Vector2 = (heading + game.separation_for(self)).limit_length(1.0)
	var motion: Vector2 = direction * minf(effective_move_speed() * delta, global_position.distance_to(waypoint))
	var before: Vector2 = global_position
	global_position = game.navigation.move(global_position, motion, body_radius)
	if before.distance_to(global_position) < move_speed * delta * 0.1 and before.distance_to(destination) > 30.0:
		blocked_time += delta
	else:
		blocked_time = 0.0


func _draw() -> void:
	if team == null or not alive:
		return
	if rally_buff > 0.0:
		draw_arc(Vector2.ZERO, body_radius + 7.0, 0.0, TAU, 24, Color("edce8e"), 2.0, true)
	var tint: Color = team.color.lerp(Color.WHITE, hit_flash / 0.16 * 0.7)
	# Small reaction in the silhouette without shaking the camera or hiding hits.
	var recoil := Vector2.ZERO
	var art_kind: StringName = tactical_role if category == &"army" else kind
	if shot_time > 0 and art_kind in [&"melee", &"tank", &"player"]:
		recoil = global_position.direction_to(shot_end) * sin(shot_time / 0.22 * PI) * (3.0 if art_kind == &"tank" else 2.0)
	ART.paint(self, art_kind, tint, visual_time * 6.0, recoil)
	draw_set_transform(Vector2.ZERO)
	# Team emblems remain distinguishable in grayscale: Azure disk / Ember chevron.
	var badge := Vector2(0, 2) if kind not in [&"king", &"tower"] else Vector2(0, -12)
	if team.team_id == 1:
		draw_circle(badge, 3.2, Color("edf3dc"))
	else:
		draw_line(badge + Vector2(-4,-2), badge + Vector2(0,3), Color("fff0d5"), 2)
		draw_line(badge + Vector2(0,3), badge + Vector2(4,-2), Color("fff0d5"), 2)
	var width: float = 36.0
	var bar_y: float = -39.0
	if kind == &"king":
		width = 98.0
		bar_y = -88.0
		draw_string(ThemeDB.fallback_font, Vector2(-100,-99), tr("KING_WORLD") % [tr(team.display_name).to_upper(), team.king_level()], HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color("f1db9f"))
	elif kind == &"tower":
		width = 54.0
		bar_y = -90.0
		for level_index in range(int(get("level"))):
			draw_rect(Rect2(-9 + level_index*7, -58, 5, 5), ART.GOLD)
	elif kind == &"player":
		width = 52.0
		bar_y = -57.0
		draw_arc(Vector2(0,5), 30, 0, TAU, 32, Color.WHITE if get("human_controlled") else tint, 2.5, true)
		if not get("human_controlled"):
			draw_string(ThemeDB.fallback_font, Vector2(-80,-69), str(get("commander_id")) + " · " + tr(str(get("commander_name"))), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color.WHITE)
		if get("human_controlled"):
			draw_arc(Vector2(0,5),34,0,TAU,32,Color(0.04,0.09,0.12,0.9),3,true)
			draw_rect(Rect2(-25,-86,50,21),ART.INK)
			draw_string(ThemeDB.fallback_font,Vector2(-25,-70),tr("YOU_MARKER"),HORIZONTAL_ALIGNMENT_CENTER,50,15,Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(-6,-65),Vector2(6,-65),Vector2(0,-59)]),Color.WHITE)
	# Keep important health persistent, ordinary healthy army silhouettes uncluttered.
	if kind in [&"king", &"tower", &"player"] or health < max_health:
		draw_rect(Rect2(-width/2-1, bar_y-1, width+2, 6), ART.INK)
		draw_rect(Rect2(-width/2, bar_y, width, 4), Color("513d3b"))
		draw_rect(Rect2(-width/2, bar_y, width * health / max_health, 4), tint)
	if shot_time > 0.0 and tactical_role != &"ranged":
		var end: Vector2 = to_local(shot_end)
		var progress: float = 1.0 - shot_time / 0.22
		if kind in [&"tower", &"king"]:
			var tip: Vector2 = end * progress
			draw_line(tip - end.normalized() * (34 if kind == &"tower" else 20), tip, ART.GOLD, 4 if kind in [&"king", &"tower"] else 3, true)
			if kind in [&"king", &"tower"]:
				draw_circle(Vector2(0,-22),6*(shot_time/0.22),Color("ffe8a8"))
			draw_circle(tip, 4 if kind == &"king" else 2, Color.WHITE)
		else:
			var angle: float = end.angle()
			draw_arc(Vector2.ZERO, 39, angle-0.9+progress, angle+0.5+progress, 12, Color(1,0.92,0.7,shot_time/0.22), 4, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()
