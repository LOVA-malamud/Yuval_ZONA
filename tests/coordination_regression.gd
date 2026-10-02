extends SceneTree
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func request(action: MatchCommand.Action, payload: Dictionary = {}, commander_id: int = 1) -> CommandResult:
	return game.session.execute(MatchCommand.new(action, commander_id, payload))

func _run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.presentation_enabled = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var team: GameTeam = game.teams[0]
	team.money = 1000
	team.wood = 1000
	var ally = game.commanders[1].controller
	ally.build_goal = game.pads[0]
	ally.reserved_gold = 140
	check(request(MatchCommand.Action.ALLY_ORDER, {"order": &"south"}).success, "Human can order ally to push South")
	check(ally.order == &"south" and ally.route_id == 2 and ally.build_goal == null and ally.reserved_gold == 0, "Explicit order clears conflicting plan and reserve")
	check(not request(MatchCommand.Action.ALLY_ORDER, {"order": &"invalid"}).success, "Unknown order rejected")
	check(not request(MatchCommand.Action.ALLY_ORDER, {"order": &"north"}, 3).success, "Enemy AI cannot issue human ally orders")
	ally.reset_orders()
	check(ally.order == &"south", "Persistent ally order survives death/respawn reset")
	ally.build_goal = game.pads[0]
	ally.reserved_gold = game.balance.tower_money
	team.money = 50
	check(request(MatchCommand.Action.RECRUIT, {"id": &"melee", "route": 0}).success, "Human can spend resources reserved by AI")
	check(ally.build_goal == null and ally.reserved_gold == 0, "Human spending revalidates an unaffordable construction plan")
	team.money = 1000
	check(request(MatchCommand.Action.RECRUIT, {"id": &"melee", "route": 0}).success, "Recruit through command boundary")
	var unit = game.entities.get_child(game.entities.get_child_count() - 1)
	unit.position = Vector2(900, 1300)
	game.player.position = Vector2(930, 1300)
	check(unit.owner_commander_id == 1 and game.coordination.commander_stats[1].gold == 100, "Recruit and spending are attributed to requester")
	check(request(MatchCommand.Action.RALLY).success and unit.rally_buff == 8.0, "Rally applies to nearby allied army")
	check(game.player.rally_buff == 0.0 and team.king.rally_buff == 0.0, "Rally excludes commanders and structures")
	check(not request(MatchCommand.Action.RALLY).success, "Rally cooldown prevents repeated activation")
	var start: Vector2 = unit.position
	unit.travel_toward(Vector2(1100, 1300), 0.1)
	check(is_equal_approx(unit.position.distance_to(start), unit.move_speed * 1.15 * 0.1), "Rally provides its declared movement bonus")
	unit.cooldown = 1.0
	unit.tick(0.1)
	check(is_equal_approx(unit.cooldown, 0.88), "Rally provides its declared attack rate bonus")
	var old_route: int = unit.route_id
	check(request(MatchCommand.Action.REGROUP).success and unit.regroup_remaining == 8.0, "Regroup issues temporary local order")
	check(game.navigation.walkable(unit.regroup_goal, unit.body_radius), "Regroup resolves a terrain-safe destination")
	var old_goal: Vector2 = unit.regroup_goal
	game.player.position += Vector2(60, 0)
	request(MatchCommand.Action.REGROUP)
	check(unit.regroup_goal != old_goal and unit.route_id == old_route, "Repeated regroup replaces destination without changing lane")
	unit.step_gameplay(8.1)
	check(unit.regroup_remaining == 0.0 and unit.route_id == old_route and unit.rally_buff == 0.0, "Temporary regroup and buff expire while original lane survives")
	var first: bool = game.coordination.alert(&"workers_threatened", 1, Vector2(900, 1300))
	var second: bool = game.coordination.alert(&"workers_threatened", 1, Vector2(910, 1300))
	check(first and not second, "Alerts suppress duplicates in a location for ten seconds")
	game.match_seconds += 10.0
	check(game.coordination.alert(&"workers_threatened", 1, Vector2(900, 1300)), "Alert becomes available after suppression period")
	game.player.position = game.pads[0].position
	check(request(MatchCommand.Action.BUILD, {"pad": game.pads[0]}).success, "Build command uses valid nearby pad")
	var tower = game.pads[0].tower
	check(tower.owner_commander_id == 1 and game.coordination.team_stats[1].towers_built == 1, "Tower build is attributed")
	tower.take_damage(99999.0, 2)
	check(game.coordination.team_stats[1].towers_destroyed == 1, "Tower loss recorded at death")
	var hp: float = game.teams[1].king.health
	game.teams[1].king.take_damage(50.0, 1, 1)
	check(game.coordination.commander_stats[1].king_damage == 50.0 and game.teams[1].king.health == hp - 50.0, "Actual King damage attributed without overkill")
	request(MatchCommand.Action.RECRUIT, {"id": &"melee", "route": 1}, 3)
	var enemy = game.entities.get_child(game.entities.get_child_count() - 1)
	enemy.position = game.player.position + Vector2(50, 0)
	game.player.controller._select_target(game.player.get_canvas_transform() * enemy.position)
	check(game.player.controller.focus_target == enemy, "Focus selection chooses a locally detected enemy")
	game.player.position = Vector2(1200, 900)
	enemy.position = Vector2(1320, 900)
	game.player.controller.drive(game.player, MatchSession.STEP)
	check(game.player.controller.focus_target == null, "Terrain occlusion clears focus before applying attack input")
	enemy.position = game.player.position + Vector2(-50, 0)
	game.player.controller._select_target(game.player.get_canvas_transform() * enemy.position)
	enemy.die()
	await process_frame
	game.player.controller.drive(game.player, MatchSession.STEP)
	check(game.player.controller.focus_target == null, "Freed focus target clears without a stale-object error")
	# Factory failure must leave wallet and roster unchanged.
	game.catalog = game.catalog.duplicate(true)
	game.catalog.army_scene = null
	var wallet := Vector2i(team.money, team.wood)
	var count: int = team.combat_count
	check(not request(MatchCommand.Action.RECRUIT, {"id": &"melee", "route": 0}).success, "Missing recruit factory rejects creation")
	check(wallet == Vector2i(team.money, team.wood) and count == team.combat_count, "Creation failure cannot spend or change counts")
	game.free()
	await process_frame
	# Tutorial is a real scene with its own progress and normal command boundary.
	game = load("res://scenes/main/tutorial.tscn").instantiate()
	game.presentation_enabled = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	check(game.tutorial.stage == TutorialDirector.Stage.MOVE, "Tutorial starts at movement lesson")
	game.player.position += Vector2(65, 0)
	game.tutorial.step_gameplay()
	check(game.tutorial.stage == TutorialDirector.Stage.ATTACK, "Movement advances tutorial")
	game.tutorial.dummy.take_damage(9999, 1)
	check(game.tutorial.stage == TutorialDirector.Stage.RECRUIT, "Practice enemy defeat advances tutorial")
	game.select_route(0)
	request(MatchCommand.Action.RECRUIT, {"id": &"melee", "route": 0})
	game.tutorial.step_gameplay()
	check(game.tutorial.stage == TutorialDirector.Stage.COORDINATE, "Route selection and recruitment advance tutorial")
	request(MatchCommand.Action.ALLY_ORDER, {"order": &"center"})
	request(MatchCommand.Action.RALLY)
	game.tutorial.step_gameplay()
	check(game.tutorial.stage == TutorialDirector.Stage.TOWER, "Ally order and effective rally advance tutorial")
	game.player.position = game.pads[0].position
	request(MatchCommand.Action.BUILD, {"pad": game.pads[0]})
	check(game.tutorial.stage == TutorialDirector.Stage.KING, "Tower purchase advances tutorial")
	game.teams[1].king.take_damage(9999, 1)
	check(game.match_finished and game.tutorial.stage == TutorialDirector.Stage.COMPLETE, "King defeat completes tutorial")
	paused = false
	game.free()
	await process_frame
	# Actions performed before their lesson must not strand later progression.
	game = load("res://scenes/main/tutorial.tscn").instantiate()
	game.presentation_enabled = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.tutorial.dummy.take_damage(9999, 1)
	game.teams[1].king.take_damage(9999, 1)
	check(game.tutorial.stage == TutorialDirector.Stage.MOVE and game.teams[1].king.health == 120, "Early practice kill is remembered and King remains protected")
	game.player.position += Vector2(65, 0)
	game.tutorial.step_gameplay()
	check(game.tutorial.stage == TutorialDirector.Stage.RECRUIT, "Earlier practice kill satisfies the attack lesson after movement")
	game.select_route(1)
	request(MatchCommand.Action.RECRUIT, {"id": &"melee", "route": 1})
	var early_recruit = game.entities.get_child(game.entities.get_child_count() - 1)
	game.session.step()
	game.player.position = game.pads[0].position
	request(MatchCommand.Action.BUILD, {"pad": game.pads[0]})
	check(game.tutorial.stage == TutorialDirector.Stage.COORDINATE and game.tutorial.tower_built, "Early tower purchase is remembered without skipping coordination")
	early_recruit.position = game.player.position + Vector2(30, 0)
	request(MatchCommand.Action.ALLY_ORDER, {"order": &"center"})
	request(MatchCommand.Action.RALLY)
	game.session.step()
	check(game.tutorial.stage == TutorialDirector.Stage.KING, "Remembered tower purchase completes its later lesson")
	game.teams[1].king.take_damage(9999, 1)
	check(game.match_finished and game.tutorial.stage == TutorialDirector.Stage.COMPLETE, "Out-of-order tutorial actions still reach completion")
	paused = false
	game.free()
	await process_frame
	print("COORDINATION COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
