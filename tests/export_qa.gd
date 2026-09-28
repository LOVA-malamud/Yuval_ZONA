extends Node
## External QA autoload: never included in the production PCK.
var failures := 0
var checks := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("EXPORT FAIL: " + label)
	else:
		print("EXPORT PASS: ", label)

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[1] + "/" + label + ".png")

func _run() -> void:
	await get_tree().process_frame
	var settings = get_node("/root/GameSettings")
	var locale = get_node("/root/Localization")
	var audio = get_node("/root/AudioFeedback")
	var game = get_tree().current_scene
	print("EXPORT ENV: ", Engine.get_version_info(), " display=", DisplayServer.get_name(), " output=", AudioServer.output_device, " user=", OS.get_user_data_dir())
	# Never risk the developer's real preferences if override application name failed.
	if not OS.get_user_data_dir().contains("Crownfront Export QA"):
		push_error("Isolated export user directory was not applied")
		get_tree().quit(2)
		return
	check(game != null and game.name == "Main", "Production main scene launches")
	check(not has_node("/root/McpRuntimeAutoload"), "No MCP runtime autoload")
	check(not FileAccess.file_exists("res://addons/godot_mcp/mcp_runtime_autoload.gd") and not FileAccess.file_exists("res://tests/runtime_smoke.gd"), "Development scripts absent from PCK")
	check(game.commanders.size() == 4 and game.pads.size() == 9, "Four commanders and nine pads initialize")
	check(audio.streams.size() == 19, "All procedural audio resources initialize")
	var mode: String = OS.get_cmdline_user_args()[0]
	if mode == "read":
		check(locale.language == "ru" and tr("SETTINGS") == "Настройки", "Russian persists across separate release launches")
		check(is_equal_approx(settings.master_volume, 0.37) and is_equal_approx(settings.sfx_volume, 0.64), "Audio settings persist across separate release launches")
		check(not settings.onboarding_enabled and not settings.fullscreen, "Guidance and display settings persist across separate release launches")
		await capture("native-ru-restart")
		await _finish()
		return
	check(locale.language == "en", "Fresh installation starts English despite Russian launch locale")
	check(is_equal_approx(settings.master_volume, 0.8) and is_equal_approx(settings.sfx_volume, 0.75) and settings.onboarding_enabled, "First-launch audio and guidance defaults")
	await get_tree().create_timer(0.5).timeout
	await capture("native-en-first-launch")
	game.hud._toggle_pause()
	game.hud._open_settings()
	var panel = game.hud.settings_panel
	panel.language_selector.item_selected.emit(1)
	check(locale.language == "ru" and tr("SETTINGS") == "Настройки", "Settings UI selects packaged Russian translation")
	panel.master_slider.value = 37
	panel.sfx_slider.value = 64
	panel.onboarding_toggle.button_pressed = false
	settings.set_fullscreen(false)
	check(settings.save() == OK, "Export saves preferences")
	await capture("native-ru-settings")
	game.hud._close_settings()
	game.hud._toggle_pause()
	var mixer := AudioEffectCapture.new()
	mixer.buffer_length = 0.5
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, mixer)
	audio.stop_all()
	audio.play(&"purchase")
	await get_tree().create_timer(0.3).timeout
	var peak := 0.0
	for frame in mixer.get_buffer(mixer.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > 0.001 and peak < 1.0, "Actual release audio mixer emits non-silent, nonclipping output")
	print("EXPORT AUDIO PEAK: ", peak)
	AudioServer.remove_bus_effect(0, effect_index)
	mixer = null
	game.teams[0].money = 5000
	game.teams[0].wood = 5000
	for kind in [&"melee", &"ranged", &"tank", &"worker"]:
		check(game.purchase(1, kind), "Production recruitment " + String(kind))
	game.select_route(2)
	check(game.selected_route == 2, "Route selection")
	var pad = game.pads[0]
	game.player.global_position = pad.global_position + Vector2(0, 60)
	check(game.build_tower(game.player, pad), "Tower build creates resources/effect")
	check(game.upgrade_tower(game.player, pad), "Tower upgrades load correctly")
	check(game.effect_count > 0, "Live procedural effects load from the production PCK")
	check(game.purchase_upgrade(1, game.upgrades[0].id), "Upgrade purchase works")
	game.teams[1].king.take_damage(999999.0, 1)
	await get_tree().create_timer(1.1).timeout
	check(game.match_finished and game.winning_team_id == 1 and game.hud.result_overlay.visible, "King death shows victory")
	await capture("native-ru-victory")
	game.hud._restart()
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	check(not game.match_finished and not get_tree().paused and game.commanders.size() == 4, "Restart reconstructs active match")
	game.teams[0].king.take_damage(999999.0, 2)
	await get_tree().create_timer(1.1).timeout
	check(game.match_finished and game.winning_team_id == 2 and game.hud.result_overlay.visible, "King death shows defeat")
	await capture("native-ru-defeat")
	await _finish()

func _finish() -> void:
	get_node("/root/AudioFeedback").stop_all()
	print("EXPORT COMPLETE checks=", checks, " failures=", failures)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
