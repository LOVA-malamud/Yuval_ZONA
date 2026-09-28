extends Control
## Strategic overview refreshes at 5 Hz; shapes retain team identity without color.
const INK := Color("10262c")
var game = null
var refresh_time: float = 0.0
var lane_points: Array[PackedVector2Array] = []
var cached_size := Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time <= 0.0:
		refresh_time = 0.2
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("243d38"))
	if game == null:
		return
	var factor: Vector2 = size / game.MAP_SIZE
	if cached_size != size or lane_points.is_empty():
		cached_size = size
		lane_points.clear()
		for lane in game.navigation.lanes:
			var points := PackedVector2Array()
			for point in lane:
				points.append(point * factor)
			lane_points.append(points)
	for lane_index in range(3):
		draw_polyline(lane_points[lane_index], Color("ead59d") if lane_index == game.selected_route else Color("837c5d"), 4 if lane_index == game.selected_route and game.route_highlight > 0 else 2, true)
	for obstacle in RouteMap.OBSTACLES:
		draw_rect(Rect2(obstacle.position * factor, obstacle.size * factor), Color("112f2c"))
	for tree in get_tree().get_nodes_in_group("trees"):
		if tree.available():
			draw_circle(tree.position * factor, 1.7, Color("65a774"))
	# The footprint is behind strategic markers so it cannot obscure commanders.
	var camera: Camera2D = game.player.get_node("Camera2D")
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	var view := Rect2((camera.get_screen_center_position() - view_size / 2) * factor, view_size * factor)
	var clipped_view: Rect2 = view.intersection(Rect2(Vector2.ZERO, size))
	if clipped_view.has_area():
		draw_rect(clipped_view, Color(1, 1, 1, 0.035))
		draw_rect(clipped_view, Color(1, 1, 1, 0.42), false, 1)
	var clusters: Dictionary = {}
	for entity in get_tree().get_nodes_in_group("combatants"):
		if entity.kind in [&"king", &"player", &"tower", &"worker"]:
			continue
		var cell := Vector2i((entity.position / 160).floor())
		var key := Vector3i(cell.x,cell.y,entity.team.team_id)
		if not clusters.has(key):
			clusters[key] = {"sum":Vector2.ZERO,"count":0,"color":entity.team.color,"team":entity.team.team_id}
		clusters[key]["sum"] += entity.position
		clusters[key]["count"] += 1
	for cluster in clusters.values():
		var p: Vector2 = cluster["sum"] / float(cluster["count"]) * factor
		var radius: float = minf(4.5, 1.6 + sqrt(cluster["count"]) * 0.6)
		_team_marker(p, radius + 1.0, cluster["team"], INK)
		_team_marker(p, radius, cluster["team"], cluster["color"])
	for pad in game.pads:
		var p: Vector2 = pad.position * factor
		if pad.occupied():
			draw_rect(Rect2(p - Vector2.ONE * 3.5, Vector2.ONE * 7), INK)
			draw_rect(Rect2(p - Vector2.ONE * 2.5, Vector2.ONE * 5), pad.tower.team.color)
			draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE * 2), INK)
		elif pad.rebuild_remaining <= 0:
			draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color("ccbb8d"), 1.5)
			draw_line(p - Vector2(0, 2), p + Vector2(0, 2), Color("ccbb8d"), 1.5)
	for commander in game.commanders:
		if not commander.alive:
			continue
		var p: Vector2 = commander.position * factor
		_commander_marker(p, 6, commander.team.team_id, INK)
		_commander_marker(p, 4.5, commander.team.team_id, commander.team.color)
		if commander.human_controlled:
			draw_arc(p, 7, 0, TAU, 20, Color.WHITE, 1.5, true)
	# Kings sit above army groups and retain their crown silhouette in dense fights.
	for team in game.teams:
		var p: Vector2 = team.base_position * factor
		draw_circle(p, 7, INK)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-5,3),p+Vector2(-6,-4),p+Vector2(-2,-1),p+Vector2(0,-6),p+Vector2(2,-1),p+Vector2(6,-4),p+Vector2(5,3)]), Color("edcc85"))
		draw_rect(Rect2(p + Vector2(-4, 2), Vector2(8, 3)), team.color)
		if is_instance_valid(team.king) and team.king.danger_remaining > 0:
			draw_arc(p, 10 + sin(game.match_seconds * 5), 0, TAU, 24, Color("ffdf97"), 2, true)
	draw_rect(Rect2(Vector2.ZERO,size),Color("60766b"),false,1)

func _team_marker(point: Vector2, radius: float, team_id: int, tint: Color) -> void:
	if team_id == 1:
		draw_circle(point, radius, tint)
	else:
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, radius), point + Vector2(-radius, radius)]), tint)

func _commander_marker(point: Vector2, radius: float, team_id: int, tint: Color) -> void:
	if team_id == 1:
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0)]), tint)
	else:
		draw_colored_polygon(PackedVector2Array([point + Vector2(-radius, -radius), point + Vector2(radius, -radius), point + Vector2(0, radius)]), tint)
