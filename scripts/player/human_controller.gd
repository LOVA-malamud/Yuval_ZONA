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
var focus_target: CombatEntity
var mobile_auto_attack: bool = OS.has_feature("mobile")
var pending_abilities: Array[Dictionary] = []


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
	if not scripted:
		for key in ["ability_dash", "ability_guard", "ability_heavy"]:
			if InputMap.has_action(key) and Input.is_action_just_pressed(key):
				request_ability(StringName(key.trim_prefix("ability_")), actor.global_position.direction_to(actor.get_global_mouse_position()))
	for request in pending_abilities:
		actor.game.session.execute(MatchCommand.new(MatchCommand.Action.ABILITY, actor.commander_id, request))
	pending_abilities.clear()
	var attacking: bool = scripted_attack if scripted else (Input.is_action_pressed("attack") or (mobile_auto_attack and not actor.healing))
	if not actor.valid_enemy(focus_target) or actor.edge_distance(focus_target) > actor.detection_range or not actor.game.navigation.clear_line(actor.position, focus_target.position):
		focus_target = null
	actor.game.session.execute(MatchCommand.new(MatchCommand.Action.INPUT, actor.commander_id, {"direction": direction, "attack": attacking, "interact": scripted_interact or (not scripted and Input.is_action_just_pressed("interact")), "target": focus_target, "delta": delta}))
	scripted_interact = false


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch and event.pressed and touch_index < 0 and event.position.x < get_viewport().get_visible_rect().size.x * 0.48:
		touch_index = event.index
		touch_origin = event.position
		touch_direction = Vector2.ZERO
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_select_target(event.position)

func _select_target(screen_position: Vector2) -> void:
	var actor = get_parent()
	var point: Vector2 = actor.get_canvas_transform().affine_inverse() * screen_position
	var best: CombatEntity = null
	var nearest := 45.0
	for candidate in actor.game.session.actors.values():
		if not actor.valid_enemy(candidate) or actor.edge_distance(candidate) > actor.detection_range or not actor.game.navigation.clear_line(actor.position, candidate.position):
			continue
		var distance: float = candidate.position.distance_to(point)
		if distance < nearest:
			nearest = distance
			best = candidate
	focus_target = best


func _input(event: InputEvent) -> void:
	# Releases must arrive even if a finger ends over a GUI control.
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_index:
		reset_touch()
	elif event is InputEventScreenDrag and event.index == touch_index:
		var offset: Vector2 = (event.position - touch_origin) / STICK_RADIUS
		touch_direction = offset.limit_length(1.0) if offset.length() >= DEAD_ZONE else Vector2.ZERO


func request_ability(ability_id: StringName, direction: Vector2 = Vector2.ZERO) -> void:
	var actor = get_parent()
	if direction.length_squared() < 0.001:
		direction = touch_direction
		if direction.length_squared() < 0.001:
			direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction.length_squared() < 0.001:
			direction = actor.global_position.direction_to(focus_target.global_position) if actor.valid_enemy(focus_target) else actor.facing
	pending_abilities.append({"ability_id": ability_id, "direction": direction.normalized()})

func reset_touch() -> void:
	pending_abilities.clear()
	touch_index = -1
	touch_direction = Vector2.ZERO
	target = null
	focus_target = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		reset_touch()
