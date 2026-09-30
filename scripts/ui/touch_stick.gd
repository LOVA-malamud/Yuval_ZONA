extends Control
## A lightweight guide for the left-side movement area; input stays in the controller.

var controller

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	if controller != null and visible:
		queue_redraw()

func _draw() -> void:
	if controller == null:
		return
	var center := Vector2(116.0, size.y * 0.57)
	if controller.touch_index >= 0:
		center = controller.touch_origin
	draw_circle(center, 74.0, Color(0.06, 0.13, 0.17, 0.34))
	draw_arc(center, 72.0, 0.0, TAU, 48, Color(0.89, 0.91, 0.79, 0.57), 3.0, true)
	draw_circle(center + controller.touch_direction * 52.0, 27.0, Color(0.85, 0.89, 0.78, 0.70))
