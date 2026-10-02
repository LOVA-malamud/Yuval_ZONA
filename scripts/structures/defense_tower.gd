extends CombatEntity
var level: int = 1
var pad = null

func _ready() -> void:
	category = &"structure"
	super._ready()
	kind = &"tower"
	body_radius = 28.0
	max_health = game.balance.tower_health
	health = max_health
	damage = game.balance.tower_damage
	attack_range = game.balance.tower_range
	attack_cooldown = game.balance.tower_cooldown

func step_gameplay(delta: float) -> void:
	if not alive:
		return
	tick(delta)
	if cooldown <= 0:
		var target: CombatEntity = closest_enemy(attack_range)
		if target != null:
			attack(target)

func upgrade_cost() -> Vector2i:
	return Vector2i(100 * level, 65 * level)

func apply_upgrade() -> void:
	level += 1
	max_health += 160.0
	health = minf(max_health, health + 160.0)
	damage += 6.0
	attack_range += 20.0
	attack_cooldown = maxf(0.8, attack_cooldown - 0.12)
	queue_redraw()

func die() -> void:
	game.play_sound(&"tower_destroy", global_position)
	game.spawn_effect(global_position, team.color, "rubble")
	super.die()
