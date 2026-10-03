extends SceneTree
## Identical intentions must produce identical gameplay with either presentation.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

static func snapshot(game) -> Dictionary:
	var actors := []
	for actor in game.session.actors.values():
		if is_instance_valid(actor):
			actors.append([actor.match_id, String(actor.kind), actor.position, actor.health, actor.cooldown, actor.alive, actor.rally_buff, actor.stun_remaining, actor.stun_immunity])
			if actor.kind == &"player":
				actors[-1].append([actor.action_state, actor.action_remaining, actor.strike_remaining, actor.facing, actor.healing, actor.heal_cooldown, actor.respawn_remaining, actor.ability_cooldowns.duplicate()])
			elif actor.kind == &"worker":
				actors[-1].append([actor.state, actor.carried, actor.gather_progress])
	var wallets := []
	for team in game.teams:
		wallets.append([team.money, team.wood, team.worker_count, team.combat_count, team.upgrade_levels.duplicate(true)])
	var projectiles := []
	for projectile in game.entities.get_children():
		if projectile.get_script() == game.PROJECTILE_SCRIPT and not projectile.is_queued_for_deletion():
			projectiles.append([projectile.position, projectile.remaining, projectile.owner_team_id])
	return {"actors": actors, "wallets": wallets, "projectiles": projectiles, "recap": game.coordination.snapshot(), "ticks": game.session.ticks}

func _run() -> void:
	var games := []
	for presentation in [true, false]:
		var game = load("res://scenes/main/main.tscn").instantiate()
		game.presentation_enabled = presentation
		game.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(game)
		games.append(game)
	for tick in range(1800):
		for game in games:
			game.player.controller.set_scripted_command(Vector2.RIGHT if tick < 120 else Vector2.ZERO, true)
			if tick in [0, 120, 240]:
				game.session.submit(MatchCommand.new(MatchCommand.Action.RECRUIT, 1, {"id": &"ranged", "route": 1}))
			if tick in [150, 480, 780]:
				game.player.cancel_action()
				game.session.submit(MatchCommand.new(MatchCommand.Action.ABILITY, 1, {"ability_id": [&"dash", &"guard", &"heavy"][[150, 480, 780].find(tick)]}))
			if tick == 60:
				game.session.submit(MatchCommand.new(MatchCommand.Action.RALLY, 1))
			game.session.step()
		if snapshot(games[0]) != snapshot(games[1]):
			push_error("Presentation parity diverged at tick %d" % tick)
			failures += 1
			break
		if tick % 60 == 0:
			await process_frame
	for game in games:
		game.free()
	await process_frame
	var audio = root.get_node("AudioFeedback")
	audio.stop_all()
	audio.queue_free()
	await create_timer(0.5).timeout
	print("STEP PARITY ticks=1800 failures=", failures)
	quit(1 if failures else 0)
