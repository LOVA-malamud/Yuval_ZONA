class_name RouteMap
extends RefCounted
## Static terrain is shared by drawing, swept movement, line of sight and A*.
## Armies retain lane waypoints; local A* only handles detours/pursuit/worker trips.

const SIZE := Vector2(4600, 2600)
const CELL: float = 50.0
const LANE_NAMES := ["LANE_NORTH", "LANE_CENTER", "LANE_SOUTH"]
const OBSTACLES: Array[Rect2] = [
	Rect2(1300, 800, 650, 260), Rect2(2100, 940, 450, 290),
	Rect2(2700, 800, 600, 260), Rect2(1300, 1530, 580, 260),
	Rect2(2070, 1700, 460, 100), Rect2(2720, 1530, 580, 260),
	Rect2(650, 450, 290, 310), Rect2(3660, 450, 290, 310),
	Rect2(650, 1900, 290, 280), Rect2(3660, 1900, 290, 280),
]
var grid := AStarGrid2D.new()
var lanes: Array[PackedVector2Array] = []
var bounds := SIZE
var obstacles: Array[Rect2] = []

func _init(definition: MapDefinition = null) -> void:
	var resolved := definition if definition != null else MapDefinition.new()
	bounds = resolved.bounds
	obstacles = resolved.obstacles.duplicate()
	lanes = resolved.routes.duplicate()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i((bounds / CELL).ceil()))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(grid.region.size.x):
		for y in range(grid.region.size.y):
			var p := Vector2(x + 0.5, y + 0.5) * CELL
			if not walkable(p, 28.0):
				grid.set_point_solid(Vector2i(x, y))

func walkable(point: Vector2, radius: float = 0.0) -> bool:
	if not Rect2(Vector2.ONE * radius, bounds - Vector2.ONE * radius * 2.0).has_point(point):
		return false
	for obstacle in obstacles:
		if obstacle.grow(radius).has_point(point):
			return false
	return true

func clear_line(start: Vector2, finish: Vector2, radius: float = 0.0) -> bool:
	var minimum: Vector2 = start.min(finish)
	var maximum: Vector2 = start.max(finish)
	for obstacle in obstacles:
		var box: Rect2 = obstacle.grow(radius)
		# Most local movement/attack segments are nowhere near an obstacle. Reject
		# their bounds before allocating corners and running exact edge tests.
		# Strict comparisons retain the original edge/corner-touch behavior.
		if maximum.x < box.position.x or minimum.x > box.end.x or maximum.y < box.position.y or minimum.y > box.end.y:
			continue
		if box.has_point(start) or box.has_point(finish):
			return false
		var corners := [box.position, box.position + Vector2(box.size.x, 0), box.end, box.position + Vector2(0, box.size.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(start, finish, corners[i], corners[(i + 1) % 4]) != null:
				return false
	return true

func move(start: Vector2, displacement: Vector2, radius: float) -> Vector2:
	# Small swept steps prevent tunneling even when a frame stalls.
	var count: int = maxi(1, int(ceil(displacement.length() / 12.0)))
	var step: Vector2 = displacement / float(count)
	var point: Vector2 = start
	for i in range(count):
		var next: Vector2 = point + step
		if walkable(next, radius):
			point = next
		else:
			if walkable(point + Vector2(step.x, 0), radius):
				point.x += step.x
			if walkable(point + Vector2(0, step.y), radius):
				point.y += step.y
	return point

func path(start: Vector2, finish: Vector2) -> PackedVector2Array:
	if clear_line(start, finish, 28.0):
		return PackedVector2Array([finish])
	var from_cell: Vector2i = _open_cell(start)
	var to_cell: Vector2i = _open_cell(finish)
	var points: PackedVector2Array = grid.get_point_path(from_cell, to_cell)
	if points.size() > 0:
		points.remove_at(0)
		if walkable(finish, 28.0):
			points.append(finish)
	return points

func _open_cell(point: Vector2) -> Vector2i:
	var cell := Vector2i((point / CELL).floor()).clamp(Vector2i.ZERO, grid.region.size - Vector2i.ONE)
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, 12):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return cell

func army_route(lane: int, reverse: bool) -> PackedVector2Array:
	var route: PackedVector2Array = lanes[clampi(lane, 0, lanes.size() - 1)].duplicate()
	if reverse:
		route.reverse()
	return route
