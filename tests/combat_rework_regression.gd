extends SceneTree
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	var actor = game.commanders[0]
	actor.controller.set_scripted_command(Vector2.ZERO, false)
	actor.position = actor.team.base_position
	actor.health = 60.0
	actor.interact()
	check(actor.healing and actor.health == 60.0 and actor.heal_cooldown > 0.0, "Healing starts channel and consumes cooldown without instant recovery")
	actor.step_gameplay(1.0)
	check(is_equal_approx(actor.health, 60.0 + game.balance.base_heal_rate), "Healing restores the configured health rate")
	actor.apply_input({"direction": Vector2.RIGHT, "delta": 0.05})
	check(not actor.healing and actor.heal_cooldown > 0.0, "Movement interrupts healing and preserves cooldown")
	actor.heal_cooldown = 0.0
	actor.health = actor.max_health
	actor.interact()
	check(not actor.healing and actor.heal_cooldown == 0.0, "Full health interaction costs no cooldown")
	actor.health = 0.0
	actor.interact()
	actor.step_gameplay(6.0)
	check(actor.health == actor.max_health and not actor.healing, "Configured healing completes empty to full in six seconds")
	actor.heal_cooldown = 0.0
	actor.health = 60.0
	actor.interact()
	actor.take_damage(1.0, game.teams[1].team_id)
	check(not actor.healing, "Enemy damage interrupts healing")
	actor.heal_cooldown = 0.0
	actor.interact()
	actor.activate_ability(&"dash", Vector2.RIGHT)
	check(not actor.healing, "Ability interrupts healing")
	actor.cancel_action()
	actor.position = Vector2(650, 1410)
	var start: Vector2 = actor.position
	actor.ability_cooldowns[&"dash"] = 0.0
	check(actor.activate_ability(&"dash", Vector2.RIGHT), "Dash activation accepted")
	for step in range(3):
		actor.step_gameplay(0.05)
	check(is_equal_approx(actor.position.distance_to(start), 150.0), "Dash moves 150 units through open terrain")
	check(actor.action_state == &"recovery" and not actor.activate_ability(&"guard", Vector2.RIGHT), "Dash has committed recovery")
	actor.cancel_action()
	actor.health = actor.max_health
	actor.activate_ability(&"guard", Vector2.RIGHT)
	actor.take_damage(20.0, game.teams[1].team_id, 0, actor.position + Vector2.RIGHT * 30.0)
	check(is_equal_approx(actor.health, actor.max_health - 6.0), "Frontal guard reduces damage by 70 percent")
	actor.take_damage(20.0, game.teams[1].team_id, 0, actor.position - Vector2.RIGHT * 30.0)
	check(is_equal_approx(actor.health, actor.max_health - 26.0), "Rear attacks bypass guard")
	actor.cancel_action()
	var foe = game.commanders[2]
	foe.position = actor.position + Vector2.RIGHT * 65.0
	foe.cancel_action()
	foe.health = foe.max_health
	check(actor.activate_ability(&"heavy", Vector2.RIGHT), "Heavy windup accepted")
	actor.step_gameplay(0.3)
	check(foe.health == foe.max_health, "Heavy strike cannot hit before committed windup")
	actor.step_gameplay(0.31)
	check(is_equal_approx(foe.health, foe.max_health - 48.0) and foe.stun_remaining > 0.0, "Heavy hits for 48 and briefly stuns")
	foe.tick(0.5)
	check(foe.stun_immunity > 0.0 and not foe.apply_stun(0.5), "Post stun immunity prevents chained lockdown")
	actor.cancel_action()
	actor.ability_cooldowns[&"heavy"] = 0.0
	foe.position = actor.position + Vector2.UP * 65.0
	var before: float = foe.health
	actor.activate_ability(&"heavy", Vector2.RIGHT)
	actor.step_gameplay(0.61)
	check(foe.health == before and actor.action_state == &"recovery", "Narrow heavy strike misses outside cone and still recovers")
	actor.cancel_action()
	actor.ability_cooldowns[&"heavy"] = 0.0
	foe.position = actor.position + Vector2.RIGHT * 65.0
	foe.cancel_action()
	foe.ability_cooldowns[&"guard"] = 0.0
	foe.stun_immunity = 0.0
	foe.activate_ability(&"guard", Vector2.LEFT)
	actor.activate_ability(&"heavy", Vector2.RIGHT)
	actor.step_gameplay(0.61)
	check(foe.stun_remaining == 0.0, "Successful guard prevents heavy stun")
	actor.cancel_action()
	actor.ability_cooldowns[&"dash"] = 0.0
	var obstacle: Rect2 = game.navigation.obstacles[0]
	actor.position = Vector2(obstacle.position.x - actor.body_radius - 5.0, obstacle.get_center().y)
	actor.activate_ability(&"dash", Vector2.RIGHT)
	for step in range(3):
		actor.step_gameplay(0.05)
	check(actor.position.x <= obstacle.position.x - actor.body_radius + 1.0, "Dash clips before terrain and cannot cross walls")
	game.free()
	quit(1 if failures else 0)
