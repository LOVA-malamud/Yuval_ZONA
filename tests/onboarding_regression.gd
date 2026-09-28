extends SceneTree
## Exercise the real optional guide and isolated persistent onboarding preference.
const TEST_PATH := "user://onboarding_regression.cfg"
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("ONBOARDING PASS: ", message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture: bool = "capture" in args
	var dimensions := (args[1] if args.size() > 1 else "1280x720").split("x")
	var settings = root.get_node("GameSettings")
	var localization = root.get_node("Localization")
	var original_path: String = settings.storage_path
	var original_locale: String = localization.language
	settings.storage_path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	settings.load_settings()
	check(settings.onboarding_enabled, "Fresh installation enables dismissible guidance")
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = game.hud
	hud.active_pad = null
	hud._update_guidance()
	check(not paused and hud.guidance_panel.visible, "First match starts immediately with nonmodal guidance")
	var tip_keys := ["HELP_TIP_OBJECTIVE", "HELP_TIP_MOVE", "HELP_TIP_RECRUIT", "HELP_TIP_WORKERS", "HELP_TIP_MAP"]
	var tips_work: bool = true
	for index in range(tip_keys.size()):
		game.match_seconds = index * 15.0
		hud._update_guidance()
		tips_work = tips_work and hud.guidance_text.text == tr(tip_keys[index])
	check(tips_work, "Opening tips explain the objective, controls, routes, workers and minimap")
	hud.active_pad = game.pads[0]
	hud._update_guidance()
	check(hud.guidance_text.text == tr("HELP_TIP_PADS"), "Nearby build pads receive contextual guidance")
	hud.active_pad = null
	hud.tabs.current_tab = 1
	hud._update_guidance()
	check(hud.guidance_text.text == tr("HELP_TIP_UPGRADES"), "Upgrade tab receives contextual guidance")
	game.player.alive = false
	hud._update_guidance()
	check(hud.guidance_text.text == tr("HELP_TIP_RESPAWN"), "Commander death explains respawn and available purchases")
	game.player.alive = true
	hud.tabs.current_tab = 0
	hud.notify("KING_DANGER")
	hud.notify("RECRUITED", ["UNIT_WORKER"])
	check(hud.notice_key == "KING_DANGER", "Routine recruitment does not overwrite a King danger alert")
	hud.notice_time = 0
	hud.notify("RECRUITED", ["UNIT_WORKER"])
	check(hud.notice_key == "RECRUITED", "Routine feedback resumes after the danger alert expires")
	game.match_seconds = 100
	hud._update_guidance()
	check(not hud.guidance_panel.visible, "Opening guidance expires without permanently occupying the battlefield")
	game.match_seconds = 0
	hud._update_guidance()
	await process_frame
	await _click(_find_button(hud.guidance_panel, "HELP_DISMISS"))
	check(not settings.onboarding_enabled and not hud.guidance_panel.visible, "Hide tips dismisses guidance immediately and saves the preference")
	settings.set_onboarding_enabled(true, false)
	await process_frame
	await _click(_find_button(hud.guidance_panel, "HELP_BUTTON"))
	var guide = hud.help_panel
	await process_frame
	check(paused and is_instance_valid(guide), "Clicking How to play opens the guide and pauses gameplay")
	check(guide.TOPICS.size() == 6 and guide.guidance_toggle.button_pressed, "Guide exposes all six topics and current preference")
	await _click(guide.guidance_toggle)
	check(not settings.onboarding_enabled and FileAccess.file_exists(TEST_PATH), "Dismissing guidance writes only the isolated preference file")
	settings.set_onboarding_enabled(true, false)
	settings.load_settings()
	check(not settings.onboarding_enabled and not guide.guidance_toggle.button_pressed, "Dismissed preference reloads and updates an open guide")
	guide.select_topic(-1)
	check(guide.topic_index == 0 and guide.previous_button.disabled, "First page disables previous navigation")
	guide.select_topic(999)
	check(guide.topic_index == 5 and guide.next_button.disabled, "Last page disables next navigation")
	paused = true
	for locale in ["en", "ru"]:
		localization.set_language(locale, false)
		var complete: bool = true
		var fits: bool = true
		for index in range(guide.TOPICS.size()):
			guide.select_topic(index)
			await process_frame
			await process_frame
			complete = complete and not guide.topic_title.text.begins_with("HELP_") and guide.topic_body.text.length() > 100
			fits = fits and _fits(guide, root.get_visible_rect())
			if capture and DisplayServer.get_name() != "headless" and (not "map" in args or index == 5):
				RenderingServer.force_draw()
				var picture: Image = root.get_texture().get_image()
				var destination: String = "res:/" + "/tests/artifacts/help_topic_%d_%s_%dx%d.png" % [index, locale, root.size.x, root.size.y]
				check(picture.get_size() == root.size and picture.save_png(destination) == OK, "Guide screenshot " + destination)
		check(complete, "All guide topics translate in " + locale)
		check(fits, "All guide topics fit the reference canvas in " + locale + " at " + str(root.size))
	check(paused and guide.topic_title.text == tr("HELP_MAP_TITLE"), "Live language switching preserves pause and the selected topic")
	var escape := InputEventAction.new()
	escape.action = "pause_match"
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	check(not is_instance_valid(hud.help_panel) and paused, "Escape closes the guide while preserving pause")
	hud._open_help()
	guide = hud.help_panel
	await process_frame
	check(not guide.guidance_toggle.button_pressed, "Reopening the guide preserves the disabled preference")
	guide.guidance_toggle.button_pressed = true
	settings.set_onboarding_enabled(false, false)
	settings.load_settings()
	check(settings.onboarding_enabled and guide.guidance_toggle.button_pressed, "Guidance can be enabled again and persists")
	hud._close_help()
	settings.storage_path = original_path
	settings.load_settings()
	localization.set_language(original_locale, false)
	DirAccess.remove_absolute(TEST_PATH)
	paused = false
	root.get_node("AudioFeedback").stop_all()
	await create_timer(0.1).timeout
	print("ONBOARDING COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)


func _fits(node: Node, bounds: Rect2) -> bool:
	if node is Control and node.is_visible_in_tree() and not bounds.grow(2).encloses(node.get_global_rect()):
		return false
	for child in node.get_children():
		if not _fits(child, bounds):
			return false
	return true


func _find_button(node: Node, key: String) -> Button:
	if node is Button and node.text == key:
		return node
	for child in node.get_children():
		var button: Button = _find_button(child, key)
		if button != null:
			return button
	return null


func _click(control: Control) -> void:
	if control == null:
		check(false, "Required onboarding control exists")
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
