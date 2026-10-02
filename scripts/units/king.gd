extends CombatEntity

var danger_remaining: float = 0.0
var damage_window: float = 0.0
var recent_damage: float = 0.0
var last_alarm: float = -20.0


func _ready() -> void:
	category = &"structure"
	super._ready()
	kind = &"king"
	body_radius = 32.0
	team.upgrades_changed.connect(_apply_upgrades)
	_apply_upgrades()
	health = max_health


func _apply_upgrades() -> void:
	var old_max: float = max_health
	max_health = team.get_stat(&"king_health")
	health = minf(max_health, health + max_health - old_max)
	damage = team.get_stat(&"king_damage")
	attack_cooldown = 1.0 / team.get_stat(&"king_attack_speed")
	attack_range = team.get_stat(&"king_range")
	queue_redraw()


func step_gameplay(delta: float) -> void:
	if not alive:
		return
	tick(delta)
	danger_remaining = maxf(0.0, danger_remaining - delta)
	damage_window = maxf(0.0, damage_window - delta)
	if damage_window <= 0:
		recent_damage = 0.0
	if cooldown <= 0.0:
		var target: CombatEntity = closest_enemy(attack_range)
		if target != null:
			attack(target)


func _draw() -> void:
	if team != null:
		draw_arc(
			Vector2.ZERO, attack_range + body_radius, 0.0, TAU, 64, Color(team.color, 0.14), 2.0
		)
	super._draw()

func take_damage(amount: float, attacker_team_id: int, source_commander_id: int = 0, source_position: Vector2 = Vector2.INF) -> void:
	if game.tutorial != null and team.team_id == 2 and game.tutorial.stage != TutorialDirector.Stage.KING:
		return
	if not alive or not team.is_enemy(attacker_team_id) or amount <= 0:
		return
	recent_damage += amount
	damage_window = 6.0
	super.take_damage(amount, attacker_team_id, source_commander_id, source_position)
	if alive and (recent_damage >= max_health * 0.07 or health < max_health * 0.35):
		danger_remaining = 6.0
		if game.coordination != null:
			game.coordination.alert(&"king_danger", team.team_id, position)
		if game.match_seconds - last_alarm > 15.0:
			last_alarm = game.match_seconds
			if team == game.player.team:
				game.play_sound(&"king_warning")
				game.notify("KING_DANGER")

func die() -> void:
	game.play_sound(&"king_death")
	game.spawn_effect(position, team.color, "crownfall")
	super.die()
