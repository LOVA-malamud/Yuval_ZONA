class_name UpgradeDefinition
extends Resource
## Adding a stat upgrade requires a resource plus an entry in GameTeam.base_stats.

@export var id: StringName
@export var display_name: String
@export_enum("king", "worker", "economy") var category: String = "king"
@export var stat: StringName
@export var base_cost: int = 35
@export var cost_growth: float = 1.55
@export var amount: float = 1.0
@export var maximum_level: int = 8
@export var unit: String = ""


func cost(level: int) -> int:
	return int(ceil(float(base_cost) * pow(cost_growth, level)))
