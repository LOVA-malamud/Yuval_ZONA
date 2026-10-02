extends CombatEntity
var level: int = 1
var pad = null
var definition: TowerDefinition

func _ready() -> void:
	category = &"structure"
	super._ready()
	kind = &"tower"
	body_radius = 28.0
	if definition == null:
		definition = load("res://resources/towers/guard.tres").duplicate(true)
	max_health = definition.max_health
	health = max_health
	damage = definition.damage
	attack_range = definition.attack_range
	attack_cooldown = definition.attack_cooldown

func tower_id() -> StringName:
	return definition.id if definition != null else &"guard"

func step_gameplay(delta: float) -> void:
	if not alive:
		return
	tick(delta)
	if cooldown <= 0:
		var target: CombatEntity = _target_in_range()
		if target != null:
			attack(target)

func _target_in_range() -> CombatEntity:
	var best: CombatEntity = null
	var nearest: float = attack_range
	for candidate in game.session.actors.values():
		if not valid_enemy(candidate):
			continue
		var distance: float = edge_distance(candidate)
		if distance >= definition.minimum_range and distance <= nearest and game.navigation.clear_line(global_position, candidate.global_position):
			best = candidate
			nearest = distance
	return best

func attack(target: CombatEntity) -> void:
	if definition == null or edge_distance(target) < definition.minimum_range:
		return
	if definition.splash_radius <= 0.0:
		super.attack(target)
		return
	if not alive or cooldown > 0.0 or not valid_enemy(target) or edge_distance(target) > attack_range or not game.navigation.clear_line(global_position, target.global_position):
		return
	cooldown = attack_cooldown
	shot_time = 0.22
	shot_end = target.global_position
	game.play_sound(&"tower_fire", global_position)
	game.spawn_effect(shot_end, team.color, "impact")
	# Snapshot protects iteration when a blast kills and unregisters an actor.
	for candidate in game.session.actors.values().duplicate():
		if valid_enemy(candidate) and candidate.global_position.distance_to(shot_end) <= definition.splash_radius + candidate.body_radius and game.navigation.clear_line(shot_end, candidate.global_position):
			candidate.take_damage(damage, team.team_id, owner_commander_id, global_position)
	queue_redraw()

func upgrade_cost() -> Vector2i:
	return Vector2i(100 * level, 65 * level)

func apply_upgrade() -> void:
	if level >= 3:
		return
	level += 1
	var bonus_health: float = 160.0 if tower_id() == &"guard" else 120.0
	max_health += bonus_health
	health = minf(max_health, health + bonus_health)
	if tower_id() == &"guard":
		damage += 6.0
		attack_range += 20.0
		attack_cooldown = maxf(0.8, attack_cooldown - 0.12)
	else:
		damage += definition.damage * 0.25
	queue_redraw()

func _draw() -> void:
	super._draw()
	if team == null or not alive:
		return
	# Additional crowns distinguish roles without depending on color or labels.
	if tower_id() == &"splash":
		draw_circle(Vector2(0, -58), 17, Color("35434a"))
		draw_circle(Vector2(0, -58), 11, Color("101d26"))
		draw_arc(Vector2(0, -58), 17, 0, TAU, 24, ART.GOLD, 3)
	elif tower_id() == &"long_range":
		draw_colored_polygon(PackedVector2Array([Vector2(-13,-54), Vector2(0,-83), Vector2(13,-54)]), team.color)
		draw_line(Vector2(-23,-65), Vector2(23,-65), ART.GOLD, 5)
		draw_line(Vector2(0,-80), Vector2(0,-49), Color("efdfb8"), 3)

func die() -> void:
	game.play_sound(&"tower_destroy", global_position)
	game.spawn_effect(global_position, team.color, "rubble")
	super.die()
