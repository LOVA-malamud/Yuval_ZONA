extends SceneTree
## Accelerated integration run: actual game behaviors at 10 Hz, no free resources.
var game = null
var towers_built: Dictionary = {1: 0, 2: 0}
var seen_towers: Dictionary = {}
var deaths: Dictionary = {1: 0, 2: 0}
var failures: int = 0
var last_positions: Dictionary = {}
var idle_seconds: Dictionary = {}
var max_idle: float = 0.0
var deposits: int = 0
var forward_gather_ticks: int = 0
var first_king_damage: float = -1.0
var max_army: int = 0
var routes_seen: Dictionary = {}
var dt: float = 0.1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.strategy_seed = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 42
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	# Substitute a controller, leaving the commander/team/core systems untouched.
	game.player.controller.free()
	var controller = game.AI_CONTROLLER.new()
	controller.game = game
	controller.team = game.player.team
	controller.actor = game.player
	controller.personality = "aggressive"
	game.player.human_controlled = false
	game.player.controller = controller
	game.player.add_child(controller)
	if OS.get_cmdline_user_args().size() > 1:
		dt = float(OS.get_cmdline_user_args()[1])
	var start_ms: int = Time.get_ticks_msec()
	var steps: int = 0
	while steps < int(1800.0/dt) and not game.match_finished:
		steps += 1
		game._process(dt)
		game._physics_process(dt)
		game.get_node("EconomyManager")._process(dt)
		for pad in game.pads:
			pad._process(dt)
		for commander in game.commanders:
			commander.controller._process(dt)
			var was_alive: bool = commander.alive
			commander._physics_process(dt)
			if not was_alive and commander.alive:
				deaths[commander.team.team_id] += 1
		for entity in get_nodes_in_group("combatants"):
			if not is_instance_valid(entity) or entity.is_queued_for_deletion() or entity.kind == &"player":
				continue
			var old_carry: int = entity.carried if entity.kind == &"worker" else 0
			entity._physics_process(dt)
			if entity.kind == &"worker":
				if old_carry > 0 and entity.carried == 0 and entity.alive:
					deposits += 1
				if entity.state == entity.State.GATHER and is_instance_valid(entity.tree) and entity.tree.renewable:
					forward_gather_ticks += 1
			elif entity.kind in [&"melee", &"ranged", &"tank"]:
				routes_seen[entity.route_id] = true
			if entity.kind == &"king" and entity.health < entity.max_health and first_king_damage < 0:
				first_king_damage = game.match_seconds
			max_army = maxi(max_army, entity.team.combat_count)
			if entity.kind == &"tower" and not seen_towers.has(entity.get_instance_id()):
				seen_towers[entity.get_instance_id()] = true
				towers_built[entity.team.team_id] += 1
			if not game.navigation.walkable(entity.position, entity.body_radius - 0.1):
				push_error("Entity entered blocked terrain: %s %s" % [entity.kind,entity.position])
				failures += 1
		if steps % maxi(1,int(2.0/dt)) == 0:
			for commander in game.commanders:
				var id: int = commander.commander_id
				var moved: float = commander.position.distance_to(last_positions.get(id, commander.position))
				var needs_travel: bool = commander.alive and commander.position.distance_to(commander.path_goal) > 130.0 and commander.tactical_status != "STATUS_ENGAGING"
				idle_seconds[id] = float(idle_seconds.get(id, 0.0)) + 2.0 if moved < 5.0 and needs_travel else 0.0
				max_idle = maxf(max_idle, idle_seconds[id])
				last_positions[id] = commander.position
		if steps % maxi(1,int(120.0/dt)) == 0:
			print("MATCH t=", int(game.match_seconds), " hp=", _hp(0), "/", _hp(1), " army=", game.teams[0].combat_count, "/", game.teams[1].combat_count, " wood=", game.teams[0].wood, "/", game.teams[1].wood, " towers_built=", towers_built)
		if steps % 30 == 0:
			# Release queued deaths/effects without advancing automatic game logic.
			for child in game.get_children():
				if child.get_script() == load("res://scripts/visuals/battle_effect.gd"):
					child.queue_free()
			await process_frame
	if not game.match_finished:
		push_error("Match did not reach conclusion within 30 minutes")
		failures += 1
	if towers_built[1] == 0 or towers_built[2] == 0:
		push_error("AI did not construct towers for both teams")
		failures += 1
	if game.match_seconds < 120:
		push_error("Match ended before strategic opening")
		failures += 1
	print("MAX commander travel stall seconds=",max_idle)
	if max_idle > 12.0:
		push_error("Commander travel stalled for more than 12 simulated seconds")
		failures += 1
	var wall_seconds: float = (Time.get_ticks_msec() - start_ms) / 1000.0
	print("MATCH COMPLETE seconds=", game.match_seconds, " finished=", game.match_finished, " respawns=", deaths, " towers=", towers_built, " wall_seconds=", wall_seconds, " failures=", failures)
	var surviving_towers: int = 0
	for pad in game.pads:
		if pad.occupied():
			surviving_towers += 1
	var report: Dictionary = {"seed":game.strategy_seed,"step_seconds":dt,"duration":game.match_seconds,"finished":game.match_finished,"winning_team_id":game.winning_team_id,"failures":failures,"first_king_damage":first_king_damage,"towers_built":towers_built,"towers_destroyed":seen_towers.size()-surviving_towers,"respawns":deaths,"worker_deposits":deposits,"forward_gather_seconds":forward_gather_ticks*dt,"max_army_per_team":max_army,"lanes_used":routes_seen.keys(),"max_commander_stall":max_idle}
	report["wall_seconds"] = wall_seconds
	print("MATCH REPORT ",JSON.stringify(report))
	var output := FileAccess.open("res:/" + "/tests/artifacts/match_%d_%dhz.json" % [game.strategy_seed,roundi(1.0/dt)],FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	# Manually stepped combat can leave deferred audio starts. The report and
	# timing are complete: release the fixture before draining the audio server.
	paused = false
	game.free()
	game = null
	var audio = root.get_node("AudioFeedback")
	await physics_frame
	await physics_frame
	audio.stop_all()
	audio.queue_free()
	await create_timer(0.5).timeout
	quit(1 if failures else 0)

func _hp(index: int) -> int:
	return int(game.teams[index].king.health) if is_instance_valid(game.teams[index].king) else 0
