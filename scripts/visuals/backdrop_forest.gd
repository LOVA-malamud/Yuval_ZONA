class_name BackdropForest
extends Node2D
## Deterministic decorative-only pine backdrop behind each castle. Baked into one
## mesh so density never adds per-tree nodes/draw calls. Never harvestable: never
## added to $Trees or the "trees" group, so economy/minimap code can't see it.

const SEED: int = 4091
const CELL: float = 34.0            # jitter-grid resolution (px)
const EDGE_MARGIN: float = 40.0     # keep off the map border
const DEPTH_MARGIN: float = 40.0    # keep off the base's own x coordinate / lane start
const BASE_CLEARANCE: float = 300.0 # Euclidean clearance from castle art + banners
const PAD_CLEARANCE: float = 100.0  # matches MapDefinition._tree_point_valid
const ROUTE_CLEARANCE: float = 85.0 # matches MapDefinition._tree_point_valid
const OBSTACLE_CLEARANCE: float = 20.0
const ECONOMY_CLEARANCE: float = 70.0
const NEAR_DENSITY: float = 0.90    # fill probability right behind the castle
const FAR_DENSITY: float = 0.06     # fill probability near the map edge (never 0: no hard edge)

var map_definition: MapDefinition
var economy_positions: PackedVector2Array
var mesh: ArrayMesh

func _ready() -> void:
	var points := generate_points(map_definition, economy_positions, SEED)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for entry in points:
		_add_tree(vertices, colors, entry.position, entry.scale, entry.tint)
	var mesh_arrays: Array = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	queue_redraw()

func _draw() -> void:
	if mesh != null:
		draw_mesh(mesh, null)

## Pure, scene-tree-free: callable directly from a regression fixture.
static func generate_points(map: MapDefinition, economy_positions: PackedVector2Array, rng_seed: int = SEED) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var base: Vector2 = map.bases[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var min_x := EDGE_MARGIN
	var max_x := base.x - DEPTH_MARGIN
	var min_y := EDGE_MARGIN
	var max_y := map.bounds.y - EDGE_MARGIN
	if max_x <= min_x:
		return result
	var max_depth := max_x - min_x
	var y := min_y
	while y < max_y:
		var x := min_x
		while x < max_x:
			var cell_center := Vector2(x, y) + Vector2.ONE * CELL * 0.5
			var t: float = clampf((max_x - cell_center.x) / max_depth, 0.0, 1.0)
			var density: float = lerpf(NEAR_DENSITY, FAR_DENSITY, smoothstep(0.0, 1.0, t))
			if rng.randf() < density:
				var point: Vector2 = cell_center + Vector2(rng.randf_range(-CELL, CELL), rng.randf_range(-CELL, CELL)) * 0.5
				var mirror := Vector2(map.bounds.x - point.x, point.y)
				var scale: float = rng.randf_range(0.82, 1.28)
				var tint: float = rng.randf()
				if _point_valid(point, map, economy_positions) and _point_valid(mirror, map, economy_positions):
					result.append({"position": point, "side": 1, "scale": scale, "tint": tint})
					result.append({"position": mirror, "side": 2, "scale": scale, "tint": tint})
			x += CELL
		y += CELL
	return result

static func _point_valid(point: Vector2, map: MapDefinition, economy_positions: PackedVector2Array) -> bool:
	if point.x < EDGE_MARGIN or point.x > map.bounds.x - EDGE_MARGIN:
		return false
	if point.y < EDGE_MARGIN or point.y > map.bounds.y - EDGE_MARGIN:
		return false
	for base in map.bases:
		if point.distance_to(base) < BASE_CLEARANCE:
			return false
	for pad in map.home_pads + map.neutral_pads:
		if point.distance_to(pad) < PAD_CLEARANCE or point.distance_to(Vector2(map.bounds.x - pad.x, pad.y)) < PAD_CLEARANCE:
			return false
	for route in map.routes:
		for i in range(route.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, route[i], route[i + 1])) < ROUTE_CLEARANCE:
				return false
	for obstacle in map.obstacles:
		if obstacle.grow(OBSTACLE_CLEARANCE).has_point(point):
			return false
	for tree_pos in economy_positions:
		if point.distance_to(tree_pos) < ECONOMY_CLEARANCE:
			return false
	return true

func _add_tree(vertices: PackedVector3Array, colors: PackedColorArray, point: Vector2, tree_scale: float, tint: float) -> void:
	var trunk := Color("4a3a28")
	var canopy := [Color("1f4a38").lerp(Color("28593f"), tint * 0.4), Color("28593f").lerp(Color("336b4c"), tint * 0.4)]
	_quad(vertices, colors, point + Vector2(-3, -6) * tree_scale, point + Vector2(3, -6) * tree_scale, point + Vector2(3, 10) * tree_scale, point + Vector2(-3, 10) * tree_scale, trunk)
	for i in range(2):
		var width: float = (26 - i * 8) * tree_scale
		var y: float = -i * 16 * tree_scale
		_tri(vertices, colors, point + Vector2(-width, y), point + Vector2(0, y - 34 * tree_scale), point + Vector2(width, y), canopy[i])

func _quad(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	for p in [a, b, c, a, c, d]:
		vertices.append(Vector3(p.x, p.y, 0))
		colors.append(color)

func _tri(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	for p in [a, b, c]:
		vertices.append(Vector3(p.x, p.y, 0))
		colors.append(color)
