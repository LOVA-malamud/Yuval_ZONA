class_name MatchSession
extends Node
## One clock and lifecycle for both live and accelerated scene-tree matches.
enum State { INITIALIZING, RUNNING, PAUSED, FINISHED, STOPPED }
const STEP := 1.0 / 60.0
var state: State = State.INITIALIZING
var game = null
var ticks: int = 0
var stepping: bool = false
signal command_completed(receipt: int, result: CommandResult)
signal match_event(event: Dictionary)
var next_receipt: int = 1
var pending: Array[Dictionary] = []
var publishing: bool = false
var next_actor_id: int = 1
var actors: Dictionary = {}
var actors_in_order: Array[CombatEntity] = []

func register_actor(actor: CombatEntity) -> int:
	var identity := next_actor_id
	next_actor_id += 1
	actors[identity] = actor
	actors_in_order.append(actor)
	actor.tree_exiting.connect(func():
		actors.erase(identity)
		actors_in_order.erase(actor)
	)
	return identity

func unregister_actor(actor: CombatEntity) -> void:
	actors.erase(actor.match_id)
	actors_in_order.erase(actor)
	actor.remove_from_group("combatants")

func start(owner_game) -> void:
	game = owner_game
	state = State.RUNNING

func step() -> void:
	if state != State.RUNNING or game == null or game.match_finished or game.get_tree().paused:
		return
	stepping = true
	ticks += 1
	game.match_seconds = ticks * STEP
	game.route_highlight = maxf(0.0, game.route_highlight - STEP)
	game.get_node("EconomyManager").step_gameplay(STEP)
	for pad in game.pads:
		pad.step_gameplay(STEP)
	for commander in game.commanders:
		if commander.controller.has_method("step_gameplay"):
			commander.controller.step_gameplay(STEP)
	var batch := pending
	pending = []
	for request in batch:
		command_completed.emit(request.receipt, execute(request.command))
	game.rebuild_spatial()
	# Children are created in stable match order. Keep a snapshot so newly created
	# projectiles advance once, in the projectile phase, rather than twice.
	for actor in actors_in_order.duplicate():
		if state != State.RUNNING:
			break
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			actor.step_gameplay(STEP)
			if game.presentation_enabled and is_instance_valid(actor) and not actor.is_queued_for_deletion():
				actor.step_presentation(STEP)
	game.rebuild_spatial()
	if state == State.RUNNING:
		for projectile in game.get_tree().get_nodes_in_group("projectiles"):
			if state != State.RUNNING:
				break
			if projectile.game == game and not projectile.is_queued_for_deletion():
				projectile.step_gameplay(STEP)
	for identity in actors.keys():
		if not is_instance_valid(actors[identity]) or actors[identity].is_queued_for_deletion():
			actors_in_order.erase(actors[identity])
			actors.erase(identity)
	if state == State.RUNNING and game.coordination != null:
		game.coordination.step_gameplay(STEP)
	if game.tutorial != null:
		game.tutorial.step_gameplay()
	stepping = false

func pause() -> void:
	if state == State.RUNNING:
		state = State.PAUSED
		_clear_input()
		_cancel_pending()

func resume() -> void:
	if state == State.PAUSED:
		state = State.RUNNING

func finish() -> void:
	state = State.FINISHED
	_clear_input()
	_cancel_pending()

func stop() -> void:
	state = State.STOPPED
	_clear_input()
	_cancel_pending()
	actors.clear()
	actors_in_order.clear()
	game = null

func submit(command: MatchCommand) -> int:
	var receipt := next_receipt
	next_receipt += 1
	if state != State.RUNNING or game == null or game.get_tree().paused or command == null:
		command_completed.emit(receipt, CommandResult.new(false, &"invalid_state"))
	else:
		pending.append({"receipt": receipt, "command": MatchCommand.new(command.action, command.commander_id, command.payload)})
	return receipt

