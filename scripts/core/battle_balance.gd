class_name BattleBalance
extends Resource
## Shared tuning for structures and commander strategy. Unit/upgrade data stays in .tres.
@export var tower_money: int = 140
@export var tower_wood: int = 55
@export var tower_health: float = 480.0
@export var tower_damage: float = 18.0
@export var tower_range: float = 245.0
@export var tower_cooldown: float = 1.2
@export var tower_rebuild_delay: float = 8.0
@export var build_reach: float = 150.0
@export var ally_money_reserve: int = 120
@export var ally_wood_reserve: int = 45
@export var aggressive_decision_seconds: float = 6.5
@export var economic_decision_seconds: float = 9.0

@export var commander_health: float = 180.0
@export var commander_strike_windup: float = 0.10
@export var commander_respawn: float = 12.0
@export var base_heal_cooldown: float = 30.0
