extends CombatEntity
## Persistent commander body, independent of its human/AI controller.

signal base_interacted

var commander_id: int = 0
var commander_name: String = "COMMANDER_DEFAULT"
var human_controlled: bool = false
var spawn_position: Vector2
var controller = null
var rally_cooldown: float = 0.0
var respawn_remaining: float = 0.0
var heal_cooldown: float = 0.0
var tactical_status: String = "STATUS_READY"
var strike_target: CombatEntity
var strike_remaining: float = 0.0
var healing: bool = false
var action_state: StringName = &"ready"
var action_remaining: float = 0.0
var facing := Vector2.RIGHT
var scouting: bool = false
var scouting_target := Vector2.ZERO
var ability_cooldowns: Dictionary = {&"dash": 0.0, &"guard": 0.0, &"heavy": 0.0}

func _tuning(key: String, fallback: float) -> float:
	for property in game.balance.get_property_list():
		if property.name == key:
			return float(game.balance.get(key))
	return fallback

func cancel_action() -> void:
	healing = false
	action_state = &"ready"
	action_remaining = 0.0
	strike_target = null
	strike_remaining = 0.0
	if character_visual != null:
		character_visual.cancel_attack()

func activate_ability(ability_id: StringName) -> bool:
	if ability_id == &"heavy_strike":
		ability_id = &"heavy"
	if not alive or stun_remaining > 0.0 or action_state != &"ready" or strike_remaining > 0.0 or not ability_cooldowns.has(ability_id) or ability_cooldowns[ability_id] > 0.0:
		return false
	_interrupt_healing(&"ability")
	action_state = ability_id
	match ability_id:
		&"dash":
			action_remaining = _tuning("dash_duration", 0.15)
			ability_cooldowns[ability_id] = _tuning("dash_cooldown", 5.0)
		&"guard":
			action_remaining = _tuning("guard_duration", 0.6)
			ability_cooldowns[ability_id] = _tuning("guard_cooldown", 5.0)
		&"heavy":
			action_remaining = _tuning("heavy_windup", 0.6)
			ability_cooldowns[ability_id] = _tuning("heavy_cooldown", 7.0)
	game.session.publish({"type": "ability", "entity_id": match_id, "commander_id": commander_id, "ability_id": String(ability_id), "direction": [facing.x, facing.y]})
	return true

func _interrupt_healing(reason: StringName) -> void:
	if not healing:
		return
	healing = false
	game.session.publish({"type": "healing_interrupt", "entity_id": match_id, "reason": String(reason)})

func _resolve_heavy() -> void:
	var victim: CombatEntity = null
	var nearest: float = INF
	for candidate in game.session.actors.values():
		if not valid_enemy(candidate) or edge_distance(candidate) > attack_range or not game.navigation.clear_line(global_position, candidate.global_position):
			continue
		var heading: Vector2 = global_position.direction_to(candidate.global_position)
		if absf(facing.angle_to(heading)) > deg_to_rad(_tuning("heavy_cone_degrees", 50.0) * 0.5):
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < nearest:
			nearest = distance
			victim = candidate
	if victim != null:
		var guarded: bool = victim.has_method("guards_from") and victim.guards_from(global_position)
		victim.take_damage(_tuning("heavy_damage", 48.0), team.team_id, commander_id, global_position)
		if is_instance_valid(victim) and victim.alive and not guarded:
			victim.apply_stun(_tuning("heavy_stun", 0.5))
		game.session.publish({"type": "heavy_hit", "entity_id": match_id, "target_id": victim.match_id, "guarded": guarded})

func guards_from(source_position: Vector2) -> bool:
	return action_state == &"guard" and source_position.is_finite() and absf(facing.angle_to(global_position.direction_to(source_position))) <= deg_to_rad(_tuning("guard_cone_degrees", 120.0) * 0.5)

