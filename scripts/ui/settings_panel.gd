extends Control
## Modal in the existing canvas, so layout, screenshots and Cyrillic share the HUD theme.
signal closed
var language_selector: OptionButton
var feedback: Label

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
	panel.custom_minimum_size = Vector2(520, 290)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	var label := Label.new()
	label.text = "LANGUAGE"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	language_selector = OptionButton.new()
	language_selector.custom_minimum_size = Vector2(240, 48)
	language_selector.add_item(tr("LANGUAGE_EN"))
	language_selector.add_item(tr("LANGUAGE_RU"))
	language_selector.select(Localization.LANGUAGES.find(Localization.language))
	language_selector.item_selected.connect(_language_selected)
	row.add_child(language_selector)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 40
	column.add_child(feedback)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size.y = 52
	back.pressed.connect(func(): closed.emit())
	column.add_child(back)

func _language_selected(index: int) -> void:
	var error: Error = Localization.set_language(Localization.LANGUAGES[index])
	feedback.text = "LANGUAGE_SAVED" if error == OK else "LANGUAGE_SAVE_FAILED"
