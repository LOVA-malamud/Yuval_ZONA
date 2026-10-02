extends SceneTree
## Render the same authoritative tick trace at 30 and 60 presentation frames/sec.
const Trace = preload("res://tests/step_parity.gd")
var reference: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures := 0
	for fps in [30, 60]:
		Engine.max_fps = fps
		var game = load("res://scenes/main/main.tscn").instantiate()
		game.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(game)
		for tick in range(240):
			game.player.controller.set_scripted_command(Vector2.RIGHT if tick < 60 else Vector2.ZERO, true)
			if tick in [0, 60, 120]:
				game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 1, {"id": &"ranged", "route": 1}))
			game.session.step()
			var state := Trace.snapshot(game)
			if fps == 30:
				reference.append(state)
			elif state != reference[tick]:
				push_error("Rendered trace diverged at tick %d" % tick)
				failures += 1
				break
			if (tick + 1) % (60 / fps) == 0:
				await process_frame
		game.free()
		await process_frame
	root.get_node("AudioFeedback").stop_all()
	root.get_node("AudioFeedback").queue_free()
	await create_timer(0.5).timeout
	print("RENDER PARITY 30/60 fps ticks=240 failures=", failures)
	quit(1 if failures else 0)
