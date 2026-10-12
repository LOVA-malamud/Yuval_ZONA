extends SceneTree
## Isolated real AI duels: no armies, economy, or King damage influence outcomes.
const DT := 1.0 / 60.0
const ALL_ABILITIES := ["dash", "guard", "heavy", "feint"]
var runs: Array[Dictionary] = []
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
	var health_override: float = 0.0
	var seed_count: int = 5
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--health="):
			health_override = argument.trim_prefix("--health=").to_float()
		elif argument.begins_with("--seeds="):
			seed_count = argument.trim_prefix("--seeds=").to_int()
	for difficulty in [&"easy", &"standard", &"hard"]:
		for seed_value in range(42, 42 + seed_count):
			var game = load("res://scenes/main/main.tscn").instantiate()
			game.presentation_enabled = false
			game.process_mode = Node.PROCESS_MODE_DISABLED
			game.strategy_seed = seed_value
			game.rules = game.rules.duplicate(true)
			game.rules.difficulty = difficulty
			game.simulation_config = {"shared": {"difficulty": String(difficulty)}}
			if health_override > 0:
				game.simulation_config.shared["balance"] = {"commander_health":health_override}
			root.add_child(game)
			var a = game.commanders[1]
			var b = game.commanders[2]
			for actor in game.session.actors.values().duplicate():
				if actor != a and actor != b:
					game.session.unregister_actor(actor)
			a.position = Vector2(1120, 1350)
			b.position = Vector2(1260, 1350)
			var metrics := {"seed": seed_value, "difficulty": String(difficulty), "duration": 0.0, "outcome": "timeout", "light_hits": 0, "heavy_hits": 0, "guarded_heavy_hits": 0, "heavy_attempts": 0, "dashes": 0, "guards": 0, "feints": 0, "feint_resolves": 0, "stuns": 0, "damage": 0.0}
			var sink := func(event: Dictionary) -> void:
				var type: String = str(event.get("type", ""))
				if type == "ability":
					var id: String = str(event.get("ability_id", ""))
					if id == "dash": metrics.dashes += 1
					elif id == "guard": metrics.guards += 1
					elif id == "heavy": metrics.heavy_attempts += 1
					elif id == "feint": metrics.feints += 1
				elif type == "heavy_hit":
					metrics.heavy_hits += 1
					if event.get("guarded", false): metrics.guarded_heavy_hits += 1
				elif type == "feint_resolve":
					metrics.feint_resolves += 1
				elif type == "stun": metrics.stuns += 1
			game.session.match_event.connect(sink)
			var previous_health: float = a.health + b.health
			for frame in range(60 * 60):
				# AI-requested abilities gate on game.session.ticks advancing past the
				# tick they were requested on (see enemy_ai.gd::_use_combat_ability);
				# this loop drives commanders directly, bypassing MatchSession.step(),
				# so the clock must be advanced here or no AI ability ever resolves.
				game.session.ticks += 1
				game.match_seconds = game.session.ticks * DT
				a.step_gameplay(DT)
				b.step_gameplay(DT)
				var health_now: float = a.health + b.health
				if health_now < previous_health:
					metrics.damage += previous_health - health_now
					metrics.light_hits += 1
				previous_health = health_now
				metrics.duration = snappedf((frame + 1) * DT, 0.01)
				if not a.alive or not b.alive:
					metrics.outcome = "defeat"
					break
				if frame > 60 and a.position.distance_to(b.position) > 380.0:
					metrics.outcome = "escape"
					break
			# Damage frames can include heavy damage; report this honest aggregate name.
			metrics["heavy_unguarded_hits"] = metrics.heavy_hits - metrics.guarded_heavy_hits
			metrics["heavy_misses_or_unresolved"] = metrics.heavy_attempts - metrics.heavy_hits
			metrics["damage_frames"] = metrics.light_hits
			metrics.erase("light_hits")
			runs.append(metrics)
			game.free()
	var report := {"suite": "commander_duels", "fixed_hz": 60, "target_duration_seconds": [12,20], "commander_health_override":health_override, "runs": runs}
	var destination: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			destination = argument.trim_prefix("--report=")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write duel report")
			quit(1)
			return
		file.store_string(JSON.stringify(report, "\t"))
	print("DUEL_REPORT ", JSON.stringify(report))
	# Structural gate: catch broken/stalled duels and dead abilities. Numeric
	# duration/hit-rate bands are left to the periodic crownfront-balance pass.
	var field_by_ability := {"dash": "dashes", "guard": "guards", "heavy": "heavy_attempts", "feint": "feints"}
	var timeouts: int = 0
	var used := {}
	for run in runs:
		if run.outcome == "timeout":
			timeouts += 1
		for ability in ALL_ABILITIES:
			if int(run.get(field_by_ability[ability], 0)) > 0:
				used[ability] = true
	check(timeouts == 0, "No duel reached the timeout cap across %d runs" % runs.size())
	for ability in ALL_ABILITIES:
		check(used.has(ability), "Ability '%s' was used at least once across the sweep" % ability)
	quit(1 if failures else 0)
