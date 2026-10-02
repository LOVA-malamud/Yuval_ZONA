extends Node2D
## Deterministic terrain dressing generated once, not every frame.
var grass_mesh: ArrayMesh
var pebbles: PackedVector2Array

func _ready() -> void:
	var bounds: Vector2 = get_parent().map_definition.bounds
	var rng := RandomNumberGenerator.new()
	rng.seed = 1073
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for i in range(1900):
		var point := Vector2(rng.randf_range(35,bounds.x - 35),rng.randf_range(35,bounds.y - 35))
		_grass_line(vertices, colors, point, point + Vector2(-3, -6), Color("3a5745"))
		_grass_line(vertices, colors, point, point + Vector2(3, -7), Color("405d48"))
	var mesh_arrays: Array = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	grass_mesh = ArrayMesh.new()
	grass_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	for i in range(320):
		pebbles.append(Vector2(rng.randf_range(35,bounds.x - 35),rng.randf_range(35,bounds.y - 35)))
	queue_redraw()

func _draw() -> void:
	var game = get_parent()
	var map = game.navigation
	draw_rect(Rect2(Vector2.ZERO, game.MAP_SIZE), Color("304b3e"))
	# One immutable mesh keeps 3,800 decorative strokes out of the per-frame
	# CanvasItem command traversal. Each quad has the original width and color.
	draw_mesh(grass_mesh, null)
	for p in pebbles:
		draw_circle(p,3,Color("526653"))
	for lane in map.lanes:
		draw_polyline(lane, Color("263e33"), 180.0, true)
		draw_polyline(lane, Color("706e51"), 152.0, true)
		draw_polyline(lane, Color("8d8160"), 127.0, true)
		draw_polyline(lane, Color("978967"), 92.0, true)
		for i in range(lane.size()-1):
			var distance: float = lane[i].distance_to(lane[i+1])
			for j in range(int(distance/65)):
				var p: Vector2 = lane[i].lerp(lane[i+1],float(j)*65.0/distance)
				draw_line(p+Vector2(-5,7),p+Vector2(6,3),Color("827655"),2)
	for obstacle in map.obstacles:
		draw_rect(Rect2(obstacle.position+Vector2(12,18),obstacle.size),Color("203a32"))
		draw_rect(obstacle.grow(6),Color("283b34"))
		draw_rect(obstacle,Color("59685b"))
		draw_rect(Rect2(obstacle.position,Vector2(obstacle.size.x,12)),Color("8a9275"))
		draw_rect(Rect2(obstacle.position+Vector2(10,12),obstacle.size-Vector2(20,27)),Color("4c6350"))
		for x in range(int(obstacle.position.x+25),int(obstacle.end.x-10),60):
			draw_line(Vector2(x,obstacle.end.y-10),Vector2(x+15,obstacle.end.y),Color("354f42"),3)
	for team in game.teams:
		var base: Vector2 = team.base_position
		draw_circle(base,240,Color("59685a"))
		draw_circle(base,219,Color("4b5a51"))
		draw_arc(base,219,0,TAU,64,Color(team.color,0.5),4,true)
		draw_circle(base,90,Color("718079"))
		draw_circle(base,76,Color("536965"))
		for i in range(12):
			var direction := Vector2.from_angle(i*TAU/12)
			draw_line(base+direction*92,base+direction*205,Color("67776a"),2)
		for dy in [-195,195]:
			for dx in [-120,120]:
				_banner(base+Vector2(dx,dy),team.color)
		var heading: String = tr("CITADEL") % tr(team.display_name).to_upper()
		draw_string(ThemeDB.fallback_font,base+Vector2(-230,277),heading,HORIZONTAL_ALIGNMENT_CENTER,460,22,Color(team.color,0.8))
	for lane in range(3):
		# Quiet landmarks sit outside the fighting line, not underneath silhouettes.
		var p: Vector2 = [Vector2(2170,560),Vector2(2140,1180),Vector2(2160,2170)][lane]
		draw_string(ThemeDB.fallback_font,p,tr(["MAP_NORTH","MAP_CENTER","MAP_SOUTH"][lane]),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("8c9877"))
	for mirror in [false,true]:
		var x: float = 3370 if mirror else 1000
		for y in [540,2140]:
			draw_string(ThemeDB.fallback_font,Vector2(x,y),tr("MAP_GROVE"),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b2c196"))
	for pad in game.pads:
		if pad.home_team_id == 0:
			draw_string(ThemeDB.fallback_font, pad.position + Vector2(-140, 85), tr("MAP_NEUTRAL_PAD"), HORIZONTAL_ALIGNMENT_CENTER, 280, 12, Color("c8bc91"))
	for mirrored in [false, true]:
		for grove in game.map_definition.groves:
			if grove.x > 1000:
				var point: Vector2 = Vector2(game.MAP_SIZE.x - grove.x if mirrored else grove.x, grove.y + 150)
				draw_string(ThemeDB.fallback_font, point + Vector2(-120, 0), tr("MAP_RENEWABLE"), HORIZONTAL_ALIGNMENT_CENTER, 280, 12, Color("b2c196"))
	draw_rect(Rect2(Vector2.ZERO,game.MAP_SIZE),Color("a59b76"),false,12)

func _grass_line(vertices: PackedVector3Array, colors: PackedColorArray, start: Vector2, finish: Vector2, color: Color) -> void:
	var edge: Vector2 = (finish - start).orthogonal().normalized() * 0.75
	for point in [start + edge, start - edge, finish + edge, finish + edge, start - edge, finish - edge]:
		vertices.append(Vector3(point.x, point.y, 0))
		colors.append(color)

func _banner(point: Vector2, tint: Color) -> void:
	draw_circle(point+Vector2(0,6),13,Color("293e35"))
	draw_line(point,point+Vector2(0,-65),Color("c0a879"),4)
	draw_colored_polygon(PackedVector2Array([point+Vector2(3,-63),point+Vector2(33,-56),point+Vector2(26,-29),point+Vector2(3,-37)]),tint.darkened(0.12))
	draw_line(point+Vector2(12,-51),point+Vector2(25,-48),Color("edce8e"),3)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()
