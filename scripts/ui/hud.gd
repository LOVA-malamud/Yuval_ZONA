extends CanvasLayer
## UI stays active during pause/end screens; all transactions go through the game.

const MINIMAP_SCRIPT = preload("res://scripts/ui/minimap.gd")
const TOUCH_STICK_SCRIPT = preload("res://scripts/ui/touch_stick.gd")

var game = null
var team: GameTeam
var resources_label: Label
var king_label: Label
var enemy_king_label: Label
var status_label: Label
var feedback_label: Label
var tabs: TabContainer
var result_overlay: CenterContainer
var result_title: Label
var result_details: Label
var resume_button: Button
var army_buttons: Dictionary = {}
var upgrade_buttons: Dictionary = {}
var refresh_time: float = 0.0
var notice_time: float = 0.0
var controls: Control
var route_selector: OptionButton
var structure_panel: PanelContainer
var structure_label: Label
var structure_button: Button
var active_pad = null
var resource_hint: Label
var resource_flash: float = 0.0
var previous_wallet := Vector2i.ZERO
var resource_tween: Tween
var king_bars: Array[ProgressBar] = []
var result_shade: ColorRect
var settings_panel: Control
var settings_button: Button
var notice_key: String = ""
var notice_arguments: Array = []
var last_resource_gain := Vector2i.ZERO
var help_panel: Control
var guidance_panel: PanelContainer
var guidance_text: Label
var shop_state: Array = []
var notice_priority: int = 0
var mobile_interact_button: Button
var command_panel: PanelContainer
var rally_button: Button
var regroup_button: Button
var difficulty_selector: OptionButton
var touch_stick: Control
var purchase_feedback: Dictionary = {}
const ROLE_KEYS := {&"worker": "ROLE_WORKER", &"melee": "ROLE_MELEE", &"ranged": "ROLE_RANGED", &"tank": "ROLE_TANK"}


