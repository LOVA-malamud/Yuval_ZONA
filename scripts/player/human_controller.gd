extends Node
## Input adapter. The commander owns health/movement; a future controller can replace this.

func drive(actor, delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	actor.global_position = actor.game.navigation.move(actor.global_position, direction * actor.move_speed * delta, actor.body_radius)
	if Input.is_action_pressed("attack"):
		var target: CombatEntity = actor.closest_enemy(actor.attack_range)
		if target != null:
			actor.attack(target)
	if Input.is_action_just_pressed("interact"):
		actor.interact()
