class_name TutorialDirector
extends Node
enum Stage { MOVE, ATTACK, RECRUIT, COORDINATE, TOWER, KING, COMPLETE }
var stage: Stage = Stage.MOVE
var game
var start_position := Vector2.ZERO
var dummy: CombatEntity
var recruited: bool = false
var selected_route: bool = false
var ordered: bool = false
var rallied: bool = false
var practice_defeated: bool = false
var tower_built: bool = false
var marker := Vector2.ZERO
const INSTRUCTIONS := ["TUTORIAL_MOVE", "TUTORIAL_ATTACK", "TUTORIAL_RECRUIT", "TUTORIAL_COORDINATE", "TUTORIAL_TOWER", "TUTORIAL_KING", "TUTORIAL_COMPLETE"]

func setup(owner_game) -> void:
	game = owner_game
	start_position = game.player.position
	game.teams[0].money = 750
	game.teams[0].wood = 300
	for commander in game.commanders:
		if not commander.human_controlled:
			commander.controller.decision_timer = INF
	game.teams[1].king.max_health = 120.0
	game.teams[1].king.health = 120.0
	game.teams[1].king.damage = 0.0
	game.teams[1].stats[&"king_health"] = 120.0
	game.teams[1].stats[&"king_damage"] = 0.0
	var practice_definition: UnitStats
	for definition in game.unit_data.values():
		if definition.tactical_role == &"melee":
			practice_definition = definition
			break
	dummy = game.catalog.army_scene.instantiate()
	dummy.configure(game.teams[1], game, practice_definition)
	dummy.position = start_position + Vector2(140, 0)
	dummy.practice_unit = true
	dummy.died.connect(func(_dead):
		practice_defeated = true
		if stage == Stage.ATTACK:
			stage = Stage.RECRUIT
	)
	game.teams[1].combat_count += 1
	dummy.died.connect(game._on_recruit_died)
	game.entities.add_child(dummy)
	game.session.match_event.connect(_event)
	marker = dummy.position

func _event(event: Dictionary) -> void:
	if event.type == "route_selected":
		selected_route = true
	elif event.type == "recruit" and event.team == 1 and event.id != "worker":
		recruited = true
	elif event.type == "ally_order":
		ordered = true
	elif event.type == "rally" and event.team == 1 and event.affected > 0:
		rallied = true
	elif event.type == "tower_built" and event.team == 1:
		tower_built = true
		if stage == Stage.TOWER:
			stage = Stage.KING

func step_gameplay() -> void:
	if stage == Stage.MOVE and game.player.position.distance_to(start_position) >= 60.0:
		stage = Stage.ATTACK
	if stage == Stage.ATTACK and practice_defeated:
		stage = Stage.RECRUIT
	elif stage == Stage.RECRUIT and recruited and selected_route:
		stage = Stage.COORDINATE
	elif stage == Stage.COORDINATE and ordered and rallied:
		stage = Stage.TOWER
	if stage == Stage.TOWER:
		marker = game.pads[0].position
		if tower_built:
			stage = Stage.KING
	elif stage == Stage.KING:
		marker = game.teams[1].base_position
	if game.match_finished:
		stage = Stage.COMPLETE

func instruction() -> String:
	return tr(INSTRUCTIONS[stage])
