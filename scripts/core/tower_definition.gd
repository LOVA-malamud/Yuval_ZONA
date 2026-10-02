class_name TowerDefinition
extends Resource
## Match-local tower construction and combat data shared by UI, AI and simulation.
@export var id: StringName = &"guard"
@export var display_name: StringName = &"TOWER_GUARD"
@export var money_cost: int = 140
@export var wood_cost: int = 55
@export var max_health: float = 480.0
@export var damage: float = 18.0
@export var attack_cooldown: float = 1.2
@export var attack_range: float = 245.0
@export var minimum_range: float = 0.0
@export var splash_radius: float = 0.0