func take_damage(amount: float, attacker_team_id: int, source_commander_id: int = 0, source_position: Vector2 = Vector2(INF, INF)) -> void:
	if alive and team.is_enemy(attacker_team_id) and amount > 0.0:
		_interrupt_healing(&"damage")
		if guards_from(source_position):
			if character_visual != null:
				character_visual.note_block()
			amount *= 1.0 - _tuning("guard_damage_reduction", 0.7)
	super.take_damage(amount, attacker_team_id, source_commander_id, source_position)

func _step_action(delta: float) -> void:
	if stun_remaining > 0.0:
		cancel_action()
		return
	if healing:
		if global_position.distance_to(team.base_position) > _tuning("base_heal_radius", 180.0):
			_interrupt_healing(&"range")
		else:
			health = minf(max_health, health + _tuning("base_heal_rate", 30.0) * delta)
			if health >= max_health:
				healing = false
				game.session.publish({"type": "healing_complete", "entity_id": match_id})
	if action_state == &"ready":
		return
	var elapsed: float = minf(delta, action_remaining)
	if action_state == &"dash":
		global_position = game.navigation.move(global_position, facing * _tuning("dash_distance", 150.0) / _tuning("dash_duration", 0.15) * elapsed, body_radius)
	action_remaining = maxf(0.0, action_remaining - delta)
	if action_remaining <= 0.0:
		if action_state == &"recovery":
			action_state = &"ready"
		else:
			var was_heavy: bool = action_state == &"heavy"
			if was_heavy:
				note_visual_attack(facing, true)
				_resolve_heavy()
			action_state = &"recovery"
			action_remaining = _tuning("heavy_recovery", 0.45) if was_heavy else _tuning("ability_recovery", 0.2)


func _ready() -> void:
	category = &"commander"
	super._ready()
	kind = &"player"
	owner_commander_id = commander_id
	max_health = game.balance.commander_health
	health = max_health
	damage = 24.0
	attack_range = 65.0
	attack_cooldown = 0.55
	move_speed = 230.0
	body_radius = 18.0
	facing = Vector2.RIGHT if team.base_position.x < game.MAP_SIZE.x * 0.5 else Vector2.LEFT
	$Camera2D.enabled = human_controlled and game.presentation_enabled
	if human_controlled:
		z_index = 2
	$Camera2D.limit_left = 0
	$Camera2D.limit_top = 0
	$Camera2D.limit_right = int(game.MAP_SIZE.x)
	$Camera2D.limit_bottom = int(game.MAP_SIZE.y)
	$Camera2D.offset = Vector2.ZERO
	$Camera2D.zoom = Vector2.ONE * 0.9

func step_gameplay(delta: float) -> void:
	for ability_id in ability_cooldowns:
		ability_cooldowns[ability_id] = maxf(0.0, float(ability_cooldowns[ability_id]) - delta)
	rally_cooldown = maxf(0.0, rally_cooldown - delta)
	if not alive:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			cancel_action()
			stun_remaining = 0.0
			stun_immunity = 0.0
			for ability_id in ability_cooldowns:
				ability_cooldowns[ability_id] = 0.0
			alive = true
			health = max_health
			cooldown = 0.0
			strike_target = null
			strike_remaining = 0.0
			travel_path.clear()
			path_goal = Vector2(INF, INF)
			if controller.has_method("reset_orders"):
				controller.reset_orders()
			global_position = spawn_position
			if character_visual != null:
				character_visual.reset(global_position, true)
			add_to_group("combatants")
			game.session.publish({"type": "commander_return", "team": team.team_id, "commander_id": commander_id, "entity_id": match_id, "position": [position.x, position.y]})
			show()
			game.spawn_effect(global_position, team.color, "spawn")
			if human_controlled:
				game.notify("COMMANDER_RETURNED")
				game.play_sound(&"respawn")
				$Camera2D.reset_smoothing()
		return
	tick(delta)
	_step_action(delta)
	if strike_remaining > 0.0:
		strike_remaining -= delta
		if strike_remaining <= 0.0:
			_resolve_strike()
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	if controller != null:
		controller.drive(self, delta)

