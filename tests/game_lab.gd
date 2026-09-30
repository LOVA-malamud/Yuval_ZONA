extends SceneTree
## Fast, text-only scenarios using the real commander and navigation scripts.

const DT: float = 1.0 / 60.0
var game
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LAB FAIL: " + name)


func _step(frames: int) -> void:
	for _frame in range(frames):
		game.player._physics_process(DT)


func _run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	var actor = game.player
	var control = actor.controller
	for entity in get_nodes_in_group("combatants"):
		if entity != actor:
			entity.remove_from_group("combatants")

	actor.position = Vector2(900, 1300)
	control.set_scripted_command(Vector2.RIGHT, false)
	_step(60)
	var travel: float = actor.position.x - 900.0
	metrics["open_travel_1s"] = snappedf(travel, 0.01)
	_check(absf(travel - actor.move_speed) < 1.0, "full-speed open travel")
	control.set_scripted_command(Vector2.ZERO, false)
	var stopped: Vector2 = actor.position
	_step(30)
	_check(actor.position.distance_to(stopped) < 0.01, "release stops movement")

	actor.position = Vector2(1200, 900)
	control.set_scripted_command(Vector2.RIGHT, false)
	_step(60)
	metrics["wall_stop_x"] = snappedf(actor.position.x, 0.01)
	_check(actor.position.x <= 1300.0 - actor.body_radius + 0.1, "solid terrain stops the body")
	control.set_scripted_command(Vector2(1, 1), false)
	var before_slide: Vector2 = actor.position
	_step(60)
	metrics["wall_slide_y"] = snappedf(actor.position.y - before_slide.y, 0.01)
	_check(actor.position.y > before_slide.y + 100.0, "diagonal input slides along terrain")
	_check(game.navigation.walkable(actor.position, actor.body_radius), "slide remains walkable")

	actor.position = Vector2(900, 1300)
	control.clear_scripted_command()
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = Vector2(120, 320)
	touch.pressed = true
	control._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = Vector2(200, 320)
	control._input(drag)
	_step(30)
	metrics["touch_travel_0_5s"] = snappedf(actor.position.x - 900.0, 0.01)
	_check(actor.position.x > 1000.0, "left-side touch drives commander")
	touch.pressed = false
	control._input(touch)
	stopped = actor.position
	_step(10)
	_check(actor.position.distance_to(stopped) < 0.01, "touch release stops commander")
	var right_touch := InputEventScreenTouch.new()
	right_touch.index = 8
	right_touch.position = Vector2(1050, 320)
	right_touch.pressed = true
	control._unhandled_input(right_touch)
	_check(control.touch_index == -1, "right-side touch leaves movement free for UI")
	touch.pressed = true
	control._unhandled_input(touch)
	game.hud._toggle_pause()
	_check(control.touch_index == -1 and control.touch_direction == Vector2.ZERO, "pause clears held movement")
	game.hud._toggle_pause()

	var foe = game.UNIT_SCENE.instantiate()
	foe.configure(game.teams[1], game, game.unit_data[&"tank"])
	foe.position = actor.position + Vector2(45, 0)
	game.entities.add_child(foe)
	var hp_before: float = foe.health
	touch.pressed = true
	control._unhandled_input(touch)
	control._input(drag)
	_step(10)
	_check(foe.health < hp_before, "movement touch attacks automatically")
	touch.pressed = false
	control._input(touch)
	actor.cooldown = 0.0
	actor.strike_remaining = 0.0
	actor.strike_target = null
	foe.position = actor.position + Vector2(45, 0)
	hp_before = foe.health
	stopped = actor.position
	control.set_scripted_command(Vector2.RIGHT, true)
	_step(10)
	metrics["move_attack_damage"] = snappedf(hp_before - foe.health, 0.01)
	_check(foe.health < hp_before and actor.position.x > stopped.x, "attack while moving")
	_check(control.target == foe, "valid target remains selected")
	foe.position = actor.position + Vector2(500, 0)
	_step(1)
	_check(control.target == null, "out-of-range target clears")
	# A committed strike can be escaped before its impact frame.
	actor.position = Vector2(900, 1300)
	foe.position = Vector2(945, 1300)
	actor.cooldown = 0.0
	control.set_scripted_command(Vector2.ZERO, true)
	_step(1)
	_check(actor.strike_remaining > 0.0, "commander strike has a windup")
	hp_before = foe.health
	foe.position = Vector2(1150, 1300)
	_step(10)
	metrics["dodged_damage"] = snappedf(hp_before - foe.health, 0.01)
	_check(is_equal_approx(foe.health, hp_before), "moving out of range dodges a committed strike")
	_check(actor.cooldown > 0.0, "missed strike still spends its cooldown")

	var archer = game.UNIT_SCENE.instantiate()
	archer.configure(game.teams[1], game, game.unit_data[&"ranged"])
	archer.position = Vector2(1070, 1300)
	game.entities.add_child(archer)
	actor.position = Vector2(900, 1300)
	actor.health = actor.max_health
	control.set_scripted_command(Vector2.DOWN, false)
	archer.attack(actor)
	hp_before = actor.health
	for _frame in range(30):
		_step(1)
		for projectile in get_nodes_in_group("projectiles"):
			if not projectile.is_queued_for_deletion():
				projectile._physics_process(DT)
	metrics["ranged_dodge_damage"] = snappedf(hp_before - actor.health, 0.01)
	_check(is_equal_approx(actor.health, hp_before), "lateral movement evades aimed ranged shot")
	actor.position = Vector2(900, 1300)
	control.set_scripted_command(Vector2.ZERO, false)
	archer.cooldown = 0.0
	archer.attack(actor)
	hp_before = actor.health
	for _frame in range(30):
		_step(1)
		for projectile in get_nodes_in_group("projectiles"):
			if not projectile.is_queued_for_deletion():
				projectile._physics_process(DT)
	metrics["stationary_ranged_damage"] = snappedf(hp_before - actor.health, 0.01)
	_check(actor.health < hp_before, "stationary commander is hit by ranged shot")
	actor.position = actor.team.base_position
	actor.health = actor.max_health - 30.0
	control.set_scripted_command(Vector2.ZERO, false, true)
	_step(1)
	_check(is_equal_approx(actor.health, actor.max_health), "scripted interaction uses the real King heal")
	control.reset_touch()
	_check(control.touch_index == -1 and control.touch_direction == Vector2.ZERO, "touch reset clears movement")
	control.clear_scripted_command()

	var report := {"suite": "movement", "checks": checks, "failures": failures, "metrics": metrics}
	print("LAB_REPORT ", JSON.stringify(report))
	root.get_node("AudioFeedback").stop_all()
	quit(1 if failures > 0 else 0)
