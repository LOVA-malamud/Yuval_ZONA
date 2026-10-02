extends Node
## Input-driven integration scene for MCP. Leaves the normal match running on success.
var game = null
var failures: int = 0
var checks: int = 0
const TEST_SETTINGS := "user://live_polish_test.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("LIVE PASS: ",message)
	else:
		failures += 1
		push_error("LIVE FAIL: " + message)

func _run() -> void:
	var original_path: String = GameSettings.storage_path
	var original_locale: String = Localization.language
	var original_preferences := [GameSettings.master_volume, GameSettings.sfx_volume, GameSettings.fullscreen, GameSettings.onboarding_enabled]
	var original_difficulty: StringName = GameSettings.difficulty
	var original_bytes := FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()
	GameSettings.storage_path = TEST_SETTINGS
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(TEST_SETTINGS)
	GameSettings.load_settings()
	Localization.set_language("en", false)
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
	await click_control(game.hud.route_selector)
	var route_popup: PopupMenu = game.hud.route_selector.get_popup()
	for attempt in range(4):
		if route_popup.get_focused_item() == 0:
			break
		await key_event(KEY_DOWN, route_popup)
	await key_event(KEY_ENTER, route_popup)
	check(game.selected_route == 0 and game.route_highlight > 0,"Route selector updates new-recruit orders")
	var enemy = game.UNIT_SCENE.instantiate()
	enemy.configure(game.teams[1],game,game.unit_data[&"tank"])
	enemy.position = game.player.position+Vector2(50,0)
	enemy.practice_unit = true
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.entities.add_child(enemy)
	var enemy_hp: float = enemy.health
	Input.action_press("attack")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("attack")
	check(enemy.health < enemy_hp,"SPACE input attacks enemy")
	await click_at(game.player.get_canvas_transform() * enemy.position)
	check(game.player.controller.focus_target == enemy, "Mouse selects a visible enemy as focus target")
	enemy.position += Vector2(1000, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.player.controller.focus_target == null, "Focus clears after target leaves detection range")
	enemy.free()
	var recruit = null
	for actor in game.session.actors.values():
		if actor.category == &"army" and actor.team == game.player.team:
			recruit = actor
			break
	recruit.position = game.player.position + Vector2(80, 0)
	var rally := InputEventAction.new()
	rally.action = "rally"
	rally.pressed = true
	get_viewport().push_input(rally, true)
	await get_tree().create_timer(0.1).timeout
	check(recruit.rally_buff > 7 and game.player.rally_cooldown > 29, "Rally input buffs nearby recruit and starts cooldown")
	var regroup := InputEventAction.new()
	regroup.action = "regroup"
	regroup.pressed = true
	get_viewport().push_input(regroup, true)
	await get_tree().create_timer(0.1).timeout
	check(recruit.regroup_remaining > 7, "Regroup input gives temporary local movement order")
	await click_control(find_button(game.hud.controls, "COMMAND_BUTTON"))
	check(game.hud.command_panel.visible, "Mouse opens ally command panel")
	await click_control(game.hud.command_panel.order_selector)
	var order_popup: PopupMenu = game.hud.command_panel.order_selector.get_popup()
	for attempt in range(8):
		if order_popup.get_focused_item() == 4:
			break
		await key_event(KEY_DOWN, order_popup)
	await key_event(KEY_ENTER, order_popup)
	await get_tree().create_timer(0.1).timeout
	check(game.commanders[1].controller.order == &"defend", "Native dropdown sends persistent Defend ally order")
	await click_control(find_button(game.hud.command_panel, "COMMAND_CLOSE"))
	game.player.position = game.pads[0].position+Vector2(-45,0)
	await get_tree().create_timer(0.2).timeout
	await click_control(game.hud.structure_button)
	check(game.pads[0].occupied(),"Context build button constructs tower")
	await get_tree().create_timer(0.2).timeout
	await click_control(game.hud.structure_button)
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
	var settings = game.hud.settings_panel
	await click_at(settings.master_slider.get_global_rect().position + Vector2(settings.master_slider.size.x * 0.3, settings.master_slider.size.y * 0.5))
	check(GameSettings.master_volume > 0.2 and GameSettings.master_volume < 0.4, "Real mouse slider input changes Master volume immediately")
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(GameSettings.master_volume)), "Master slider updates the actual mixer gain")
	await click_at(settings.sfx_slider.get_global_rect().position + Vector2(settings.sfx_slider.size.x * 0.6, settings.sfx_slider.size.y * 0.5))
	check(GameSettings.sfx_volume > 0.5 and GameSettings.sfx_volume < 0.7, "Real mouse slider input changes SFX volume")
	await click_control(settings.onboarding_toggle)
	check(not GameSettings.onboarding_enabled, "Mouse dismisses future guidance through Settings")
	if "display" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await click_control(settings.fullscreen_toggle)
		await get_tree().create_timer(1.0, true).timeout
		check(GameSettings.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Mouse applies native fullscreen mode")
		print("LIVE DISPLAY before_return mode=", DisplayServer.window_get_mode(), " pref=", GameSettings.fullscreen, " size=", get_tree().root.size, " rect=", settings.fullscreen_toggle.get_global_rect())
		await click_control(settings.fullscreen_toggle)
		await get_tree().create_timer(1.0, true).timeout
		print("LIVE DISPLAY after_return mode=", DisplayServer.window_get_mode(), " pref=", GameSettings.fullscreen, " size=", get_tree().root.size, " rect=", settings.fullscreen_toggle.get_global_rect())
		check(not GameSettings.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Mouse returns from fullscreen to windowed mode")
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
	check(config.load(TEST_SETTINGS) == OK and config.get_value("interface", "language") == "ru", "Settings selection persists to isolated disk path")
	check(is_equal_approx(float(config.get_value("audio", "master")), GameSettings.master_volume) and not config.get_value("interface", "onboarding"), "Mouse volume and guidance selections persist together")
	await click_control(find_button(settings, "RESET_DEFAULTS"))
	check(Localization.language == "en" and GameSettings.onboarding_enabled and is_equal_approx(GameSettings.master_volume, 0.8), "Mouse reset restores default preferences and live English UI")
	Input.parse_input_event(escape)
	await get_tree().process_frame
	check(not is_instance_valid(game.hud.settings_panel) and get_tree().paused, "Escape closes Settings without resuming match")
	await click_control(find_button(game.hud.result_overlay, "HELP_BUTTON"))
	check(is_instance_valid(game.hud.help_panel) and get_tree().paused, "Mouse opens optional guide from pause")
	await click_control(game.hud.help_panel.next_button)
	check(game.hud.help_panel.topic_index == 1, "Mouse navigates to recruitment guidance")
	Input.parse_input_event(escape)
	await get_tree().process_frame
	check(not is_instance_valid(game.hud.help_panel) and get_tree().paused, "Escape closes guide while preserving pause")
	Input.parse_input_event(escape)
	await get_tree().process_frame
	check(not get_tree().paused,"Escape resumes")
	game.player.controller.touch_index = 7
	game.player.controller.touch_direction = Vector2.RIGHT
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().process_frame
	check(get_tree().paused and game.player.controller.touch_index == -1, "Application focus loss pauses and clears held touch input")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	check(not get_tree().paused, "System Back resumes paused match")
	get_viewport().push_input(escape, true)
	await get_tree().process_frame
	await click_control(find_button(game.hud.result_overlay, "RESTART"))
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	check(game.commanders.size() == 4 and not game.match_finished,"Restart produces fresh four-commander match")
	get_viewport().push_input(escape, true)
	await get_tree().process_frame
	await click_control(game.hud.difficulty_selector)
	var difficulty_popup: PopupMenu = game.hud.difficulty_selector.get_popup()
	for attempt in range(4):
		if difficulty_popup.get_focused_item() == 2:
			break
		await key_event(KEY_DOWN, difficulty_popup)
	await key_event(KEY_ENTER, difficulty_popup)
	check(GameSettings.difficulty == &"hard" and game.rules.difficulty == &"standard", "Native difficulty selector changes the next match only")
	config.load(TEST_SETTINGS)
	check(config.get_value("gameplay", "difficulty") == "hard", "Difficulty preference persists in isolated settings")
	await click_control(find_button(game.hud.result_overlay, "TUTORIAL_BUTTON"))
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	check(game.tutorial_mode and game.tutorial.stage == TutorialDirector.Stage.MOVE, "Mouse starts a separate playable tutorial")
	Input.action_press("move_right")
	await get_tree().create_timer(0.4).timeout
	Input.action_release("move_right")
	check(game.tutorial.stage == TutorialDirector.Stage.ATTACK, "Real movement advances tutorial lesson")
	get_viewport().push_input(escape, true)
	await get_tree().process_frame
	await click_control(find_button(game.hud.result_overlay, "RESTART"))
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	check(game.tutorial_mode and game.tutorial.stage == TutorialDirector.Stage.MOVE, "Mouse restart resets tutorial progress")
	await click_control(find_button(game.hud.guidance_panel, "TUTORIAL_SKIP"))
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	check(not game.tutorial_mode and game.tutorial == null, "Mouse skips tutorial into a fresh ordinary match")
	check(game.rules.difficulty == &"hard" and game.teams[0].money == game.teams[1].money and game.teams[0].wood == game.teams[1].wood and game.teams[0].worker_count == game.teams[1].worker_count, "Fresh match applies Hard with equal team resources")
	await capture_languages()
	GameSettings.difficulty = original_difficulty
	GameSettings.storage_path = original_path
	GameSettings.set_master_volume(original_preferences[0], false)
	GameSettings.set_sfx_volume(original_preferences[1], false)
	GameSettings.set_fullscreen(original_preferences[2], false)
	GameSettings.set_onboarding_enabled(original_preferences[3], false)
	Localization.set_language(original_locale, false)
	DirAccess.remove_absolute(TEST_SETTINGS)
	var final_bytes := FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()
	check(original_bytes == final_bytes, "Live input suite leaves real developer settings byte-for-byte unchanged")
	print("LIVE PLAYTEST COMPLETE checks=", checks, " failures=",failures)
	if failures > 0 or "finish" in OS.get_cmdline_user_args():
		game.process_mode = Node.PROCESS_MODE_DISABLED
		AudioFeedback.stop_all()
		await get_tree().create_timer(0.1, true).timeout
		get_tree().quit(1 if failures > 0 else 0)


func click_control(control: Control) -> void:
	if control == null:
		check(false, "Required live UI control exists")
		return
	await click_at(control.get_global_rect().get_center())

func click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func find_button(node: Node, key: String) -> Button:
	if node is Button and node.text == key:
		return node
	for child in node.get_children():
		var button := find_button(child, key)
		if button != null:
			return button
	return null

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
	if DisplayServer.get_name() == "headless":
		return
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
		var prefix: String = "review_live_" if "finish" in OS.get_cmdline_user_args() else "mcp_live_"
		check(picture.save_png("res:/" + "/tests/artifacts/" + prefix + locale + ".png") == OK, "Live viewport capture saved in " + locale)
	game.hud._toggle_pause()