func execute(command: MatchCommand) -> CommandResult:
	if state != State.RUNNING or game == null or game.get_tree().paused or publishing or command == null:
		return CommandResult.new(false, &"invalid_state")
	var commander = game.commander_by_id(command.commander_id)
	if commander == null:
		return CommandResult.new(false, &"invalid_actor")
	var values := command.payload
	var available: Dictionary
	var success: bool = false
	var before := Vector2i(commander.team.money, commander.team.wood)
	var event_type: StringName = &""
	match command.action:
		MatchCommand.Action.ABILITY:
			if not commander.alive or not typeof(values.get("ability_id")) in [TYPE_STRING, TYPE_STRING_NAME]:
				return CommandResult.new(false, &"invalid_request")
			# Legacy direction fields are intentionally ignored: facing belongs to movement.
			success = commander.activate_ability(StringName(values.ability_id))
		MatchCommand.Action.RECRUIT:
			if not typeof(values.get("id")) in [TYPE_STRING, TYPE_STRING_NAME] or typeof(values.get("route")) != TYPE_INT:
				return CommandResult.new(false, &"invalid_request")
			available = game.recruit_availability(commander.team, values.get("id", &""), int(values.get("route", -1)))
			if not available.allowed:
				return CommandResult.new(false, available.reason)
			event_type = &"recruit"
			success = game._purchase(commander.team.team_id, values.id, bool(values.get("feedback", false)), values.route)
		MatchCommand.Action.UPGRADE:
			if not typeof(values.get("id")) in [TYPE_STRING, TYPE_STRING_NAME]:
				return CommandResult.new(false, &"invalid_request")
			available = game.upgrade_availability(commander.team, values.get("id", &""))
			if not available.allowed:
				return CommandResult.new(false, available.reason)
			event_type = &"upgrade"
			success = game._purchase_upgrade(commander.team.team_id, values.id, bool(values.get("feedback", false)))
		MatchCommand.Action.BUILD:
			if typeof(values.get("pad")) != TYPE_OBJECT or not is_instance_valid(values.pad):
				return CommandResult.new(false, &"invalid_target")
			event_type = &"tower_built"
			if not typeof(values.get("tower_id", &"guard")) in [TYPE_STRING, TYPE_STRING_NAME]:
				return CommandResult.new(false, &"invalid_request")
			success = game._build_tower(commander, values.get("pad"), StringName(values.get("tower_id", &"guard")))
		MatchCommand.Action.UPGRADE_TOWER:
			if typeof(values.get("pad")) != TYPE_OBJECT or not is_instance_valid(values.pad):
				return CommandResult.new(false, &"invalid_target")
			event_type = &"tower_upgrade"
			success = game._upgrade_tower(commander, values.get("pad"))
		MatchCommand.Action.ALLY_ORDER:
			if not typeof(values.get("order")) in [TYPE_STRING, TYPE_STRING_NAME]:
				return CommandResult.new(false, &"invalid_request")
			success = game.coordination.set_order(commander, values.get("order", &""))
		MatchCommand.Action.RALLY:
			success = game.coordination.rally(commander)
		MatchCommand.Action.REGROUP:
			success = game.coordination.regroup(commander)
		MatchCommand.Action.INPUT:
			if not commander.alive:
				return CommandResult.new(false, &"invalid_actor")
			if typeof(values.get("direction", Vector2.ZERO)) != TYPE_VECTOR2 or not typeof(values.get("delta", STEP)) in [TYPE_INT, TYPE_FLOAT]:
				return CommandResult.new(false, &"invalid_input")
			if values.get("target") != null and typeof(values.target) != TYPE_OBJECT:
				return CommandResult.new(false, &"invalid_target")
			var direction: Vector2 = values.get("direction", Vector2.ZERO)
			if not direction.is_finite():
				return CommandResult.new(false, &"invalid_input")
			if values.has("goal") and (typeof(values.goal) != TYPE_VECTOR2 or not values.goal.is_finite()):
				return CommandResult.new(false, &"invalid_input")
			if values.has("speed_limit") and (not typeof(values.speed_limit) in [TYPE_INT, TYPE_FLOAT] or not is_finite(values.speed_limit) or values.speed_limit <= 0):
				return CommandResult.new(false, &"invalid_input")
			var elapsed: float = values.get("delta", STEP)
			if not is_finite(elapsed) or elapsed <= 0.0 or elapsed > 1.0:
				return CommandResult.new(false, &"invalid_input")
			commander.apply_input(values)
			success = true
		_:
			return CommandResult.new(false, &"invalid_action")
	if success and event_type != &"" and game.coordination != null:
		var created: CombatEntity = null
		if event_type == &"recruit":
			created = game.entities.get_child(game.entities.get_child_count() - 1)
			created.owner_commander_id = commander.commander_id
		elif event_type == &"tower_built":
			created = values.pad.tower
			created.owner_commander_id = commander.commander_id
		game.coordination.purchase(commander, event_type, values.get("id", values.get("tower_id", &"guard")), before.x - commander.team.money, before.y - commander.team.wood, created)
	if success and event_type != &"" and game.coordination != null:
		game.coordination.revalidate_plans()
	return CommandResult.new(success, &"ok" if success else &"unavailable")

func publish(event: Dictionary) -> void:
	var copy := event.duplicate(true)
	copy["t"] = game.match_seconds
	copy["tick"] = ticks
	publishing = true
	match_event.emit(copy)
	publishing = false

func _cancel_pending() -> void:
	var batch := pending
	pending = []
	for request in batch:
		command_completed.emit(request.receipt, CommandResult.new(false, &"cancelled"))

func _clear_input() -> void:
	if game == null:
		return
	for commander in game.commanders:
		commander.end_camera_scouting(true)
		if commander.controller.has_method("cancel_pending_ability"):
			commander.controller.cancel_pending_ability()
		if commander.controller.has_method("reset_touch"):
			commander.controller.reset_touch()
		if commander.controller.has_method("clear_scripted_command"):
			commander.controller.clear_scripted_command()
		commander.strike_target = null
		commander.strike_remaining = 0.0