func attack(target: CombatEntity) -> void:
	if not alive or stun_remaining > 0.0 or action_state != &"ready" or cooldown > 0.0 or strike_remaining > 0.0 or not valid_enemy(target):
		return
	if edge_distance(target) > attack_range or not game.navigation.clear_line(global_position, target.global_position):
		return
	_interrupt_healing(&"attack")
	strike_target = target
	strike_remaining = game.balance.commander_strike_windup
	queue_redraw()

func _resolve_strike() -> void:
	if valid_enemy(strike_target) and edge_distance(strike_target) <= attack_range and game.navigation.clear_line(global_position, strike_target.global_position):
		super.attack(strike_target)
	else:
		var heading: Vector2 = global_position.direction_to(strike_target.global_position) if is_instance_valid(strike_target) else facing
		note_visual_attack(heading)
		# Dodging a committed strike creates a real opening for the opponent.
		cooldown = attack_cooldown
	strike_target = null
	queue_redraw()

func _draw() -> void:
	super._draw()
	if action_state in [&"heavy", &"guard"]:
		var half_angle: float = deg_to_rad(25.0 if action_state == &"heavy" else 60.0)
		draw_arc(Vector2.ZERO, attack_range + body_radius, facing.angle() - half_angle, facing.angle() + half_angle, 20, Color("ffae55") if action_state == &"heavy" else Color("90dfff"), 4.0, true)
	if healing:
		draw_arc(Vector2.ZERO, body_radius + 12.0, -PI / 2.0, -PI / 2.0 + TAU * health / max_health, 24, Color("99efb0"), 3.0, true)
	if human_controlled and controller != null and valid_enemy(controller.target):
		var selected: CombatEntity = controller.target
		draw_arc(to_local(selected.global_position), selected.body_radius + 9.0, 0.0, TAU, 24, Color("f6e4a6", 0.75), 2.0, true)
	if strike_remaining > 0.0 and valid_enemy(strike_target):
		var heading: float = global_position.angle_to_point(strike_target.global_position)
		var progress: float = 1.0 - strike_remaining / game.balance.commander_strike_windup
		draw_arc(Vector2.ZERO, attack_range + body_radius, heading - 0.55, heading + 0.55, 18, Color("f6d390", 0.30 + 0.60 * progress), 3.0, true)
	if human_controlled and controller != null and valid_enemy(controller.focus_target):
		var selected: CombatEntity = controller.focus_target
		draw_arc(to_local(selected.position), selected.body_radius + 13.0, 0.0, TAU, 24, Color.WHITE, 3.0, true)

# Camera state is presentation-only; it never enters the command stream.
func scout_camera(world_position: Vector2) -> void:
	if not human_controlled or not game.presentation_enabled:
		return
	scouting = true
	scouting_target = world_position
	update_scout_camera()

func update_scout_camera() -> void:
	if not scouting:
		return
	var camera: Camera2D = $Camera2D
	var half_view := get_viewport_rect().size / camera.zoom * 0.5
	var center := scouting_target
	for axis in range(2):
		center[axis] = game.MAP_SIZE[axis] * 0.5 if half_view[axis] * 2.0 >= game.MAP_SIZE[axis] else clampf(center[axis], half_view[axis], game.MAP_SIZE[axis] - half_view[axis])
	camera.position = center - global_position

func end_camera_scouting(immediate: bool = false) -> void:
	scouting = false
	$Camera2D.position = Vector2.ZERO
	if immediate:
		$Camera2D.reset_smoothing()

func update_movement_facing(direction: Vector2) -> void:
	if alive and stun_remaining <= 0.0 and action_state == &"ready" and direction.is_finite() and direction.length_squared() > 0.001:
		facing = direction.normalized()

