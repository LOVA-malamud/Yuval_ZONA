extends PanelContainer
## Compact orders stay available on keyboard and touchscreen.
var game
var order_selector: OptionButton
var intent: Label
var purchases: Label
var order_keys := ["ORDER_AUTO", "ORDER_NORTH", "ORDER_CENTER", "ORDER_SOUTH", "ORDER_DEFEND", "ORDER_ESCORT"]

func setup(owner_game) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -436
	offset_right = -16
	offset_top = 102
	var column := VBoxContainer.new()
	if game.force_touch_controls or DisplayServer.is_touchscreen_available():
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(332, 320)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(column)
	else:
		add_child(column)
	var title := Label.new()
	title.text = "COMMAND_TITLE"
	column.add_child(title)
	order_selector = OptionButton.new()
	order_selector.custom_minimum_size.y = 48
	for key in order_keys:
		order_selector.add_item(tr(key))
	order_selector.item_selected.connect(func(index):
		game.session.submit(MatchCommand.new(MatchCommand.Action.ALLY_ORDER, game.player.commander_id, {"order": CoordinationService.ORDERS[index]}))
	)
	column.add_child(order_selector)
	intent = Label.new()
	intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent.custom_minimum_size.x = 312 if game.force_touch_controls or DisplayServer.is_touchscreen_available() else 360
	column.add_child(intent)
	purchases = Label.new()
	purchases.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(purchases)
	var close := Button.new()
	close.text = "COMMAND_CLOSE"
	close.custom_minimum_size.y = 48
	close.pressed.connect(hide)
	column.add_child(close)
	Localization.language_changed.connect(refresh)
	hide()

func refresh() -> void:
	for index in range(order_keys.size()):
		order_selector.set_item_text(index, tr(order_keys[index]))
	var ally = game.commanders[1]
	order_selector.select(CoordinationService.ORDERS.find(ally.controller.order))
	order_selector.disabled = game.match_finished or game.get_tree().paused
	var bot = ally.controller
	var plan: String = tr("PLAN_NONE")
	if bot.build_goal != null:
		plan = tr("PLAN_TOWER")
	elif bot.planned_purchase != &"":
		plan = _unit_name(bot.planned_purchase)
	intent.text = tr("ALLY_INTENT") % [tr(ally.tactical_status), plan, bot.reserved_gold, bot.reserved_wood]
	purchases.text = tr("RECENT_PURCHASES")
	var shown := 0
	for entry in game.coordination.purchases:
		if entry.team == game.player.team.team_id and shown < 3:
			var commander = game.commander_by_id(entry.commander_id)
			var name: String = _unit_name(StringName(entry.id)) if entry.type == "recruit" else tr("PURCHASE_" + entry.type.to_upper())
			purchases.text += "\n" + tr("PURCHASE_ENTRY") % [tr(commander.commander_name), name, entry.gold, entry.wood]
			shown += 1

func _unit_name(id: StringName) -> String:
	return tr("UNIT_WORKER" if id == &"worker" else game.unit_data[id].display_name)
