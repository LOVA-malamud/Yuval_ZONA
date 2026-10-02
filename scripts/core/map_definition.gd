class_name MapDefinition
extends Resource
@export var bounds := Vector2(4600, 2600)
@export var obstacles: Array[Rect2] = []
@export var routes: Array[PackedVector2Array] = []
@export var bases: Array[Vector2] = [Vector2(400, 1300), Vector2(4200, 1300)]
@export var home_pads: Array[Vector2] = [Vector2(750, 1250), Vector2(1090, 900), Vector2(1090, 1770)]
@export var neutral_pads: Array[Vector2] = [Vector2(2300, 810), Vector2(2300, 1570), Vector2(2300, 2070)]
@export var tree_groves: Array[Dictionary] = []
@export var groves: Array[Vector2] = [Vector2(450, 950), Vector2(450, 1650), Vector2(1150, 650), Vector2(1150, 1950)]

func _init() -> void:
	obstacles = RouteMap.OBSTACLES.duplicate()
	# Defaults live here; navigation consumes the same resolved map as drawing.
	routes = [
		PackedVector2Array([Vector2(400,1300), Vector2(1000,1100), Vector2(1550,550), Vector2(2300,700), Vector2(3050,550), Vector2(3600,1100), Vector2(4200,1300)]),
		PackedVector2Array([Vector2(400,1300), Vector2(1000,1400), Vector2(1550,1250), Vector2(2300,1470), Vector2(3050,1250), Vector2(3600,1400), Vector2(4200,1300)]),
		PackedVector2Array([Vector2(400,1300), Vector2(1000,1600), Vector2(1550,2050), Vector2(2300,1950), Vector2(3050,2050), Vector2(3600,1600), Vector2(4200,1300)]),
	]

func tree_placements() -> Array[Dictionary]:
	# Safe stock is deliberately shallow; larger exposed trees sustain late games.
	# Candidate pairs are checked together to retain exact economic symmetry.
	var result: Array[Dictionary] = []
	var navigation := RouteMap.new(self)
	var zones := [
		{"id": &"home", "centers": [Vector2(450, 900), Vector2(450, 1630)], "count": 8, "wood": 60},
		{"id": &"transition", "centers": [Vector2(1120, 620), Vector2(1120, 1980)], "count": 4, "wood": 300},
		{"id": &"forward", "centers": [Vector2(1960, 650), Vector2(1930, 2010)], "count": 2, "wood": 500},
	]
	if not tree_groves.is_empty():
		zones = []
		for grove in tree_groves:
			zones.append({"id": grove.zone, "centers": [grove.center], "count": grove.count, "wood": grove.wood})
	for zone in zones:
		for center in zone.centers:
			var requested: int = int(zone.count)
			if requested < 1 or requested > 100 or int(zone.wood) < 1 or not center.is_finite() or center.x >= bounds.x * 0.5:
				push_error("Invalid grove: expected left-side center, 1–100 trees, and positive finite wood")
				return []
			var placed: int = 0
			for radius in range(11):
				for y in range(-radius, radius + 1):
					for x in range(-radius, radius + 1):
						if maxi(absi(x), absi(y)) != radius or placed >= int(zone.count):
							continue
						var point: Vector2 = center + Vector2(x, y) * 80.0
						var mirror := Vector2(bounds.x - point.x, point.y)
						if point.x >= bounds.x * 0.5 - 38.0 or not _tree_point_valid(point, navigation, result) or not _tree_point_valid(mirror, navigation, result):
							continue
						result.append({"position": point, "wood": int(zone.wood), "zone": zone.id, "side": 1})
						result.append({"position": mirror, "wood": int(zone.wood), "zone": zone.id, "side": 2})
						placed += 1
			if placed != requested:
				push_error("Grove %s at %s requested %d trees, but only %d accessible mirrored pairs fit" % [zone.id, center, requested, placed])
				return []
	return result

func _tree_point_valid(point: Vector2, navigation: RouteMap, existing: Array[Dictionary]) -> bool:
	if not navigation.walkable(point, 38.0):
		return false
	for base in bases:
		if point.distance_to(base) < 190.0:
			return false
	for pad in home_pads + neutral_pads:
		if point.distance_to(pad) < 100.0 or point.distance_to(Vector2(bounds.x - pad.x, pad.y)) < 100.0:
			return false
	for route in routes:
		for i in range(route.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, route[i], route[i + 1])) < 85.0:
				return false
	for tree in existing:
		if point.distance_to(tree.position) < 65.0:
			return false
	var base: Vector2 = bases[0] if point.x < bounds.x * 0.5 else bases[1]
	var route_to_tree: PackedVector2Array = navigation.path(base, point)
	return not route_to_tree.is_empty() and route_to_tree[-1].distance_to(point) < 1.0
