extends Node2D
## Presentation-only drifting cloud shadows. Uses wall-clock time and never
## touches simulation state or the simulation RNG.
const CLOUDS: int = 7
var bounds: Vector2 = Vector2(2000, 1200)
var shapes: Array[Vector3] = []
var drift: float = 0.0

func _ready() -> void:
	z_index = 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(CLOUDS):
		shapes.append(Vector3(rng.randf_range(0.0, bounds.x), rng.randf_range(0.0, bounds.y), rng.randf_range(160.0, 320.0)))

func _process(delta: float) -> void:
	drift += delta * 14.0
	queue_redraw()

func _draw() -> void:
	for shape in shapes:
		var center := Vector2(fposmod(shape.x + drift, bounds.x + 600.0) - 300.0, shape.y)
		for part in range(3):
			var offset := Vector2(part * shape.z * 0.5 - shape.z * 0.5, (part % 2) * 30.0)
			draw_circle(center + offset, shape.z * 0.5, Color(0.02, 0.05, 0.06, 0.05))
