extends Node
## Input-driven integration scene for MCP. Leaves the normal match running on success.
var game = null
var failures: int = 0
var saved_settings: String = ""
var had_settings: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("LIVE PASS: ",message)
	else:
		failures += 1
		push_error("LIVE FAIL: " + message)

func _run() -> void:
	had_settings = FileAccess.file_exists(Localization.SETTINGS_PATH)
	if had_settings:
		saved_settings = FileAccess.get_file_as_string(Localization.SETTINGS_PATH)
	game = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.4).timeout
	var start: Vector2 = game.player.position
	Input.action_press("move_right")
	await get_tree().create_timer(0.7).timeout
	Input.action_release("move_right")
	check(game.player.position.x > start.x+120,"Human WASD input moves commander")
	game.teams[0].money = 1000
	game.teams[0].wood = 500
	var before: int = game.teams[0].combat_count
	# Feed a real mouse event through the viewport, exercising GUI hit testing.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = game.hud.army_buttons[&"melee"].get_global_rect().get_center()
	click.pressed = true
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().create_timer(0.15).timeout
	check(game.teams[0].combat_count == before+1,"Mouse click purchases a unit through shop")
	game.hud._route_selected(0)
	check(game.selected_route == 0 and game.route_highlight > 0,"Route selector updates new-recruit orders")
	var enemy = game.UNIT_SCENE.instantiate()
	enemy.configure(game.teams[1],game,game.unit_data[&"tank"])
	enemy.position = game.player.position+Vector2(50,0)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.entities.add_child(enemy)
	var enemy_hp: float = enemy.health
	Input.action_press("attack")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("attack")
	check(enemy.health < enemy_hp,"SPACE input attacks enemy")
	enemy.free()
	game.player.position = game.pads[0].position+Vector2(-45,0)
	await get_tree().create_timer(0.2).timeout
	game.hud.structure_button.pressed.emit()
	check(game.pads[0].occupied(),"Context build button constructs tower")
	game.hud.structure_button.pressed.emit()
	check(game.pads[0].tower.level == 2,"Context button upgrades owned tower")
	var old_zoom: float = game.player.get_node("Camera2D").zoom.x
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(700,300)
	Input.parse_input_event(wheel)
	await get_tree().process_frame
	check(game.player.get_node("Camera2D").zoom.x > old_zoom,"Mouse wheel changes camera zoom")
	var escape := InputEventAction.new()
	escape.action = "pause_match"
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	check(get_tree().paused and game.hud.result_overlay.visible,"Escape pauses and opens overlay")
	var money: int = game.teams[0].money
	await get_tree().create_timer(1.2,true).timeout
	check(game.teams[0].money == money,"Paused economy does not advance")
	await click_control(game.hud.settings_button)
	check(is_instance_valid(game.hud.settings_panel), "Mouse opens Settings from pause")
	await get_tree().create_timer(0.2,true).timeout
	var selector: OptionButton = game.hud.settings_panel.language_selector
	await click_control(selector)
	var popup: PopupMenu = selector.get_popup()
	check(popup.visible, "Language menu opens with mouse")
	# PopupMenu is its own Viewport; deliver keyboard events to that window.
	for attempt in range(3):
		if popup.get_focused_item() == 1:
			break
		await key_event(KEY_DOWN, popup)
	await key_event(KEY_ENTER, popup)
	await get_tree().process_frame
	check(Localization.language == "ru" and game.hud.army_buttons[&"worker"].text.contains("Рабочий"), "Native language dropdown changes UI immediately")
	var config := ConfigFile.new()
	check(config.load(Localization.SETTINGS_PATH) == OK and config.get_value("interface", "language") == "ru", "Settings selection persists to disk")
	Input.parse_input_event(escape)
	await get_tree().process_frame
	check(not is_instance_valid(game.hud.settings_panel) and get_tree().paused, "Escape closes Settings without resuming match")
	Input.parse_input_event(escape)
	await get_tree().process_frame
	check(not get_tree().paused,"Escape resumes")
	game.hud._restart()
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	check(game.commanders.size() == 4 and not game.match_finished,"Restart produces fresh four-commander match")
	await capture_languages()
	# The test restores the user's preference byte-for-byte, including a fresh install.
	if had_settings:
		var file := FileAccess.open(Localization.SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(saved_settings)
		file.close()
	else:
		DirAccess.remove_absolute(Localization.SETTINGS_PATH)
	Localization.load_preference()
	print("LIVE PLAYTEST COMPLETE failures=",failures)
	if failures > 0:
		get_tree().quit(1)


func click_control(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func key_event(code: Key, target: Window) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.window_id = target.get_window_id()
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func capture_languages() -> void:
	var window := get_tree().root
	game.hud._toggle_pause()
	# Embedded editor play locks the window size. The standalone visual suite tests
	# all requested resolutions; this MCP pass records the actual live viewport.
	for locale in ["en", "ru"]:
		Localization.set_language(locale, false)
		await get_tree().create_timer(0.25,true).timeout
		RenderingServer.force_draw()
		var picture: Image = window.get_texture().get_image()
		check(picture.get_size() == window.size, "Live viewport pixels " + locale + " " + str(picture.get_size()))
		picture.save_png("res:/" + "/tests/artifacts/mcp_live_" + locale + ".png")
	game.hud._toggle_pause()
