extends SceneTree
## Developer preview: godot --path . --script tests/pixel_art_preview.gd
## Add -- --capture for a deterministic PNG and automatic exit.
const Visual = preload("res://scripts/visuals/character_visual.gd")

class Gallery extends Node2D:
	var clock := 0.0
	var stopped := false
	var selected_direction := 1
	var cycle := [&"walk", &"windup", &"attack", &"heavy", &"guard_hit", &"dash", &"gather", &"carry"]
	var selected_action := 0
	func _process(delta: float) -> void:
		if not stopped:
			clock += delta
		queue_redraw()
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_SPACE: stopped = not stopped
				KEY_LEFT: selected_direction = posmod(selected_direction-1,8)
				KEY_RIGHT: selected_direction = posmod(selected_direction+1,8)
				KEY_UP: selected_action = posmod(selected_action-1,cycle.size())
				KEY_DOWN: selected_action = posmod(selected_action+1,cycle.size())
				KEY_ESCAPE: get_tree().quit()
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,800),Color("101e27"))
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(28,38),"CROWNFRONT · CRISP MEDIEVAL PIXEL ANIMATION LAB",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f3d58e"))
		draw_string(font,Vector2(28,65),"Space: pause · Left/Right: facing · Up/Down: action · Esc: close",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("92aeb8"))
		var f: int = int(clock * 9.0) % 6
		for team_id in [1,2]:
			var y: float = 190 if team_id==1 else 330
			draw_string(font,Vector2(28,y-60),"AZURE" if team_id==1 else "EMBER",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("67b6d1") if team_id==1 else Color("ec9560"))
			for dir in range(8):
				var point := Vector2(200+dir*135,y)
				Visual.paint_pose(self,&"player",team_id,&"walk",dir,f,true,f,point,1.8)
				draw_string(font,point+Vector2(-12,40),["E","SE","S","SW","W","NW","N","NE"][dir],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
		var roles := [&"player", &"melee", &"ranged", &"tank", &"worker"]
		for i in range(roles.size()):
			var point := Vector2(160+i*240,525)
			var pose: StringName = cycle[selected_action]
			if roles[i]==&"worker" and pose in [&"attack", &"windup", &"heavy", &"guard_hit"]:
				pose = &"gather"
			Visual.paint_pose(self,roles[i],1,pose,selected_direction,f,pose in [&"walk", &"carry", &"dash"],f,point,2.4)
			draw_string(font,point+Vector2(-60,55),String(roles[i])+" / "+String(pose),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		var poses := [&"windup", &"attack", &"heavy", &"guard_hit", &"gather", &"carry", &"flee", &"deposit"]
		for i in range(poses.size()):
			var point := Vector2(85+i*155,715)
			Visual.paint_pose(self,&"player" if i<4 else &"worker",1,poses[i],1,f,i in [5,6],f,point,1.8)
			draw_string(font,point+Vector2(-44,38),String(poses[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f3d58e"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var gallery := Gallery.new()
	gallery.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var surface := SubViewport.new()
	surface.size = Vector2i(1280,800)
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if "--capture" not in OS.get_cmdline_user_args():
		root.add_child(gallery)
	else:
		root.add_child(surface)
		surface.add_child(gallery)
	if "--capture" in OS.get_cmdline_user_args():
		gallery.stopped = true
		gallery.clock = 0.3
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var error := surface.get_texture().get_image().save_png("res:/"+"/tests/artifacts/pixel_art_preview.png")
		print("PIXEL ART PREVIEW capture error=",error)
		quit(0 if error==OK else 1)
	else:
		surface.free()
