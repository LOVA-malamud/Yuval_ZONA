class_name ContentCatalog
extends Resource
## Authoring resources stay immutable; every match receives its own copies.
@export var units: Array[UnitStats] = []
@export var upgrades: Array[UpgradeDefinition] = []
@export var army_scene: PackedScene
@export var worker_scene: PackedScene

func unit_definitions() -> Dictionary:
	var definitions := {}
	for unit in units:
		assert(not definitions.has(unit.id), "Duplicate unit definition")
		definitions[unit.id] = unit
	return definitions

@export var towers: Array[TowerDefinition] = []

func tower_definitions() -> Dictionary:
	var result := {}
	for definition in towers:
		assert(not result.has(definition.id), "Duplicate tower definition")
		result[definition.id] = definition
	return result
