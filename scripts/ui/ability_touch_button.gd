extends Button
## Independent action finger: drag to aim, return to cancel, release to commit.
var ability_id: StringName
var controller
var touch_index: int = -1
var origin := Vector2.ZERO
var aim := Vector2.ZERO
var has_dragged: bool = false
var cancelled: bool = false
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(76, 76)
	pressed.connect(func():
		if touch_index < 0 and controller != null:
			controller.request_ability(ability_id)
	)
func _process(_delta: float) -> void:
	if touch_index >= 0 and (not is_visible_in_tree() or disabled or get_tree().paused):
		reset_action()

func _input(event: InputEvent) -> void:
	if not visible or disabled or get_tree().paused:
		reset_action()
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0 and get_global_rect().has_point(event.position):
			touch_index = event.index
			origin = event.position
			aim = Vector2.ZERO
			has_dragged = false
			cancelled = false
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_index:
			if not cancelled:
				controller.request_ability(ability_id, aim)
			reset_action()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		var offset: Vector2 = event.position - origin
		if offset.length() > 18.0:
			has_dragged = true
			aim = offset.normalized()
			cancelled = false
		elif has_dragged:
			cancelled = true
		queue_redraw()
		get_viewport().set_input_as_handled()
func reset_action() -> void:
	touch_index = -1
	aim = Vector2.ZERO
	has_dragged = false
	cancelled = false
	queue_redraw()
func _draw() -> void:
	if touch_index >= 0:
		var center: Vector2 = size * 0.5
		draw_arc(center, size.x * 0.45, 0, TAU, 24, Color("ee9b86") if cancelled else Color("f7dc95"), 3.0, true)
		if aim != Vector2.ZERO and not cancelled:
			draw_line(center, center + aim * 58.0, Color("f7dc95"), 4.0, true)
