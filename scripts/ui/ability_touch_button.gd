extends Button
## An independent action finger releases inside to activate, outside to cancel.
var ability_id: StringName
var controller
var touch_index: int = -1
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
	if not is_visible_in_tree() or disabled or get_tree().paused:
		reset_action()
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0 and get_global_rect().has_point(event.position):
			touch_index = event.index
			cancelled = false
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_index:
			if not event.canceled and get_global_rect().has_point(event.position) and controller != null:
				controller.request_ability(ability_id)
			reset_action()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		cancelled = not get_global_rect().has_point(event.position)
		queue_redraw()
		get_viewport().set_input_as_handled()

func reset_action() -> void:
	touch_index = -1
	cancelled = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_action()

func _draw() -> void:
	if touch_index >= 0:
		draw_arc(size * 0.5, size.x * 0.45, 0, TAU, 24, Color("ee9b86") if cancelled else Color("f7dc95"), 3.0, true)
