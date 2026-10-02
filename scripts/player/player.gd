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
	rally_cooldown = maxf(0.0, rally_cooldown - delta)
	if not alive:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
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
	if strike_remaining > 0.0:
		strike_remaining -= delta
		if strike_remaining <= 0.0:
			_resolve_strike()
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	if controller != null:
		controller.drive(self, delta)

func attack(target: CombatEntity) -> void:
	if not alive or cooldown > 0.0 or strike_remaining > 0.0 or not valid_enemy(target):
		return
	if edge_distance(target) > attack_range or not game.navigation.clear_line(global_position, target.global_position):
		return
	strike_target = target
	strike_remaining = game.balance.commander_strike_windup
	queue_redraw()

func _resolve_strike() -> void:
	if valid_enemy(strike_target) and edge_distance(strike_target) <= attack_range and game.navigation.clear_line(global_position, strike_target.global_position):
		super.attack(strike_target)
	else:
		# Dodging a committed strike creates a real opening for the opponent.
		cooldown = attack_cooldown
	strike_target = null
	queue_redraw()

func _draw() -> void:
	super._draw()
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

func apply_input(values: Dictionary) -> void:
	var direction: Vector2 = values.get("direction", Vector2.ZERO)
	if values.has("goal"):
		var normal_speed := move_speed
		move_speed = minf(move_speed, float(values.get("speed_limit", move_speed)))
		travel_toward(values.goal, float(values.get("delta", MatchSession.STEP)))
		move_speed = normal_speed
	else:
		global_position = game.navigation.move(global_position, direction.limit_length(1.0) * move_speed * float(values.get("delta", MatchSession.STEP)), body_radius)
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
	if global_position.distance_to(team.base_position) <= 180.0:
		base_interacted.emit()
		if heal_cooldown <= 0.0:
			health = max_health
			heal_cooldown = game.balance.base_heal_cooldown
			if human_controlled:
				game.notify("HEALED")
	elif human_controlled:
		game.notify("APPROACH_KING")

func die() -> void:
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
