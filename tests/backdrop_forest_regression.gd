extends SceneTree
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := MapDefinition.new()
	var economy_positions := PackedVector2Array()
	for entry in map.tree_placements():
		economy_positions.append(entry.position)
	check(economy_positions.size() == 56, "Backdrop forest test expects the harvestable economy to stay untouched")

	var points := BackdropForest.generate_points(map, economy_positions)
	check(points.size() > 400 and points.size() < 900, "Backdrop forest should be substantially denser than the economy groves")

	var side1: Array = []
	var side2: Array = []
	for entry in points:
		if entry.side == 1:
			side1.append(entry)
		else:
			side2.append(entry)
	check(side1.size() == side2.size(), "Backdrop forest must be balanced between the two sides")
	for entry in side1:
		var mirrored: bool = false
		for other in side2:
			var mirror_position: Vector2 = Vector2(map.bounds.x - entry.position.x, entry.position.y)
			if other.position == mirror_position and other.scale == entry.scale and other.tint == entry.tint:
				mirrored = true
				break
		check(mirrored, "Each backdrop tree needs a mirrored counterpart")

	var base: Vector2 = map.bases[0]
	var near_edge: float = base.x - BackdropForest.DEPTH_MARGIN
	var max_depth: float = near_edge - BackdropForest.EDGE_MARGIN
	var bands: Array = [0, 0, 0, 0]
	for entry in side1:
		var depth: float = clampf((near_edge - entry.position.x) / max_depth, 0.0, 1.0)
		var band: int = mini(3, int(depth * 4.0))
		bands[band] += 1
	check(bands[0] > bands[3], "Tree density must taper away from the castle")
	for i in range(3):
		check(bands[i] >= bands[i + 1], "Tree density must not increase farther from the castle")

	var navigation := RouteMap.new(map)
	for entry in points:
		var position: Vector2 = entry.position
		for match_base in map.bases:
			check(position.distance_to(match_base) >= BackdropForest.BASE_CLEARANCE, "Backdrop tree too close to a base")
		for pad in map.home_pads + map.neutral_pads:
			check(position.distance_to(pad) >= BackdropForest.PAD_CLEARANCE, "Backdrop tree too close to a pad")
			check(position.distance_to(Vector2(map.bounds.x - pad.x, pad.y)) >= BackdropForest.PAD_CLEARANCE, "Backdrop tree too close to a mirrored pad")
		for route in map.routes:
			for i in range(route.size() - 1):
				check(position.distance_to(Geometry2D.get_closest_point_to_segment(position, route[i], route[i + 1])) >= BackdropForest.ROUTE_CLEARANCE, "Backdrop tree too close to a route")
		for obstacle in navigation.obstacles:
			check(not obstacle.grow(BackdropForest.OBSTACLE_CLEARANCE).has_point(position), "Backdrop tree overlaps an obstacle")
		for tree_pos in economy_positions:
			check(position.distance_to(tree_pos) >= BackdropForest.ECONOMY_CLEARANCE, "Backdrop tree too close to a harvestable tree")

	var repeated := BackdropForest.generate_points(map, economy_positions)
	check(repeated.size() == points.size(), "Backdrop forest generation must be deterministic")
	for i in range(points.size()):
		check(repeated[i].position == points[i].position, "Backdrop forest generation must be deterministic")

	var game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var battlefield = game.get_node("Battlefield")
	var forest = null
	for child in battlefield.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("backdrop_forest.gd"):
			forest = child
	check(forest != null, "Battlefield must spawn a BackdropForest child")
	check(forest != null and forest.mesh != null, "BackdropForest must build a mesh")
	check(game.map_definition.tree_placements().size() == 56, "Harvestable economy must remain untouched")
	root.get_node("AudioFeedback").stop_all()
	game.free()
	await create_timer(0.1).timeout
	print("BACKDROP FOREST CHECK failures=", failures)
	quit(1 if failures else 0)
