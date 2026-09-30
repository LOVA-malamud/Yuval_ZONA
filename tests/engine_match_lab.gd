extends SceneTree
## Accelerated real scene-tree match; Godot owns process and physics ordering.

const LIMIT_SECONDS: float = 1800.0
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var seed: int = int(arguments[0]) if arguments.size() > 0 else 42
	game = load("res://scenes/main/main.tscn").instantiate()
	game.strategy_seed = seed
	root.add_child(game)
	current_scene = game
	# A commander AI stands in for the human; all other systems run normally.
	game.player.controller.free()
	var controller = game.AI_CONTROLLER.new()
	controller.game = game
	controller.team = game.player.team
	controller.actor = game.player
	controller.personality = "aggressive"
	game.player.human_controlled = false
	game.player.controller = controller
	game.player.add_child(controller)
	var first_king_damage: float = -1.0
	var peak_army: int = 0
	var started: int = Time.get_ticks_msec()
	while game.match_seconds < LIMIT_SECONDS and not game.match_finished:
		await process_frame
		for team in game.teams:
			peak_army = maxi(peak_army, team.combat_count)
			if first_king_damage < 0.0 and is_instance_valid(team.king) and team.king.health < team.king.max_health:
				first_king_damage = game.match_seconds
	var report := {
		"seed": seed,
		"duration": game.match_seconds,
		"finished": game.match_finished,
		"winning_team_id": game.winning_team_id,
		"first_king_damage": first_king_damage,
		"max_army_per_team": peak_army,
		"wall_seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"failures": 0 if game.match_finished and game.match_seconds >= 120.0 else 1,
	}
	print("LAB_MATCH_REPORT ", JSON.stringify(report))
	paused = false
	game.free()
	root.get_node("AudioFeedback").stop_all()
	quit(int(report["failures"]))
