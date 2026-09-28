extends CombatEntity
## Persistent commander body, independent of its human/AI controller.

signal base_interacted

var commander_id: int = 0
var commander_name: String = "COMMANDER_DEFAULT"
var human_controlled: bool = false
var spawn_position: Vector2
var controller = null
var respawn_remaining: float = 0.0
var heal_cooldown: float = 0.0
var tactical_status: String = "STATUS_READY"

func _ready() -> void:
	super._ready()
	kind = &"player"
	max_health = game.balance.commander_health
	health = max_health
	damage = 24.0
	attack_range = 65.0
	attack_cooldown = 0.55
	move_speed = 230.0
	body_radius = 18.0
	$Camera2D.enabled = human_controlled
	if human_controlled:
		z_index = 2
	$Camera2D.limit_left = 0
	$Camera2D.limit_top = 0
	$Camera2D.limit_right = int(game.MAP_SIZE.x)
	$Camera2D.limit_bottom = int(game.MAP_SIZE.y)
	$Camera2D.offset = Vector2.ZERO
	$Camera2D.zoom = Vector2.ONE * 0.9

func _physics_process(delta: float) -> void:
	if not alive:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			alive = true
			health = max_health
			cooldown = 0.0
			travel_path.clear()
			path_goal = Vector2(INF, INF)
			if controller.has_method("reset_orders"):
				controller.reset_orders()
			global_position = spawn_position
			add_to_group("combatants")
			show()
			game.spawn_effect(global_position, team.color, "spawn")
			if human_controlled:
				game.notify("COMMANDER_RETURNED")
				AudioFeedback.play(&"respawn")
				$Camera2D.reset_smoothing()
		return
	tick(delta)
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	if controller != null:
		controller.drive(self, delta)

func interact() -> void:
	if human_controlled and game.nearest_pad(self) != null:
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
	remove_from_group("combatants")
	respawn_remaining = game.balance.commander_respawn
	tactical_status = "STATUS_RESPAWNING"
	hide()
	if human_controlled:
		AudioFeedback.play(&"commander_death")
		game.notify("COMMANDER_DOWN", [int(respawn_remaining)])

func _unhandled_input(event: InputEvent) -> void:
	if not human_controlled or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed:
		var change: float = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change = 0.05
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change = -0.05
		$Camera2D.zoom = Vector2.ONE * clampf($Camera2D.zoom.x + change, 0.7, 1.1)
