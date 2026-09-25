extends Node2D
var tint: Color = Color.WHITE
var age: float = 0.0
var duration: float = 0.45
var effect: String = "spawn"

func _ready() -> void:
	if effect == "crownfall":
		duration = 1.2
		process_mode = Node.PROCESS_MODE_ALWAYS
	elif effect == "upgrade":
		duration = 0.7

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(age / duration, 0, 1)
	var color := Color(tint, 1.0 - t)
	draw_arc(Vector2.ZERO, 12 + t * 32, 0, TAU, 24, color, 2, true)
	if effect == "crownfall":
		draw_arc(Vector2.ZERO, 35+t*145, 0, TAU, 48, Color(1,0.83,0.4,1-t), 5*(1-t), true)
		for i in range(7):
			var p := Vector2.from_angle(i*TAU/7) * (10+t*65)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-12),p+Vector2(6,-7),p+Vector2(3,5)]),Color(1,0.8,0.4,1-t))
	if effect == "upgrade":
		for i in range(3):
			draw_arc(Vector2(0,-t*50+i*12),25,0,PI,16,color,2,true)
	if effect == "death":
		for i in range(5):
			var p := Vector2.from_angle(i * TAU / 5) * (8 + t*24)
			draw_circle(p, 3*(1-t), color)
