extends Node2D
const Visual = preload("res://scripts/visuals/character_visual.gd")
var game
var born_tick: int = 0
var tint: Color = Color.WHITE
var age: float = 0.0
var duration: float = 0.45
var effect: String = "spawn"

func _ready() -> void:
	game = get_parent()
	born_tick = game.session.ticks
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if effect == "crownfall":
		duration = 1.2
		process_mode = Node.PROCESS_MODE_ALWAYS
	elif effect == "upgrade":
		duration = 0.7
	elif effect == "build":
		duration = 0.65
	elif effect == "impact":
		duration = 0.28
	elif effect == "deposit":
		duration = 0.6

func _process(delta: float) -> void:
	# Action effects sample the session clock. Preserve the existing victory
	# crown burst on its always-processing result-screen clock.
	var next_age: float = age + delta if effect == "crownfall" else (game.session.ticks - born_tick) * MatchSession.STEP
	if next_age >= duration:
		queue_free()
	elif next_age != age:
		age = next_age
		queue_redraw()

func _draw() -> void:
	var t: float = clampf(age / duration, 0, 1)
	var color := Color(tint, 1.0 - t)
	if effect == "rally":
		draw_arc(Vector2.ZERO, 300.0 * t, 0.0, TAU, 48, color, 3.0, true)
		return
	if effect in ["deposit", "impact", "death", "spawn"]:
		var pixel_effect: StringName = &"block" if effect == "impact" else StringName(effect)
		Visual.paint_effect(self,pixel_effect,0,clampi(int(t*Visual.FRAMES),0,Visual.FRAMES-1),Vector2(0,-10))
		return
	if effect == "rubble":
		for i in range(6):
			var p := Vector2.from_angle(i * TAU / 6) * (12 + t * 30)
			draw_rect(Rect2(p,Vector2(5,7)*(1-t)),Color("a5b0a0") * Color(1,1,1,1-t))
		return
	draw_arc(Vector2.ZERO, 12 + t * 32, 0, TAU, 24, color, 2, true)
	if effect == "build":
		draw_rect(Rect2(-28,-76*t,56,76*t), Color(tint,0.2*(1-t)),false,3)
	if effect == "crownfall":
		draw_arc(Vector2.ZERO, 35+t*145, 0, TAU, 48, Color(1,0.83,0.4,1-t), 5*(1-t), true)
		for i in range(7):
			var p := Vector2.from_angle(i*TAU/7) * (10+t*65)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-12),p+Vector2(6,-7),p+Vector2(3,5)]),Color(1,0.8,0.4,1-t))
	if effect == "upgrade":
		for i in range(3):
			draw_arc(Vector2(0,-t*50+i*12),25,0,PI,16,color,2,true)
