class_name MatchRules
extends Resource
@export var worker_cap: int = 10
@export var army_cap: int = 40
@export var worker_cost: int = 65
@export var starting_gold: int = 210
@export var starting_wood: int = 35
@export var starting_workers: int = 3
@export var rally_wait_seconds: float = 6.0
@export var army_speed_multiplier: float = 1.0
@export var difficulty: StringName = &"standard"

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if worker_cap <= 0 or army_cap <= 0 or worker_cost < 0 or starting_gold < 0 or starting_wood < 0 or starting_workers < 0 or starting_workers > worker_cap:
		errors.append("Invalid match caps, costs or starting resources")
	if not is_finite(rally_wait_seconds) or rally_wait_seconds <= 0 or not is_finite(army_speed_multiplier) or army_speed_multiplier <= 0:
		errors.append("Invalid grouping wait or army speed")
	if not difficulty in [&"easy", &"standard", &"hard"]:
		errors.append("Unknown difficulty")
	return errors
