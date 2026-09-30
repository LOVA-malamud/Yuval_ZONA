extends Node
## Keyboard, touch and scripted play feed the same commander commands.

const STICK_RADIUS: float = 72.0
const DEAD_ZONE: float = 0.14

var touch_index: int = -1
var touch_origin := Vector2.ZERO
var touch_direction := Vector2.ZERO
var scripted: bool = false
var scripted_direction := Vector2.ZERO
var scripted_attack: bool = false
var scripted_interact: bool = false
var target: CombatEntity


func set_scripted_command(direction: Vector2, attack: bool = true, interact: bool = false) -> void:
	scripted = true
	scripted_direction = direction.limit_length(1.0)
	scripted_attack = attack
	scripted_interact = interact


func clear_scripted_command() -> void:
	scripted = false
	scripted_direction = Vector2.ZERO
	scripted_attack = false
	scripted_interact = false


func drive(actor, delta: float) -> void:
	var direction: Vector2 = scripted_direction if scripted else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not scripted and touch_index >= 0:
		direction = touch_direction
	actor.global_position = actor.game.navigation.move(actor.global_position, direction * actor.move_speed * delta, actor.body_radius)
	var attacking: bool = scripted_attack if scripted else (Input.is_action_pressed("attack") or touch_index >= 0)
	if attacking:
		if not actor.valid_enemy(target) or actor.edge_distance(target) > actor.attack_range or not actor.game.navigation.clear_line(actor.global_position, target.global_position):
			target = actor.closest_enemy(actor.attack_range)
		if target != null:
			actor.attack(target)
	else:
		target = null
	if scripted_interact or (not scripted and Input.is_action_just_pressed("interact")):
		actor.interact()
		scripted_interact = false


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch and event.pressed and touch_index < 0 and event.position.x < get_viewport().get_visible_rect().size.x * 0.48:
		touch_index = event.index
		touch_origin = event.position
		touch_direction = Vector2.ZERO


func _input(event: InputEvent) -> void:
	# Releases must arrive even if a finger ends over a GUI control.
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_index:
		reset_touch()
	elif event is InputEventScreenDrag and event.index == touch_index:
		var offset: Vector2 = (event.position - touch_origin) / STICK_RADIUS
		touch_direction = offset.limit_length(1.0) if offset.length() >= DEAD_ZONE else Vector2.ZERO


func reset_touch() -> void:
	touch_index = -1
	touch_direction = Vector2.ZERO
	target = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		reset_touch()
