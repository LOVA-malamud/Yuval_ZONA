extends Node2D
## A ranged shot travels to the position aimed at when fired.

const SPEED: float = 1400.0
const RADIUS: float = 5.0

var game
var source_commander_id: int = 0
var owner_team_id: int
var base_damage: float
var structure_multiplier: float = 1.0
var direction := Vector2.ZERO
var remaining: float = 0.0


func configure(manager, team_id: int, start: Vector2, aim: Vector2, damage: float, multiplier: float, commander_id: int = 0) -> void:
	game = manager
	source_commander_id = commander_id
	owner_team_id = team_id
	position = start
	direction = start.direction_to(aim)
	remaining = start.distance_to(aim)
	base_damage = damage
	structure_multiplier = multiplier


func _ready() -> void:
	add_to_group("projectiles")
	queue_redraw()


func step_gameplay(delta: float) -> void:
	if remaining <= 0.0:
		queue_free()
		return
	var travel: float = minf(SPEED * delta, remaining)
	var finish: Vector2 = global_position + direction * travel
	if not game.navigation.clear_line(global_position, finish):
		queue_free()
		return
	var struck: CombatEntity = null
	var nearest: float = INF
	for entity in game.session.actors_in_order:
		if not is_instance_valid(entity) or not entity.alive or not entity.team.is_enemy(owner_team_id):
			continue
		var contact: Vector2 = Geometry2D.get_closest_point_to_segment(entity.global_position, global_position, finish)
		if entity.global_position.distance_to(contact) <= entity.body_radius + RADIUS:
			var along: float = global_position.distance_to(contact)
			if along < nearest:
				nearest = along
				struck = entity
	if struck != null:
		var amount: float = base_damage * (structure_multiplier if struck.kind in [&"king", &"tower"] else 1.0)
		struck.take_damage(amount, owner_team_id, source_commander_id)
		game.spawn_effect(global_position + direction * nearest, Color("e6c28b"), "impact")
		queue_free()
		return
	global_position = finish
	remaining -= travel
	if remaining <= 0.0:
		queue_free()


func _draw() -> void:
	draw_line(-direction * 14.0, Vector2.ZERO, Color("edc46e", 0.65), 3.0, true)
	draw_circle(Vector2.ZERO, RADIUS, Color("f8efd4"))