func apply_input(values: Dictionary) -> void:
	var direction: Vector2 = values.get("direction", Vector2.ZERO)
	var moving: bool = direction.length_squared() > 0.001 or (values.has("goal") and global_position.distance_to(values.goal) > 4.0)
	if moving:
		_interrupt_healing(&"movement")
	if bool(values.get("attack", false)):
		_interrupt_healing(&"attack")
	if stun_remaining > 0.0 or action_state == &"dash" or healing:
		return
	var heading: Vector2 = global_position.direction_to(values.goal) if values.has("goal") and moving else direction
	update_movement_facing(heading)
	var original_speed: float = move_speed
	if action_state == &"guard":
		move_speed *= _tuning("guard_move_multiplier", 0.35)
	elif action_state == &"heavy":
		move_speed *= _tuning("heavy_move_multiplier", 0.25)
	if values.has("goal"):
		var normal_speed := move_speed
		move_speed = minf(move_speed, float(values.get("speed_limit", move_speed)))
		travel_toward(values.goal, float(values.get("delta", MatchSession.STEP)))
		move_speed = normal_speed
	else:
		global_position = game.navigation.move(global_position, direction.limit_length(1.0) * effective_move_speed() * float(values.get("delta", MatchSession.STEP)), body_radius)
	move_speed = original_speed
	if bool(values.get("attack", false)):
		var selected = values.get("target")
		if not valid_enemy(selected) or edge_distance(selected) > attack_range:
			selected = closest_enemy(attack_range)
		if human_controlled:
			controller.target = selected
		if selected != null:
			attack(selected)
	else:
		if human_controlled:
			controller.target = null
	if bool(values.get("interact", false)):
		interact()

func interact() -> void:
	if human_controlled and game.hud != null and game.nearest_pad(self) != null:
		game.hud.focus_build_pad()
		return
	if global_position.distance_to(team.base_position) <= _tuning("base_heal_radius", 180.0):
		base_interacted.emit()
		if heal_cooldown <= 0.0 and health < max_health and action_state == &"ready" and stun_remaining <= 0.0:
			healing = true
			game.session.publish({"type": "healing_start", "entity_id": match_id})
			heal_cooldown = game.balance.base_heal_cooldown
			if human_controlled:
				game.notify("HEALED")
	elif human_controlled:
		game.notify("APPROACH_KING")

func die() -> void:
	game.spawn_character_remnant(self)
	cancel_action()
	game.spawn_effect(global_position, team.color, "death")
	alive = false
	game.session.publish({"type": "death", "team": team.team_id, "kind": String(kind), "entity_id": match_id, "position": [position.x, position.y], "commander_id": commander_id})
	if controller.has_method("reset_touch"):
		controller.reset_touch()
	if controller.has_method("reset_orders"):
		controller.reset_orders()
	strike_target = null
	strike_remaining = 0.0
	remove_from_group("combatants")
	respawn_remaining = game.balance.commander_respawn
	tactical_status = "STATUS_RESPAWNING"
	hide()
	if human_controlled:
		end_camera_scouting(true)
		game.play_sound(&"commander_death")
		game.notify("COMMANDER_DOWN", [int(respawn_remaining)])

func _unhandled_input(event: InputEvent) -> void:
	if not human_controlled or get_tree().paused:
		return
	if event.is_echo():
		return
	if event.is_action_pressed("rally"):
		game.session.submit(MatchCommand.new(MatchCommand.Action.RALLY, commander_id))
	elif event.is_action_pressed("regroup"):
		game.session.submit(MatchCommand.new(MatchCommand.Action.REGROUP, commander_id))
	if event is InputEventMouseButton and event.pressed:
		var change: float = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change = 0.05
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change = -0.05
		$Camera2D.zoom = Vector2.ONE * clampf($Camera2D.zoom.x + change, 0.7, 1.1)
		update_scout_camera()
