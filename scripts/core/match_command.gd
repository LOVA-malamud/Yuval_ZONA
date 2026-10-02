class_name MatchCommand
extends RefCounted
## Requests carry their commander identity; callers cannot charge another team.
enum Action { RECRUIT, UPGRADE, BUILD, UPGRADE_TOWER, ALLY_ORDER, RALLY, REGROUP, INPUT, ABILITY }
var action: Action
var commander_id: int
var payload: Dictionary

func _init(kind: Action = Action.RECRUIT, requester: int = 0, values: Dictionary = {}) -> void:
	action = kind
	commander_id = requester
	payload = values.duplicate()
