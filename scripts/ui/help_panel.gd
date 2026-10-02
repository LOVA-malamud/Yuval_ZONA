extends Control
## Optional reference guide. Opening and closing it is owned by the HUD's pause flow.
## This panel never changes match state and never advances gameplay itself.
signal closed

const TOPICS := ["CONTROLS", "ARMY", "RESOURCES", "TOWERS", "UPGRADES", "MAP", "COORDINATION"]

var game = null
var topic_index: int = 0
var topic_title: Label
var topic_body: Label
var topic_action: Label
var page_label: Label
var previous_button: Button
var next_button: Button
var guidance_toggle: CheckButton
var feedback: Label


func setup(manager) -> void:
	game = manager


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 680
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var heading := _label("HELP_TITLE", 28)
	column.add_child(heading)
	var objective := _label("HELP_OBJECTIVE", 16)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_color_override("font_color", Color("edce8e"))
	column.add_child(objective)
	column.add_child(HSeparator.new())
	topic_title = _label("", 21)
	column.add_child(topic_title)
	topic_body = _label("", 16)
	topic_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	topic_body.custom_minimum_size.y = 156
	topic_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(topic_body)
	topic_action = _label("", 15)
	topic_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	topic_action.custom_minimum_size.y = 42
	topic_action.add_theme_color_override("font_color", Color("add9cf"))
	column.add_child(topic_action)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 16)
	column.add_child(navigation)
	previous_button = _button("HELP_PREVIOUS", func(): select_topic(topic_index - 1))
	previous_button.custom_minimum_size.x = 170
	navigation.add_child(previous_button)
	page_label = _label("", 15)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(page_label)
	next_button = _button("HELP_NEXT", func(): select_topic(topic_index + 1))
	next_button.custom_minimum_size.x = 170
	navigation.add_child(next_button)
	guidance_toggle = CheckButton.new()
	guidance_toggle.text = "ONBOARDING_ENABLED"
	guidance_toggle.custom_minimum_size.y = 32
	guidance_toggle.toggled.connect(_guidance_toggled)
	AudioFeedback.bind_button(guidance_toggle)
	column.add_child(guidance_toggle)
	feedback = _label("", 13)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.hide()
	column.add_child(feedback)
	column.add_child(_button("HELP_CLOSE", func(): closed.emit()))
	Localization.language_changed.connect(_refresh)
	GameSettings.settings_changed.connect(_settings_changed)
	_settings_changed()
	_refresh()


func _label(key: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = key
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	AudioFeedback.bind_button(button)
	return button


func select_topic(index: int) -> void:
	topic_index = clampi(index, 0, TOPICS.size() - 1)
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	var topic: String = TOPICS[topic_index]
	topic_title.text = tr("HELP_" + topic + "_TITLE")
	if topic == "CONTROLS" and DisplayServer.is_touchscreen_available():
		topic_body.text = tr("HELP_CONTROLS_BODY_TOUCH")
		topic_action.text = tr("HELP_CONTROLS_ACTION_TOUCH")
	else:
		topic_body.text = tr("HELP_" + topic + "_BODY")
		topic_action.text = tr("HELP_" + topic + "_ACTION")
	page_label.text = tr("HELP_PAGE") % [topic_index + 1, TOPICS.size()]
	previous_button.disabled = topic_index == 0
	next_button.disabled = topic_index == TOPICS.size() - 1


func _settings_changed() -> void:
	guidance_toggle.set_pressed_no_signal(GameSettings.onboarding_enabled)


func _guidance_toggled(enabled: bool) -> void:
	var error: Error = GameSettings.set_onboarding_enabled(enabled)
	feedback.text = "SETTINGS_SAVED" if error == OK else "SETTINGS_SAVE_FAILED"
	feedback.show()
