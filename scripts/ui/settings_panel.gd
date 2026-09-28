extends Control
## Modal in the existing canvas. All changes apply immediately, including paused UI.
signal closed
var language_selector: OptionButton
var feedback: Label
var master_slider: HSlider
var sfx_slider: HSlider
var master_value: Label
var sfx_value: Label
var fullscreen_toggle: CheckButton
var onboarding_toggle: CheckButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	var note := Label.new()
	note.text = "SETTINGS_NOTE"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color("b2c0b8"))
	column.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	var label := Label.new()
	label.text = "LANGUAGE"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	language_selector = OptionButton.new()
	language_selector.custom_minimum_size = Vector2(240, 42)
	language_selector.add_item(tr("LANGUAGE_EN"))
	language_selector.add_item(tr("LANGUAGE_RU"))
	language_selector.item_selected.connect(_language_selected)
	row.add_child(language_selector)
	AudioFeedback.bind_button(language_selector)
	var master: Array = _volume_control(column, "AUDIO_MASTER")
	master_slider = master[0]
	master_value = master[1]
	master_slider.value_changed.connect(_master_changed)
	master_slider.drag_ended.connect(_volume_released)
	var sfx: Array = _volume_control(column, "AUDIO_SFX")
	sfx_slider = sfx[0]
	sfx_value = sfx[1]
	sfx_slider.value_changed.connect(_sfx_changed)
	sfx_slider.drag_ended.connect(_volume_released)
	fullscreen_toggle = _toggle(column, "DISPLAY_FULLSCREEN")
	fullscreen_toggle.toggled.connect(func(value: bool): _saved(GameSettings.set_fullscreen(value)))
	onboarding_toggle = _toggle(column, "ONBOARDING_ENABLED")
	onboarding_toggle.toggled.connect(func(value: bool): _saved(GameSettings.set_onboarding_enabled(value)))
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size = Vector2(0, 40)
	feedback.add_theme_font_size_override("font_size", 14)
	column.add_child(feedback)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var reset := Button.new()
	reset.text = "RESET_DEFAULTS"
	reset.custom_minimum_size.y = 48
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func():
		_saved(GameSettings.reset_defaults())
		if GameSettings.last_save_error == OK:
			feedback.text = "SETTINGS_RESET"
	)
	actions.add_child(reset)
	AudioFeedback.bind_button(reset)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(150, 48)
	back.pressed.connect(func(): closed.emit())
	actions.add_child(back)
	AudioFeedback.bind_button(back)
	GameSettings.settings_changed.connect(_refresh)
	Localization.language_changed.connect(_refresh)
	_refresh()


func _volume_control(column: VBoxContainer, key: String) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	column.add_child(box)
	var line := HBoxContainer.new()
	box.add_child(line)
	var label := Label.new()
	label.text = key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var value := Label.new()
	value.custom_minimum_size.x = 48
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size.y = 28
	slider.focus_exited.connect(func(): _saved(GameSettings.save()))
	box.add_child(slider)
	return [slider, value]


func _toggle(column: VBoxContainer, key: String) -> CheckButton:
	var button := CheckButton.new()
	button.text = key
	button.custom_minimum_size.y = 38
	column.add_child(button)
	AudioFeedback.bind_button(button)
	return button


func _refresh() -> void:
	if language_selector == null or master_slider == null:
		return
	language_selector.select(Localization.LANGUAGES.find(Localization.language))
	master_slider.set_value_no_signal(roundi(GameSettings.master_volume * 100))
	sfx_slider.set_value_no_signal(roundi(GameSettings.sfx_volume * 100))
	master_value.text = "%d%%" % roundi(GameSettings.master_volume * 100)
	sfx_value.text = "%d%%" % roundi(GameSettings.sfx_volume * 100)
	fullscreen_toggle.set_pressed_no_signal(GameSettings.fullscreen)
	onboarding_toggle.set_pressed_no_signal(GameSettings.onboarding_enabled)


func _language_selected(index: int) -> void:
	var error: Error = Localization.set_language(Localization.LANGUAGES[index])
	feedback.text = "LANGUAGE_SAVED" if error == OK else "LANGUAGE_SAVE_FAILED"


func _master_changed(value: float) -> void:
	GameSettings.set_master_volume(value / 100.0, false)
	# Keyboard changes do not emit drag_ended; save those immediately.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_saved(GameSettings.save())


func _sfx_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value / 100.0, false)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_saved(GameSettings.save())


func _volume_released(changed: bool) -> void:
	if changed:
		_saved(GameSettings.save())
		AudioFeedback.play(&"ui_click")


func _saved(error: Error) -> void:
	feedback.text = "SETTINGS_SAVED" if error == OK else "SETTINGS_SAVE_FAILED"
