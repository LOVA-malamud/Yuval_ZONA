class_name UnitStats
extends Resource
## Shared immutable starting values. Each entity copies these when spawned.

@export var id: StringName = &"melee"
@export var tactical_role: StringName = &"melee"
@export var display_name: String = "UNIT_MELEE"
@export var money_cost: int = 50
@export var max_health: float = 110.0
@export var damage: float = 16.0
@export var move_speed: float = 105.0
@export var attack_range: float = 26.0
@export var attack_cooldown: float = 0.85
@export var detection_range: float = 260.0
@export var body_radius: float = 13.0

@export var structure_damage_multiplier: float = 1.0
