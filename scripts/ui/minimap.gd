extends Control
## Strategic overview refreshes at 5 Hz; shapes retain team identity without color.
const INK := Color("10262c")
var game = null
var refresh_time: float = 0.0
var lane_points: Array[PackedVector2Array] = []
var cached_size := Vector2.ZERO
# -1 means no touch; mouse ownership is separate to avoid emulated mouse takeover.
var scouting_finger: int = -1
var scouting_mouse: bool = false
var gesture_rect := Rect2()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	tooltip_text = tr("MINIMAP_SCOUT_HINT")

func _process(delta: float) -> void:
	tooltip_text = tr("MINIMAP_SCOUT_HINT")
	if scouting_finger >= 0 or scouting_mouse:
		if not _can_scout() or gesture_rect != get_global_rect() or not game.player.scouting:
			cancel_scouting(true)
		else:
			game.player.update_scout_camera()
	refresh_time -= delta
	if refresh_time <= 0.0:
		refresh_time = 0.2
		queue_redraw()

func _can_scout() -> bool:
	return is_visible_in_tree() and game != null and is_instance_valid(game.player) and game.player.alive and game.session.state == MatchSession.State.RUNNING and not game.match_finished and not get_tree().paused

func _scout_at(screen_position: Vector2) -> void:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_position
	var fraction := Vector2(clampf(local.x / size.x, 0.0, 1.0), clampf(local.y / size.y, 0.0, 1.0))
	game.player.scout_camera(fraction * game.MAP_SIZE)
	queue_redraw()

func cancel_scouting(immediate: bool = false) -> void:
	scouting_finger = -1
	scouting_mouse = false
	if game != null and is_instance_valid(game.player):
		game.player.end_camera_scouting(immediate)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not _can_scout():
		if scouting_finger >= 0 or scouting_mouse:
			cancel_scouting(true)
		return
	if event is InputEventScreenTouch:
		if event.pressed and get_global_rect().has_point(event.position):
			if scouting_finger < 0 and not scouting_mouse:
				scouting_finger = event.index
				gesture_rect = get_global_rect()
				_scout_at(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == scouting_finger:
			cancel_scouting(event.canceled)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == scouting_finger:
		_scout_at(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and get_global_rect().has_point(event.position):
				if scouting_finger < 0 and not scouting_mouse:
					scouting_mouse = true
					gesture_rect = get_global_rect()
					_scout_at(event.position)
				get_viewport().set_input_as_handled()
			elif not event.pressed and scouting_mouse:
				cancel_scouting()
				get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and get_global_rect().has_point(event.position):
			# GUI consumes wheel events, so explicitly retain the player's existing zoom.
			game.player._unhandled_input(event)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and scouting_mouse:
		_scout_at(event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		cancel_scouting(true)

func _exit_tree() -> void:
	cancel_scouting(true)

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
	for lane_index in range(game.navigation.lanes.size()):
		draw_polyline(lane_points[lane_index], Color("ead59d") if lane_index == game.selected_route else Color("837c5d"), 4 if lane_index == game.selected_route and game.route_highlight > 0 else 2, true)
	for obstacle in game.navigation.obstacles:
		draw_rect(Rect2(obstacle.position * factor, obstacle.size * factor), Color("112f2c"))
	for tree in game.get_node("Trees").get_children():
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
	for entity in game.session.actors.values():
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
	for alert in game.coordination.alerts:
		if alert.team == game.player.team.team_id and game.match_seconds - alert.t < 10.0:
			var point := Vector2(alert.position[0], alert.position[1]) * factor
			draw_arc(point, 9.0, 0.0, TAU, 20, Color("ffdf97"), 2.0, true)
	if game.tutorial != null and not game.match_finished:
		draw_circle(game.tutorial.marker * factor, 6.0, Color.WHITE)
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
