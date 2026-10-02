extends SceneTree
var failures := 0
var checks := 0
var game

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.presentation_enabled = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	check(Engine.physics_ticks_per_second == 60, "Production physics clock is pinned to 60 Hz")
	check(game.hud == null and game.effect_count == 0 and game.get_node_or_null("Battlefield") == null, "Presentation-disabled session owns no HUD, effects or battlefield")
	var results := {}
	game.session.command_completed.connect(func(id, result): results[id] = result)
	var wallet: int = game.teams[0].money
	var bad: CommandResult = game.session.execute(MatchCommand.new(MatchCommand.Action.INPUT, 1, {"direction": NAN}))
	check(not bad.success, "Malformed input rejected without script errors")
	bad = game.session.execute(MatchCommand.new(MatchCommand.Action.INPUT, 1, {"goal": Vector2(INF, 0)}))
	check(not bad.success, "Non-finite AI destination rejected")
	bad = game.session.execute(MatchCommand.new(MatchCommand.Action.INPUT, 1, {"speed_limit": -1}))
	check(not bad.success, "Invalid AI movement limit rejected")
	bad = game.session.execute(MatchCommand.new(MatchCommand.Action.BUILD, 1, {"pad": 9}))
	check(not bad.success, "Malformed build target rejected without script errors")
	var invalid: int = game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 99, {"id": &"melee", "route": 1}))
	var route: int = game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 1, {"id": &"melee", "route": 99}))
	game.session.step()
	check(not results[invalid].success and not results[route].success and game.teams[0].money == wallet, "Invalid actor and route cannot spend resources")
	game.teams[0].money = 50
	var first: int = game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 1, {"id": &"melee", "route": 1}))
	var second: int = game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 2, {"id": &"melee", "route": 1}))
	game.session.step()
	check(results[first].success and not results[second].success and game.teams[0].combat_count == 1 and game.teams[0].money == 0, "FIFO teammates cannot double spend")
	var cancelled: int = game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 1, {"id": &"worker", "route": 1}))
	game.session.pause()
	check(results[cancelled].reason == &"cancelled", "Pause completes queued commands as cancelled")
	var rejected: int = game.session.submit(MatchCommand.new(MatchCommand.Action.RALLY, 1))
	check(results[rejected].reason == &"invalid_state", "Paused submissions complete immediately")
	var ticks: int = game.session.ticks
	game.session.step()
	check(game.session.ticks == ticks, "Paused session cannot advance time")
	game.session.resume()
	game.session.step()
	check(game.session.ticks == ticks + 1 and is_equal_approx(game.match_seconds, game.session.ticks / 60.0), "Resume advances one fixed tick")
	game.teams[1].king.take_damage(99999, 1)
	check(game.session.state == MatchSession.State.FINISHED, "King defeat finishes lifecycle")
	game.session.step()
	check(game.session.ticks == ticks + 1, "Finished match cannot advance")
	paused = false
	game.free()
	await process_frame
	check(get_nodes_in_group("combatants").is_empty() and get_nodes_in_group("projectiles").is_empty(), "Teardown releases match actors")
	print("SESSION COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
