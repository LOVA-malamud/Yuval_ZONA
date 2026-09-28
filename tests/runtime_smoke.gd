extends SceneTree
## Run after an editor import: godot --headless --path . --script tests/runtime_smoke.gd
## Deterministically steps real game scripts. It does not replace a visual playtest.

var failures: int = 0
var game = null


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		push_error(message)
		failures += 1


func _run() -> void:
	var scene = load("res://scenes/main/main.tscn")
	game = scene.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var azure: GameTeam = game.teams[0]
	var ember: GameTeam = game.teams[1]
	check(game.commanders.size() == 4, "Four independent commanders exist")
	check(game.commanders[0].team == game.commanders[1].team and game.commanders[2].team == game.commanders[3].team, "Commanders share the correct teams")
	check(azure.worker_count == 3 and ember.worker_count == 3, "Both teams start with workers")
	check(get_nodes_in_group("trees").size() == 32, "Symmetrical tree groves exist")
	check(game.hud.controls.size.x >= 1280.0, "HUD root fills viewport")
	var money_before: int = azure.money
	game.get_node("EconomyManager")._process(1.0)
	check(azure.money == money_before + 10, "Passive income uses team stats")
	azure.money = 0
	check(not game.purchase(1, &"tank", false), "Unaffordable purchase rejected")
	check(azure.money == 0 and azure.combat_count == 0, "Failed purchase changes nothing")
	azure.money = 100000
	azure.wood = 100000
	money_before = azure.money
	check(game.purchase(1, &"melee", false), "Melee purchase succeeds")
	check(azure.money == money_before - 50 and azure.combat_count == 1, "Purchase debits once")
	check(game.purchase(1, &"ranged", false), "Ranged purchase succeeds")
	check(game.purchase(1, &"tank", false), "Tank purchase succeeds")
	check(game.purchase(1, &"worker", false), "Worker purchase succeeds")
	var hp_before: float = azure.king.health
	azure.king.take_damage(10.0, azure.team_id)
	check(azure.king.health == hp_before, "Friendly damage is rejected")
	azure.king.take_damage(10.0, ember.team_id)
	check(azure.king.health == hp_before - 10.0, "Enemy damage applies")
	for definition in game.upgrades:
		var before: float = azure.get_stat(definition.stat)
		var wood_before: int = azure.wood
		check(game.purchase_upgrade(1, definition.id, false), "%s upgrade succeeds" % definition.id)
		check(
			is_equal_approx(azure.get_stat(definition.stat), before + definition.amount),
			"Upgrade changes stat"
		)
		check(azure.wood == wood_before - definition.cost(0), "Upgrade debits wood")
		check(definition.cost(1) > definition.cost(0), "Upgrade cost increases")
	check(azure.king.max_health == 1420.0, "King receives upgrade immediately")
	check(azure.king.health == hp_before - 10.0 + 220.0, "HP upgrade preserves missing health")
	var worker = null
	var melee = null
	for entity in get_nodes_in_group("combatants"):
		if entity.team == azure and entity.kind == &"worker":
			worker = entity
		if entity.team == azure and entity.kind == &"melee":
			melee = entity
	var wood_before: int = azure.wood
	money_before = azure.money
	for step in range(1800):
		worker._physics_process(1.0 / 60.0)
	check(azure.wood > wood_before, "Worker finds tree, gathers, returns and deposits")
	check(
		azure.money - money_before == azure.wood - wood_before, "Wood delivery pays matching money"
	)
	check(worker.move_speed == azure.get_stat(&"worker_speed"), "Existing worker receives upgrades")
	var tree = get_nodes_in_group("trees")[0]
	tree.renewable = false
	tree.wood_remaining = 2
	check(tree.harvest(10) == 2 and not tree.available(), "Finite tree cannot overdraw")
	var position_before: Vector2 = melee.position
	melee._physics_process(0.1)
	check(melee.position.x > position_before.x, "Army advances toward enemy base")
	melee.position = ember.base_position + Vector2(-70, 0)
	melee.cooldown = 0.0
	var enemy_hp: float = ember.king.health
	melee.attack(ember.king)
	check(ember.king.health < enemy_hp, "Melee damages enemy in range")
	enemy_hp = ember.king.health
	melee.attack(ember.king)
	check(ember.king.health == enemy_hp, "Attack cooldown prevents repeated damage")
	var melee_hp: float = melee.health
	ember.king._physics_process(0.1)
	check(melee.health < melee_hp, "King defends itself automatically")
	var bot = game.commanders[2].controller
	ember.money = 1000
	bot._process(20.1)
	check(ember.combat_count > 0, "Bot buys combat units")
	var pad = game.pads[0]
	game.player.position = pad.position
	money_before = azure.money
	wood_before = azure.wood
	check(game.build_tower(game.player, pad), "Nearby commander builds tower")
	check(azure.money == money_before - game.balance.tower_money and azure.wood == wood_before - game.balance.tower_wood, "Tower debits shared wallet once")
	check(not game.build_tower(game.player, pad), "Occupied pad rejects duplicate construction")
	check(game.upgrade_tower(game.player, pad) and pad.tower.level == 2, "Tower level two upgrade")
	check(game.upgrade_tower(game.player, pad) and pad.tower.level == 3, "Tower level three upgrade")
	check(not game.upgrade_tower(game.player, pad), "Tower upgrade cap enforced")
	var enemy_commander = game.commanders[2]
	enemy_commander.position = pad.position
	check(not game.upgrade_tower(enemy_commander, pad), "Enemy cannot upgrade owned tower")
	var commander_hp: float = enemy_commander.health
	pad.tower._physics_process(0.1)
	check(enemy_commander.health < commander_hp, "Tower automatically attacks enemy")
	pad.tower.take_damage(99999, ember.team_id)
	check(not pad.occupied() and pad.rebuild_remaining > 0, "Destroyed tower releases pad with cooldown")
	check(not game.build_tower(game.player, pad), "Cooldown prevents immediate rebuild")
	pad._process(9.0)
	check(not game.build_tower(enemy_commander, pad), "Enemy cannot occupy protected home pad")
	check(game.build_tower(game.player, pad), "Tower can be rebuilt after cooldown")
	game.player.position = azure.base_position
	check(not game.build_tower(game.player, game.pads[1]), "Remote construction rejected")
	for commander in game.commanders:
		commander.take_damage(99999, 2 if commander.team.team_id == 1 else 1)
		check(not commander.alive and not game.match_finished, "Commander death is independent of match")
		commander._physics_process(12.1)
		check(commander.alive and commander.position == commander.spawn_position, "Each commander respawns at own point")
	game.player.take_damage(9999.0, 2)
	check(not game.player.alive and not game.match_finished, "Hero death does not end match")
	game.player._physics_process(12.1)
	check(game.player.alive and game.player.health == game.player.max_health, "Hero respawns")
	game.hud._toggle_pause()
	check(paused and game.hud.result_overlay.visible, "Pause exposes working menu")
	check(not game.purchase(1, &"melee", false), "Paused match rejects transactions")
	game.hud._toggle_pause()
	check(not paused, "Resume unpauses")
	ember.king.take_damage(99999.0, 1)
	check(game.match_finished and paused, "King death freezes match")
	check(game.hud.result_title.text == "VICTORY", "Enemy King death shows victory")
	check(not game.purchase_upgrade(1, &"king_health", false), "Ended match rejects upgrades")
	game.hud._restart()
	await process_frame
	await process_frame
	game = current_scene
	game.process_mode = Node.PROCESS_MODE_DISABLED
	check(not paused and not game.match_finished, "Restart clears match state")
	check(game.teams[0].worker_count == 3, "Restart restores starting roster")
	game.teams[0].king.take_damage(99999.0, 2)
	check(game.hud.result_title.text == "DEFEAT", "Own King death shows defeat")
	paused = false
	root.get_node("AudioFeedback").stop_all()
	await create_timer(0.1).timeout
	print("Runtime smoke checks complete; failures: ", failures)
	quit(1 if failures > 0 else 0)
