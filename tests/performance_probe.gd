extends SceneTree
## Reproducible capacity stress. Fixture health sustains concurrent combat; not a balance test.
## godot --path . --script tests/performance_probe.gd -- rendered 1280x720 baseline
## Optional fourth argument sets sample duration in seconds (e.g. rendered 1280x720 soak 60).
## Run separately from other Godot instances, using isolated settings in copies.
## godot --headless --path . --script tests/performance_probe.gd -- headless 1280x720 baseline

var sample_seconds: float = 15.0
const WARMUP_SECONDS := 3.0
const STEP := 1.0 / 60.0
var game = null
var totals: Dictionary = {}
var maxima: Dictionary = {}
var samples: Dictionary = {}
var sample_count: int = 0
var mode: String
var dimensions: String
var label: String
var next_runtime_sample: float = 0.0
var runtime_samples: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "rendered"
	dimensions = args[1] if args.size() > 1 else "1280x720"
	label = args[2] if args.size() > 2 else "current"
	sample_seconds = float(args[3]) if args.size() > 3 else 15.0
	var size_parts := dimensions.split("x")
	root.size = Vector2i(int(size_parts[0]), int(size_parts[1]))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(67231)
	game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	await process_frame
	_setup_capacity()
	if get_nodes_in_group("combatants").size() != 115:
		push_error("Capacity fixture must contain exactly 115 actors")
		quit(1)
		return
	await process_frame
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var initial_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var start := Time.get_ticks_usec()
	if mode == "headless":
		await _headless()
		if sample_count != int(sample_seconds / STEP):
			push_error("Performance fixture did not complete all samples")
			quit(1)
			return
	else:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		await create_timer(WARMUP_SECONDS).timeout
		var last := Time.get_ticks_usec()
		start = last
		while (Time.get_ticks_usec() - start) / 1000000.0 < sample_seconds:
			await process_frame
			var now := Time.get_ticks_usec()
			_record("frame_ms", (now - last) / 1000.0)
			last = now
			_record("process_ms", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_record("physics_ms", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			_record("draw_calls", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_record("rendered_objects", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			_record("memory_mb", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
			sample_count += 1
			if game.match_seconds >= next_runtime_sample:
				next_runtime_sample = game.match_seconds + 1.0
				var effects: int = 0
				for node in game.get_children():
					if node.get_script() == load("res://scripts/visuals/battle_effect.gd"):
						effects += 1
				runtime_samples.append({"seconds": game.match_seconds, "memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "effects": effects})
		game.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		RenderingServer.force_draw()
		var picture := root.get_texture().get_image()
		picture.save_png("res:/" + "/tests/artifacts/performance_%s_%s.png" % [label, dimensions])
		if picture.get_size() != root.size:
			push_error("Incorrect rendered performance dimensions")
			quit(1)
			return
	if _total_damage_taken() <= 1000.0 or get_nodes_in_group("combatants").size() != 115:
		push_error("Capacity fixture did not sustain live combat with all 115 actors")
		quit(1)
		return
	var summary := {}
	for key in samples:
		var values: Array = samples[key]
		values.sort()
		summary[key] = {"mean": totals[key] / values.size(), "p95": values[mini(values.size() - 1, int(values.size() * 0.95))], "max": maxima[key]}
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	var report := {"mode": mode, "label": label, "resolution": dimensions, "godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "os": OS.get_name(), "sample_count": sample_count, "elapsed_wall_seconds": elapsed, "sample_seconds": sample_seconds, "warmup_seconds": WARMUP_SECONDS, "metrics": summary, "initial_memory_mb": initial_memory / 1048576.0, "final_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "initial_nodes": initial_nodes, "final_nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "combatants": get_nodes_in_group("combatants").size(), "runtime_samples": runtime_samples, "simulated_seconds": game.match_seconds, "total_damage_taken": _total_damage_taken(), "fixture": "80 troops, 20 workers, 9 towers, 4 commanders, 2 Kings; three mixed-role battles; fixed seed 67231; fixture durability increased to sustain load; no balance inference"}
	if mode != "headless":
		report["fps_from_mean_frame"] = 1000.0 / summary.frame_ms.mean
	var output := FileAccess.open("res:/" + "/tests/artifacts/performance_%s_%s_%s.json" % [label, mode, dimensions], FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print("PERFORMANCE REPORT ", JSON.stringify(report))
	# Manually stepped combat can leave pending audio-player starts. Teardown is
	# outside all measurements; release the fixture before the audio thread drains.
	game.free()
	game = null
	var audio = root.get_node_or_null("AudioFeedback")
	if audio != null:
		await physics_frame
		await physics_frame
		audio.stop_all()
		audio.queue_free()
		await create_timer(0.5).timeout
	quit()

func _setup_capacity() -> void:
	for team in game.teams:
		team.money = 100000
		team.wood = 100000
		for i in range(7):
			game.purchase(team.team_id, &"worker", false)
		for i in range(40):
			game.purchase(team.team_id, [&"melee", &"ranged", &"tank"][i % 3], false, i % 3)
	for i in range(game.pads.size()):
		var pad = game.pads[i]
		var commander = game.commanders[0 if i < 3 or i == 6 else 2]
		commander.position = pad.position
		game.build_tower(commander, pad)
	var indices := {1: 0, 2: 0}
	for entity in get_nodes_in_group("combatants"):
		entity.max_health = 1000000.0
		entity.health = entity.max_health
		if entity.kind not in [&"melee", &"ranged", &"tank"]:
			continue
		var index: int = indices[entity.team.team_id]
		indices[entity.team.team_id] += 1
		var lane: int = (index / 3) % 3
		var battle_y: float = [700.0, 1400.0, 2020.0][lane]
		var side: float = 1.0 if entity.team.team_id == 1 else -1.0
		var rank: int = index / 9
		var role_offset: float = -60.0 if entity.kind == &"ranged" else 0.0
		entity.position = Vector2(2180 if side > 0 else 2380, battle_y) + Vector2(role_offset * side, (rank - 2) * 32 + (index % 3) * 8)
		entity.rally_remaining = 0.0
	game.player.position = Vector2(2200, 1430)
	game.commanders[1].position = Vector2(2150, 1450)
	game.commanders[2].position = Vector2(2490, 1430)
	game.commanders[3].position = Vector2(2500, 2070)
	game.player.get_node("Camera2D").reset_smoothing()
	game._physics_process(STEP)

func _headless() -> void:
	for step in range(int((WARMUP_SECONDS + sample_seconds) / STEP)):
		var collecting: bool = step >= int(WARMUP_SECONDS / STEP)
		var start := Time.get_ticks_usec()
		game._process(STEP)
		game._physics_process(STEP)
		game.get_node("EconomyManager")._process(STEP)
		for pad in game.pads:
			pad._process(STEP)
		var after_world := Time.get_ticks_usec()
		for commander in game.commanders:
			if commander.controller.has_method("_process"):
				commander.controller._process(STEP)
			commander._physics_process(STEP)
		var after_ai := Time.get_ticks_usec()
		for entity in get_nodes_in_group("combatants"):
			if entity.kind != &"player" and not entity.is_queued_for_deletion():
				entity._physics_process(STEP)
		var after_units := Time.get_ticks_usec()
		game.hud._process(STEP)
		for child in game.get_children():
			if child.get_script() == load("res://scripts/visuals/battle_effect.gd") and not child.is_queued_for_deletion():
				child._process(STEP)
		var after_ui := Time.get_ticks_usec()
		if collecting:
			_record("world_ms", (after_world - start) / 1000.0)
			_record("ai_commanders_ms", (after_ai - after_world) / 1000.0)
			_record("units_workers_towers_ms", (after_units - after_ai) / 1000.0)
			_record("hud_effects_ms", (after_ui - after_units) / 1000.0)
			_record("total_script_ms", (after_ui - start) / 1000.0)
			sample_count += 1
		if step % 60 == 0:
			await process_frame

func _record(key: String, value: float) -> void:
	if not samples.has(key):
		samples[key] = []
		totals[key] = 0.0
		maxima[key] = 0.0
	samples[key].append(value)
	totals[key] += value
	maxima[key] = maxf(maxima[key], value)

func _total_damage_taken() -> float:
	var result: float = 0.0
	for actor in get_nodes_in_group("combatants"):
		result += actor.max_health - actor.health
	return result