func setup(manager, owner_team: GameTeam) -> void:
	game = manager
	team = owner_team
	_build_interface()
	Localization.language_changed.connect(_language_changed)
	_language_changed()
	previous_wallet = Vector2i(team.money, team.wood)
	team.resources_changed.connect(_resources_changed)
	GameSettings.settings_changed.connect(_update_guidance)
	game.session.match_event.connect(_match_event)
	game.session.command_completed.connect(_command_completed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_refresh()


func _label(text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 62
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	AudioFeedback.bind_button(button)
	return button


func _style(fill: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _build_interface() -> void:
	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Color("e5e9df"))
	theme.set_stylebox("panel", "PanelContainer", _style(Color("172b32"), Color("42595c")))
	theme.set_stylebox("normal", "Button", _style(Color("263e45"), Color("4c6568"), 7))
	theme.set_stylebox("hover", "Button", _style(Color("36565d"), Color("d9bc7e"), 7))
	theme.set_stylebox("pressed", "Button", _style(Color("426570"), Color("e5d8ab"), 7))
	theme.set_stylebox("disabled", "Button", _style(Color("1e3036"), Color("34484b"), 7))
	theme.set_color("font_disabled_color", "Button", Color("839496"))
	theme.set_stylebox("panel", "TabContainer", _style(Color("172b32"), Color("172b32")))
	theme.set_stylebox("tab_selected", "TabContainer", _style(Color("304e56"), Color("52747d"), 5))
	theme.set_stylebox("tab_unselected", "TabContainer", _style(Color("1e343c"), Color("1e343c"), 5))
	controls.theme = theme

	var top := PanelContainer.new()
	controls.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.offset_bottom = 82
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 28)
	top.add_child(bar)
	var brand := _label("HUD_BRAND", 17)
	brand.add_theme_color_override("font_color", Color("edce8e"))
	bar.add_child(brand)
	var wallet := VBoxContainer.new()
	bar.add_child(wallet)
	resources_label = _label("", 23)
	wallet.add_child(resources_label)
	resource_hint = _label("HUD_RESOURCES", 11)
	resource_hint.add_theme_color_override("font_color", Color("b2c0b8"))
	wallet.add_child(resource_hint)
	var kings := VBoxContainer.new()
	kings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(kings)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 16)
	kings.add_child(bars)
	for owner_team in game.teams:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bars.add_child(column)
		var title := _label("",14)
		column.add_child(title)
		if owner_team == team:
			king_label = title
		else:
			enemy_king_label = title
		var meter := ProgressBar.new()
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.custom_minimum_size.y = 7
		meter.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = owner_team.color
		var background := StyleBoxFlat.new()
		background.bg_color = Color("101f27")
		meter.add_theme_stylebox_override("fill",fill)
		meter.add_theme_stylebox_override("background",background)
		column.add_child(meter)
		king_bars.append(meter)
	bar.add_child(_button("PAUSE_BUTTON", _toggle_pause))
	var status_panel := PanelContainer.new()
	controls.add_child(status_panel)
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	status_panel.position = Vector2(16, 102)
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label = _label("", 14)
	status_panel.add_child(status_label)

	var dock := PanelContainer.new()
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	controls.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 16
	dock.offset_right = -16
	dock.offset_top = -222
	dock.offset_bottom = -14
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	dock.add_child(row)
	var shop := VBoxContainer.new()
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(shop)
	var orders := HBoxContainer.new()
	shop.add_child(orders)
	var heading := _label("REINFORCEMENTS", 13)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orders.add_child(heading)
	route_selector = OptionButton.new()
	for title in RouteMap.LANE_NAMES:
		route_selector.add_item(tr(title))
	route_selector.select(game.selected_route)
	route_selector.item_selected.connect(_route_selected)
	route_selector.tooltip_text = "ROUTE_TOOLTIP"
	route_selector.custom_minimum_size.y = 48
	orders.add_child(route_selector)
	var command_button := _button("COMMAND_BUTTON", _toggle_commands)
	command_button.custom_minimum_size.y = 48
	orders.add_child(command_button)
	rally_button = _button("RALLY_BUTTON", func(): game.session.submit(MatchCommand.new(MatchCommand.Action.RALLY, game.player.commander_id)))
	rally_button.custom_minimum_size.y = 48
	orders.add_child(rally_button)
	regroup_button = _button("REGROUP_BUTTON", func(): game.session.submit(MatchCommand.new(MatchCommand.Action.REGROUP, game.player.commander_id)))
	regroup_button.custom_minimum_size.y = 48
	orders.add_child(regroup_button)
	rally_button.tooltip_text = "RALLY_TOOLTIP"
	regroup_button.tooltip_text = "REGROUP_TOOLTIP"
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	shop.add_child(tabs)
	for title in ["Army", "King", "Economy"]:
		var page := HBoxContainer.new()
		page.name = title
		page.add_theme_constant_override("separation", 8)
		tabs.add_child(page)
	var recruit_ids: Array[StringName] = [&"worker"]
	for id in game.unit_data:
		recruit_ids.append(id)
	for id in recruit_ids:
		var button: Button = _button("", _buy.bind(id))
		button.custom_minimum_size = Vector2(160, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tabs.get_child(0).add_child(button)
		var icon = preload("res://scripts/ui/unit_icon.gd").new()
		icon.kind = &"worker" if id == &"worker" else game.unit_data[id].tactical_role
		icon.position = Vector2(4, 6)
		icon.size = Vector2(43, 60)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		army_buttons[id] = button
	for definition in game.upgrades:
		var page = tabs.get_child(1 if definition.category == "king" else 2)
		var button: Button = _button("", _upgrade.bind(definition.id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(155, 78)
		button.add_theme_font_size_override("font_size", 13)
		page.add_child(button)
		upgrade_buttons[definition.id] = button
	var map_column := VBoxContainer.new()
	row.add_child(map_column)
	map_column.add_child(_label("MINIMAP_LEGEND", 12))
	var overview = MINIMAP_SCRIPT.new()
	overview.game = game
	overview.custom_minimum_size = Vector2(256, 136)
	map_column.add_child(overview)
	var bottom := VBoxContainer.new()
	controls.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -269
	bottom.offset_bottom = -229
	feedback_label = _label("", 14)
	bottom.add_child(feedback_label)
	_build_structure_panel()
	_build_guidance()
	command_panel = preload("res://scripts/ui/command_panel.gd").new()
	controls.add_child(command_panel)
	command_panel.setup(game)
	_build_mobile_controls()
	_build_overlay()

func _build_mobile_controls() -> void:
	if not DisplayServer.is_touchscreen_available() and not game.force_touch_controls:
		return
	touch_stick = TOUCH_STICK_SCRIPT.new()
	touch_stick.controller = game.player.controller
	controls.add_child(touch_stick)
	mobile_interact_button = _button("MOBILE_INTERACT", func():
		if game.player.alive and not get_tree().paused and not game.match_finished:
			game.player.interact()
	)
	controls.add_child(mobile_interact_button)
	mobile_interact_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	mobile_interact_button.offset_left = -154
	mobile_interact_button.offset_right = -22
	mobile_interact_button.offset_top = -33
	mobile_interact_button.offset_bottom = 33

func _build_structure_panel() -> void:
	structure_panel = PanelContainer.new()
	controls.add_child(structure_panel)
	structure_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	structure_panel.offset_left = 24
	structure_panel.offset_right = 292
	structure_panel.offset_top = -100
	structure_panel.offset_bottom = 62
	var column := VBoxContainer.new()
	structure_panel.add_child(column)
	structure_label = _label("", 15)
	column.add_child(structure_label)
	structure_button = _button("", _build_or_upgrade)
	structure_button.custom_minimum_size.y = 38
	column.add_child(structure_button)
	structure_panel.hide()

func _refresh_structure() -> void:
	active_pad = game.nearest_pad(game.player) if game.player.alive else null
	structure_panel.visible = active_pad != null and not game.match_finished
	if active_pad == null:
		return
	var blocked: bool = game.match_finished or get_tree().paused
	if active_pad.occupied():
		var tower = active_pad.tower
		var owned: bool = tower.team == team
		var cost: Vector2i = tower.upgrade_cost()
		structure_label.text = tr("TOWER_STATS") % [tr(active_pad.pad_name), tr(tower.team.display_name), tower.level, tower.health, tower.max_health, tower.damage, tower.attack_range, tower.attack_cooldown]
		structure_button.text = tr("TOWER_UPGRADE") % [cost.x, cost.y] if tower.level < 3 else tr("MAX_LEVEL")
		structure_button.disabled = blocked or not owned or tower.level >= 3 or not team.can_afford(cost.x, cost.y)
	else:
		structure_label.text = tr("TOWER_BUILD_INFO") % [tr(active_pad.pad_name), game.balance.tower_money, game.balance.tower_wood]
		structure_button.text = tr("BUILD") if active_pad.rebuild_remaining <= 0 else tr("REBUILD_TIMER") % ceili(active_pad.rebuild_remaining)
		structure_button.disabled = blocked or active_pad.rebuild_remaining > 0 or (active_pad.home_team_id != 0 and active_pad.home_team_id != team.team_id) or not team.can_afford(game.balance.tower_money, game.balance.tower_wood)

func _build_or_upgrade() -> void:
	if active_pad == null:
		return
	_queue_purchase(MatchCommand.Action.UPGRADE_TOWER if active_pad.occupied() else MatchCommand.Action.BUILD, {"pad": active_pad}, structure_button)


func _build_overlay() -> void:
	result_overlay = CenterContainer.new()
	controls.add_child(result_overlay)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.88)
	result_shade = shade
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	# Sibling prevents CenterContainer from shrinking the backdrop.
	controls.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.move_child(shade, result_overlay.get_index())
	shade.hide()
	result_overlay.visibility_changed.connect(func(): shade.visible = result_overlay.visible)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	result_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	result_title = _label("", 38)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_title)
	result_details = _label("")
	result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size = Vector2(760, 140)
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.add_child(result_details)
	column.add_child(details_scroll)
	resume_button = _button("RESUME", _toggle_pause)
	column.add_child(resume_button)
	column.add_child(_button("RESTART", _restart))
	settings_button = _button("SETTINGS", _open_settings)
	column.add_child(settings_button)
	column.add_child(_button("HELP_BUTTON", _open_help))
	column.add_child(_button("TUTORIAL_BUTTON", _start_tutorial))
	column.add_child(_button("MATCH_BUTTON", _start_standard_match))
	difficulty_selector = OptionButton.new()
	difficulty_selector.custom_minimum_size.y = 48
	for key in ["DIFFICULTY_EASY", "DIFFICULTY_STANDARD", "DIFFICULTY_HARD"]:
		difficulty_selector.add_item(tr(key))
	difficulty_selector.select([&"easy", &"standard", &"hard"].find(GameSettings.difficulty))
	difficulty_selector.item_selected.connect(func(index): GameSettings.set_difficulty([&"easy", &"standard", &"hard"][index]))
	difficulty_selector.tooltip_text = "DIFFICULTY_TOOLTIP"
	column.add_child(difficulty_selector)
	for child in column.get_children():
		if child is Button:
			child.custom_minimum_size.y = 44
	result_overlay.hide()


func _process(delta: float) -> void:
	if game == null:
		return
	if is_instance_valid(mobile_interact_button):
		mobile_interact_button.visible = game.player.alive and not get_tree().paused and not game.match_finished
		touch_stick.visible = mobile_interact_button.visible
	refresh_time -= delta
	notice_time -= delta
	resource_flash = maxf(0.0, resource_flash - delta)
	if resource_flash <= 0:
		resource_hint.text = "HUD_RESOURCES"
	if notice_time <= 0.0:
		feedback_label.text = ""
		notice_priority = 0
	if refresh_time <= 0.0:
		refresh_time = 0.1
		_refresh()
		_update_guidance()


func _unhandled_input(event: InputEvent) -> void:
	if game != null and not get_tree().paused and not game.match_finished:
		for index in range(3):
			if event.is_action_pressed(["route_north", "route_center", "route_south"][index]):
				route_selector.select(index)
				_route_selected(index)
				get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause_match") and not event.is_echo() and game != null:
		if is_instance_valid(help_panel):
			_close_help()
		elif is_instance_valid(settings_panel):
			_close_settings()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_refresh_structure()
	if command_panel != null:
		command_panel.refresh()
	rally_button.text = tr("RALLY_BUTTON") if game.player.rally_cooldown <= 0.0 else tr("RALLY_COOLDOWN") % ceili(game.player.rally_cooldown)
	rally_button.disabled = not game.player.alive or game.player.rally_cooldown > 0.0 or game.match_finished or get_tree().paused
	regroup_button.disabled = not game.player.alive or game.match_finished or get_tree().paused
	resources_label.text = "◈ %s   ♣ %s" % [_wallet_number(team.money), _wallet_number(team.wood)]
	resources_label.tooltip_text = tr("WALLET_TOOLTIP") % game.balance.ally_money_reserve
	var king_hp: float = team.king.health if is_instance_valid(team.king) else 0.0
	var opponent: GameTeam = game.teams[1]
	var enemy_hp: float = opponent.king.health if is_instance_valid(opponent.king) else 0.0
	king_label.text = tr("AZURE_KING_HP") % [king_hp,team.get_stat(&"king_health")]
	enemy_king_label.text = tr("EMBER_KING_HP") % [enemy_hp,opponent.get_stat(&"king_health")]
	king_label.tooltip_text = tr("ECONOMY_TOOLTIP") % [team.worker_count,team.combat_count,team.get_stat(&"income")]
	for index in range(2):
		var king = game.teams[index].king
		king_bars[index].max_value = game.teams[index].get_stat(&"king_health")
		king_bars[index].value = king.health if is_instance_valid(king) else 0
		king_bars[index].modulate = Color.WHITE
		if is_instance_valid(king) and king.danger_remaining > 0:
			king_bars[index].modulate = Color(1.5, 1.5, 1.5, 0.7 + absf(sin(game.match_seconds*5))*0.3)
	var hero_text: String = tr("HERO_HP") % [game.player.health, game.player.max_health]
	if not game.player.alive:
		hero_text = tr("RESPAWN_TIMER") % ceili(game.player.respawn_remaining)
	var ally = game.commanders[1]
	status_label.text = tr("ALLY_STATUS") % [int(game.match_seconds) / 60, int(game.match_seconds) % 60, hero_text, tr(ally.tactical_status)]
	if is_instance_valid(team.king) and team.king.danger_remaining > 0:
		status_label.text += tr("KING_WARNING")
	var rallying := 0
	for unit in game.entities.get_children():
		if unit is CombatEntity and unit.category == &"army" and unit.team == team and unit.rally_remaining > 0.0:
			rallying += 1
	status_label.text += "\n" + tr("RALLYING_COUNT") % rallying
	route_selector.tooltip_text = tr("RECRUIT_LOCATION") % tr(RouteMap.LANE_NAMES[game.selected_route])
	var next_shop_state: Array = [team.money, team.wood, team.worker_count, team.combat_count, hash(team.upgrade_levels), game.selected_route, game.match_finished, get_tree().paused, Localization.language]
	if next_shop_state != shop_state:
		shop_state = next_shop_state
		_refresh_shop()


func _refresh_shop() -> void:
	for id in army_buttons:
		var availability: Dictionary = game.recruit_availability(team, id, game.selected_route)
		var cost: int = availability.gold
		var button: Button = army_buttons[id]
		var description: String = ROLE_KEYS.get(id, ROLE_KEYS.get(game.unit_data[id].tactical_role, "ROLE_MELEE")) if id != &"worker" else "ROLE_WORKER"
		button.text = tr("SHOP_CARD") % [tr("UNIT_WORKER" if id == &"worker" else game.unit_data[id].display_name), cost, tr(description)]
		var capped: bool = (
			team.worker_count >= game.rules.worker_cap
			if id == &"worker"
			else team.combat_count >= game.rules.army_cap
		)
		button.disabled = not availability.allowed
		button.tooltip_text = "LIMIT_REACHED" if capped else (tr("NEED_GOLD") % maxi(0,cost-team.money) if team.money < cost else tr("ROUTE_RECRUIT") % tr(RouteMap.LANE_NAMES[game.selected_route]))
		if id == &"worker" and not capped and team.money >= cost:
			button.tooltip_text = tr("WORKER_RECRUIT_TOOLTIP")
	for definition in game.upgrades:
		var level: int = team.upgrade_level(definition.id)
		var button: Button = upgrade_buttons[definition.id]
		var maxed: bool = level >= definition.maximum_level
		var cost_text: String = tr("MAX_LEVEL") if maxed else tr("WOOD_COST") % definition.cost(level)
		button.text = (
			tr("UPGRADE_CARD")
			% [
				tr(definition.display_name),
				level,
				team.get_stat(definition.stat),
				tr(definition.unit),
				team.get_stat(definition.stat) + (0 if maxed else definition.amount),
				cost_text,
			]
		)
		button.disabled = not game.upgrade_availability(team, definition.id).allowed


func _buy(id: StringName) -> void:
	_queue_purchase(MatchCommand.Action.RECRUIT, {"id": id, "route": game.selected_route, "feedback": true}, army_buttons[id])


func _upgrade(id: StringName) -> void:
	_queue_purchase(MatchCommand.Action.UPGRADE, {"id": id, "feedback": true}, upgrade_buttons[id])

func _queue_purchase(action: MatchCommand.Action, payload: Dictionary, button: Button) -> void:
	if game.session.state != MatchSession.State.RUNNING or get_tree().paused:
		return
	var receipt: int = game.session.submit(MatchCommand.new(action, game.player.commander_id, payload))
	purchase_feedback[receipt] = button

func _command_completed(receipt: int, result: CommandResult) -> void:
	if not purchase_feedback.has(receipt):
		return
	var button = purchase_feedback[receipt]
	purchase_feedback.erase(receipt)
	if result.success and is_instance_valid(button):
		_flash_button(button)
	elif result.reason != &"cancelled":
		AudioFeedback.play(&"failed")
		notify("BUILD_UNAVAILABLE")
	_refresh()


func show_king_tab() -> void:
	tabs.current_tab = 1


func notify(key: String, arguments: Array = []) -> void:
	var priority: int = 3 if key == "KING_DANGER" else (2 if key == "COMMANDER_DOWN" else 0)
	if notice_time > 0 and priority < notice_priority:
		return
	notice_priority = priority
	notice_key = key
	notice_arguments = arguments
	if feedback_label != null:
		feedback_label.text = Localization.format_message(key, arguments)
		feedback_label.add_theme_color_override("font_color", Color("ffcf91") if priority > 0 else Color("e5e9df"))
		notice_time = 6.0 if priority > 0 else 4.0


func show_result(winner: int) -> void:
	if game.player.controller.has_method("reset_touch"):
		game.player.controller.reset_touch()
	_refresh_result(winner)
	resume_button.hide()
	result_overlay.show()
	result_title.add_theme_color_override("font_color",Color("edce8e") if winner == team.team_id else Color("ef9c85"))
	result_overlay.modulate.a = 0.0
	result_shade.modulate.a = 0.0
	var transition := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition.tween_interval(0.45)
	transition.tween_property(result_shade,"modulate:a",1.0,0.5)
	transition.parallel().tween_property(result_overlay,"modulate:a",1.0,0.5)
	_refresh()


func _toggle_pause() -> void:
	if game.match_finished:
		return
	if game.player.controller.has_method("reset_touch"):
		game.player.controller.reset_touch()
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		game.session.pause()
	else:
		game.session.resume()
	result_title.text = "PAUSED"
	result_details.text = "PAUSE_INSTRUCTIONS"
	resume_button.show()
	result_overlay.visible = get_tree().paused


func _restart() -> void:
	AudioFeedback.stop_all()
	get_tree().paused = false
	get_tree().reload_current_scene()


func focus_build_pad() -> void:
	_refresh_structure()


func _resources_changed() -> void:
	var current := Vector2i(team.money,team.wood)
	var change: Vector2i = current - previous_wallet
	previous_wallet = current
	if resource_tween != null:
		resource_tween.kill()
	resources_label.modulate = Color("92dcd0") if change.x < 0 or change.y < 0 else Color("f0d497")
	resource_tween = create_tween()
	resource_tween.tween_property(resources_label,"modulate",Color.WHITE,0.45)
	if change.y > 0:
		last_resource_gain = change
		resource_hint.text = tr("RESOURCE_GAIN") % [change.x,change.y]
		resource_flash = 1.3

func _flash_button(button: Button) -> void:
	button.modulate = Color("8edbd0")
	create_tween().tween_property(button,"modulate",Color.WHITE,0.25)

func _route_selected(index: int) -> void:
	game.select_route(index)
	AudioFeedback.play(&"route")
	notify("ROUTE_NOTICE", [RouteMap.LANE_NAMES[index]])

func _wallet_number(value: int) -> String:
	return "%.1fK" % (value/1000.0) if value >= 10000 else str(value)


func _refresh_result(winner: int) -> void:
	result_title.text = "VICTORY" if winner == team.team_id else "DEFEAT"
	result_details.text = tr("VICTORY_DETAIL" if winner == team.team_id else "DEFEAT_DETAIL")
	if game.tutorial != null:
		result_details.text = tr("TUTORIAL_COMPLETE")
	result_details.text += tr("RESULT_TIME") % [int(game.match_seconds)/60,int(game.match_seconds)%60]
	if game.coordination != null:
		for commander in game.commanders:
			var stats: Dictionary = game.coordination.commander_stats[commander.commander_id]
			result_details.text += "\n" + tr("RECAP_COMMANDER") % [tr(commander.commander_name), stats.gold, stats.wood, stats.recruits, stats.king_damage, stats.rallies]
		var stats: Dictionary = game.coordination.team_stats[team.team_id]
		result_details.text += "\n" + tr("RECAP_TEAM") % [stats.workers_lost, stats.deposited, stats.towers_built, stats.towers_destroyed]

func _language_changed() -> void:
	shop_state.clear()
	if is_instance_valid(mobile_interact_button):
		mobile_interact_button.text = tr("MOBILE_INTERACT")
	for index in range(3):
		tabs.set_tab_title(index, tr(["TAB_ARMY", "TAB_KING", "TAB_ECONOMY"][index]))
		route_selector.set_item_text(index, tr(RouteMap.LANE_NAMES[index]))
	if difficulty_selector != null:
		for index in range(3):
			difficulty_selector.set_item_text(index, tr(["DIFFICULTY_EASY", "DIFFICULTY_STANDARD", "DIFFICULTY_HARD"][index]))
	if game.match_finished:
		_refresh_result(game.winning_team_id)
	if notice_time > 0:
		feedback_label.text = Localization.format_message(notice_key, notice_arguments)
	if resource_flash > 0:
		resource_hint.text = tr("RESOURCE_GAIN") % [last_resource_gain.x, last_resource_gain.y]
	_refresh()
	_update_guidance()

func _open_settings() -> void:
	if is_instance_valid(settings_panel):
		return
	settings_panel = preload("res://scripts/ui/settings_panel.gd").new()
	controls.add_child(settings_panel)
	settings_panel.closed.connect(_close_settings)
	_apply_safe_area()

func _close_settings() -> void:
	settings_panel.queue_free()
	settings_panel = null


func _build_guidance() -> void:
	guidance_panel = PanelContainer.new()
	controls.add_child(guidance_panel)
	guidance_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	guidance_panel.offset_left = -404
	guidance_panel.offset_right = -16
	guidance_panel.offset_top = 102
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	guidance_panel.add_child(column)
	var heading := _label("HELP_GUIDANCE", 12)
	heading.add_theme_color_override("font_color", Color("edce8e"))
	column.add_child(heading)
	guidance_text = _label("", 15)
	guidance_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_text.custom_minimum_size = Vector2(350, 58)
	column.add_child(guidance_text)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for entry in [["HELP_BUTTON", _open_help], ["HELP_DISMISS", _dismiss_guidance]]:
		var button := _button("TUTORIAL_SKIP" if game.tutorial_mode and entry[0] == "HELP_DISMISS" else entry[0], entry[1])
		button.custom_minimum_size.y = 30
		button.add_theme_font_size_override("font_size", 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)


func _update_guidance() -> void:
	if not is_instance_valid(guidance_panel):
		return
	guidance_panel.visible = GameSettings.onboarding_enabled and not get_tree().paused and not game.match_finished and game.match_seconds < 100 and not command_panel.visible
	if game.tutorial != null:
		guidance_panel.visible = not get_tree().paused and not game.match_finished and not command_panel.visible
		guidance_text.text = game.tutorial.instruction()
		return
	var key: String = "HELP_TIP_OBJECTIVE"
	if not game.player.alive:
		key = "HELP_TIP_RESPAWN"
	elif active_pad != null:
		key = "HELP_TIP_PADS"
	elif tabs.current_tab > 0:
		key = "HELP_TIP_UPGRADES"
	else:
		var tips := ["HELP_TIP_OBJECTIVE", "HELP_TIP_MOVE", "HELP_TIP_RECRUIT", "HELP_TIP_WORKERS", "HELP_TIP_MAP"]
		key = tips[mini(int(game.match_seconds / 15), tips.size() - 1)]
		if key == "HELP_TIP_MOVE" and DisplayServer.is_touchscreen_available():
			key = "HELP_TIP_MOVE_TOUCH"
	guidance_text.text = tr(key)


func _dismiss_guidance() -> void:
	if game.tutorial != null:
		_start_standard_match()
		return
	if GameSettings.set_onboarding_enabled(false) != OK:
		notify("SETTINGS_SAVE_FAILED")
	_update_guidance()


func _open_help() -> void:
	if is_instance_valid(help_panel):
		return
	if not get_tree().paused and not game.match_finished:
		_toggle_pause()
	help_panel = preload("res://scripts/ui/help_panel.gd").new()
	help_panel.setup(game)
	controls.add_child(help_panel)
	help_panel.closed.connect(_close_help)
	_apply_safe_area()


func _close_help() -> void:
	help_panel.queue_free()
	help_panel = null

func _toggle_commands() -> void:
	command_panel.visible = not command_panel.visible
	_update_guidance()

func _start_tutorial() -> void:
	AudioFeedback.stop_all()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/tutorial.tscn")

func _start_standard_match() -> void:
	AudioFeedback.stop_all()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _match_event(event: Dictionary) -> void:
	if event.type == "alert" and event.team == team.team_id:
		var key := "ALERT_" + str(event.category).to_upper()
		if event.category == "king_danger":
			notify("KING_DANGER")
		elif notice_priority < 3:
			notify(key, [RouteMap.LANE_NAMES[event.lane]])

func _apply_safe_area() -> void:
	var bounds := get_viewport().get_visible_rect()
	var safe := bounds
	if game.safe_area_override.has_area():
		safe = bounds.intersection(game.safe_area_override)
	elif DisplayServer.is_touchscreen_available():
		var physical := Rect2(DisplayServer.get_display_safe_area())
		if physical.has_area():
			safe = bounds.intersection(get_viewport().get_screen_transform().affine_inverse() * physical)
	controls.offset_left = safe.position.x
	controls.offset_top = safe.position.y
	controls.offset_right = safe.end.x - bounds.end.x
	controls.offset_bottom = safe.end.y - bounds.end.y
	if game.force_touch_controls or DisplayServer.is_touchscreen_available():
		_ensure_touch_targets(controls)

func _ensure_touch_targets(node: Node) -> void:
	if node is BaseButton or node is TabBar:
		node.custom_minimum_size.y = maxf(48.0, node.custom_minimum_size.y)
	for child in node.get_children():
		_ensure_touch_targets(child)
