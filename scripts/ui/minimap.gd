extends Control
var game = null
var refresh_time: float = 0.0

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
	for lane_index in range(3):
		var lane: PackedVector2Array = game.navigation.lanes[lane_index]
		var points := PackedVector2Array()
		for point in lane:
			points.append(point * factor)
		draw_polyline(points, Color("ffe2a0") if lane_index == game.selected_route else Color("aa9d70"), 5 if lane_index == game.selected_route and game.route_highlight > 0 else 3, true)
	for obstacle in RouteMap.OBSTACLES:
		draw_rect(Rect2(obstacle.position * factor, obstacle.size * factor), Color("112f2c"))
	for tree in get_tree().get_nodes_in_group("trees"):
		if tree.available():
			draw_circle(tree.position * factor, 1.7, Color("65a774"))
	for pad in game.pads:
		var color: Color = pad.tower.team.color if pad.occupied() else Color("ccbb8d")
		draw_rect(Rect2(pad.position * factor - Vector2.ONE * 2, Vector2.ONE * 4), color, pad.occupied())
	var clusters: Dictionary = {}
	for entity in get_tree().get_nodes_in_group("combatants"):
		if entity.kind in [&"king", &"player", &"tower", &"worker"]:
			continue
		var cell := Vector2i((entity.position / 160).floor())
		var key := Vector3i(cell.x,cell.y,entity.team.team_id)
		if not clusters.has(key):
			clusters[key] = {"sum":Vector2.ZERO,"count":0,"color":entity.team.color}
		clusters[key]["sum"] += entity.position
		clusters[key]["count"] += 1
	for cluster in clusters.values():
		var p: Vector2 = cluster["sum"] / float(cluster["count"]) * factor
		draw_circle(p,minf(4.5,1.6+sqrt(cluster["count"])*0.6),Color(cluster["color"],0.8))
	for team in game.teams:
		var p: Vector2 = team.base_position * factor
		draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),Color("edcc85"))
		draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),team.color)
		if is_instance_valid(team.king) and team.king.danger_remaining > 0:
			draw_arc(p,9+sin(game.match_seconds*5)*2,0,TAU,16,Color("ffdf97"),2,true)
	for commander in game.commanders:
		if not commander.alive:
			continue
		var p: Vector2 = commander.position * factor
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4),p+Vector2(4,0),p+Vector2(0,4),p+Vector2(-4,0)]),commander.team.color)
		if commander.human_controlled:
			draw_arc(p,6,0,TAU,16,Color.WHITE,1.5,true)
	var camera: Camera2D = game.player.get_node("Camera2D")
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	var view := Rect2((camera.get_screen_center_position() - view_size/2)*factor, view_size*factor)
	draw_rect(view.intersection(Rect2(Vector2.ZERO,size)),Color(1,1,1,0.3),false,1)
	draw_rect(Rect2(Vector2.ZERO,size),Color("60766b"),false,1)
