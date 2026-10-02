extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.presentation_enabled = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var workers: Array = []
	for actor in game.session.actors.values().duplicate():
		if actor.kind == &"worker": workers.append(actor)
		else: game.session.unregister_actor(actor)
	var depleted_seconds: float = -1.0
	for frame in range(60*1000):
		for worker in workers: worker.step_gameplay(1.0/60.0)
		if frame % 600 == 0:
			var stock: int = 0
			for tree in game.get_node("Trees").get_children():
				if tree.zone == &"home": stock += tree.wood_remaining
			if stock == 0:
				depleted_seconds = frame / 60.0
				break
	game.free()
	print("ECONOMY_PACING_REPORT ", JSON.stringify({"fixed_hz":60, "starting_workers_per_team":3, "safe_depletion_seconds":depleted_seconds, "target_seconds":[180,300]}))
	quit(0 if depleted_seconds >= 180 and depleted_seconds <= 300 else 1)
