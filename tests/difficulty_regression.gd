extends SceneTree
## Difficulty changes tactical behavior while preserving the starting economy/stats.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var reference := {}
	var intervals := {}
	for difficulty in [&"easy", &"standard", &"hard"]:
		var game = load("res://scenes/main/main.tscn").instantiate()
		game.presentation_enabled = false
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.simulation_config = {"shared": {"difficulty": String(difficulty)}}
		root.add_child(game)
		var starting := {}
		for team in game.teams:
			starting[team.team_id] = [team.money, team.wood, team.worker_count, team.stats.duplicate(true)]
		if reference.is_empty():
			reference = starting
		elif starting != reference:
			push_error("Difficulty changed starting resources or stats")
			failures += 1
		var ally = game.commanders[1]
		ally.controller.decision_timer = 0.0
		ally.controller.step_gameplay(MatchSession.STEP)
		intervals[difficulty] = ally.controller.decision_timer
		game.teams[0].money = 1000
		for index in range(6):
			game.purchase(1, &"melee", false, 1)
			var unit = game.entities.get_child(game.entities.get_child_count() - 1)
			unit.position = ally.position + Vector2(index * 20, 0)
		ally.controller.drive(ally, MatchSession.STEP)
		var rallies: int = game.coordination.commander_stats[2].rallies
		if rallies != (1 if difficulty == &"hard" else 0):
			push_error("Difficulty rally coordination mismatch: %s" % difficulty)
			failures += 1
		game.free()
		await process_frame
	if not intervals.easy > intervals.standard or not intervals.standard > intervals.hard:
		push_error("Difficulty decision cadence is not ordered")
		failures += 1
	print("DIFFICULTY cadence=", intervals, " failures=", failures)
	quit(1 if failures else 0)
