class_name ContentCatalog
extends Resource
## Authoring resources stay immutable; every match receives its own copies.
@export var units: Array[UnitStats] = []
@export var upgrades: Array[UpgradeDefinition] = []
@export var army_scene: PackedScene
@export var worker_scene: PackedScene

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var identities := {}
	if army_scene == null or worker_scene == null or units.is_empty():
		errors.append("Catalog needs army/worker scenes and unit definitions")
	for unit in units:
		if unit == null:
			errors.append("Catalog contains a missing unit")
			continue
		if unit.id == &"" or identities.has(unit.id) or unit.id in [&"worker", &"king", &"tower", &"player"]:
			errors.append("Invalid or duplicate unit ID: %s" % unit.id)
		identities[unit.id] = true
		if not unit.tactical_role in [&"melee", &"ranged", &"tank"] or unit.money_cost < 0:
			errors.append("Invalid unit role/cost: %s" % unit.id)
		if tr(unit.display_name) == unit.display_name:
			errors.append("Missing unit translation: %s" % unit.display_name)
		for field in ["max_health", "move_speed", "attack_range", "attack_cooldown", "detection_range", "body_radius"]:
			var value: float = unit.get(field)
			if not is_finite(value) or value <= 0:
				errors.append("Invalid unit value: %s.%s" % [unit.id, field])
		if not is_finite(unit.damage) or unit.damage < 0 or not is_finite(unit.structure_damage_multiplier) or unit.structure_damage_multiplier < 0:
			errors.append("Invalid unit damage: %s" % unit.id)
	identities.clear()
	var defaults := GameTeam.new()
	for upgrade in upgrades:
		if upgrade == null:
			errors.append("Catalog contains a missing upgrade")
			continue
		if upgrade.id == &"" or identities.has(upgrade.id) or not defaults.base_stats.has(upgrade.stat):
			errors.append("Invalid upgrade ID/stat: %s" % upgrade.id)
		identities[upgrade.id] = true
		if upgrade.base_cost < 0 or upgrade.maximum_level <= 0 or not is_finite(upgrade.cost_growth) or upgrade.cost_growth <= 0 or not is_finite(upgrade.amount):
			errors.append("Invalid upgrade values: %s" % upgrade.id)
	defaults.free()
	return errors

func unit_definitions() -> Dictionary:
	var definitions := {}
	for unit in units:
		assert(not definitions.has(unit.id), "Duplicate unit definition")
		definitions[unit.id] = unit
	return definitions
