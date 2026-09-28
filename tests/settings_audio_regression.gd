extends SceneTree
## Isolated settings storage; never overwrite the developer's real preferences.
const TEST_PATH := "user://polish_settings_test.cfg"
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("SETTINGS/AUDIO PASS: ", message)


func _run() -> void:
	var settings = root.get_node("GameSettings")
	var localization = root.get_node("Localization")
	var audio = root.get_node("AudioFeedback")
	if "write" in OS.get_cmdline_user_args() or "read" in OS.get_cmdline_user_args():
		_persistence_launch(settings, localization)
		return
	var original_path: String = settings.storage_path
	var previous_language: String = localization.language
	var previous_fullscreen: bool = settings.fullscreen
	var previous_master: float = settings.master_volume
	var previous_sfx: float = settings.sfx_volume
	var previous_onboarding: bool = settings.onboarding_enabled
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()
	settings.storage_path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	TranslationServer.set_locale("ru")
	localization.load_preference(TEST_PATH)
	settings.load_settings()
	check(localization.language == "en", "Fresh install explicitly starts in English")
	check(is_equal_approx(settings.master_volume, 0.8) and is_equal_approx(settings.sfx_volume, 0.75), "Missing file restores conservative audio defaults")
	check(not settings.fullscreen and settings.onboarding_enabled, "First launch is windowed with guidance enabled")
	check(AudioServer.get_bus_index("SFX") >= 0, "SFX bus exists and routes through Master")
	settings.set_master_volume(0.33, false)
	settings.set_sfx_volume(0.42, false)
	settings.set_fullscreen(false, false)
	settings.set_onboarding_enabled(false, false)
	check(localization.set_language("ru", true, TEST_PATH) == OK, "Locale shares atomic preference save")
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "Successful save leaves no temporary file")
	settings.set_master_volume(0.9, false)
	settings.set_sfx_volume(0.9, false)
	settings.set_onboarding_enabled(true, false)
	localization.set_language("en", false)
	settings.load_settings()
	localization.load_preference(TEST_PATH)
	check(is_equal_approx(settings.master_volume, 0.33) and is_equal_approx(settings.sfx_volume, 0.42), "Audio values survive reload")
	check(not settings.onboarding_enabled and localization.language == "ru", "Guidance and Russian survive reload")
	var config := ConfigFile.new()
	config.load(TEST_PATH)
	config.set_value("future", "preserve", "extension")
	config.save(TEST_PATH)
	check(settings.set_master_volume(0.4) == OK, "Atomic replacement works with existing file")
	config.load(TEST_PATH)
	check(config.get_value("future", "preserve") == "extension", "Saving preserves unrelated future preference fields")
	config.set_value("audio", "master", "invalid")
	config.set_value("audio", "sfx", -5.0)
	config.set_value("display", "fullscreen", "true")
	config.set_value("interface", "onboarding", 0)
	config.set_value("interface", "language", "unknown")
	config.save(TEST_PATH)
	settings.load_settings()
	localization.load_preference(TEST_PATH)
	check(is_equal_approx(settings.master_volume, 0.8) and is_zero_approx(settings.sfx_volume), "Invalid type falls back and numeric range clamps")
	check(not settings.fullscreen and settings.onboarding_enabled, "Boolean strings and numbers cannot corrupt preferences")
	check(localization.language == "en", "Unsupported saved locale falls back to English")
	settings.set_master_volume(NAN, false)
	settings.set_sfx_volume(INF, false)
	check(is_equal_approx(settings.master_volume, 0.8) and is_equal_approx(settings.sfx_volume, 0.75), "Nonfinite volume values fall back safely")
	settings.set_master_volume(0.0, false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Zero master volume truly mutes")
	settings.set_master_volume(0.5, false)
	check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Master changes immediately unmute and update gain")
	settings.set_sfx_volume(0.0, false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Zero SFX volume mutes independently")
	var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	broken.store_string("[audio]\nmaster=0.01\nsfx=Vector2(\n")
	broken.close()
	# ConfigFile deliberately logs a parse error for this malformed fixture.
	settings.load_settings()
	localization.load_preference(TEST_PATH)
	check(is_equal_approx(settings.master_volume, 0.8) and settings.onboarding_enabled and localization.language == "en", "Corrupt file discards partial values and starts safely")
	settings.storage_path = "user://directory_that_does_not_exist/settings.cfg"
	check(settings.set_master_volume(0.6) != OK and is_equal_approx(settings.master_volume, 0.6), "Save failure reports error while current session preference remains applied")
	settings.storage_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	localization.set_language("ru", false)
	check(settings.reset_defaults() == OK and localization.language == "en" and settings.onboarding_enabled, "Reset defaults restores English, guidance, audio and windowed preference")
	check(not settings.fullscreen and is_equal_approx(settings.master_volume, 0.8) and is_equal_approx(settings.sfx_volume, 0.75), "Reset covers all persisted display and audio options")
	var waveform_valid: bool = true
	var total_bytes: int = 0
	for key in audio.CUES:
		var stream: AudioStreamWAV = audio.streams[key]
		var peak: int = 0
		for index in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(index)))
		waveform_valid = waveform_valid and stream.mix_rate == 22050 and not stream.stereo and peak > 100 and peak < 32767 and stream.get_length() < 1.0
		total_bytes += stream.data.size()
	check(waveform_valid and audio.streams.size() == 19, "All 19 original PCM cues contain nonclipping audio under one second")
	check(total_bytes < 400000, "Cached audio remains under 400 KB")
	audio.stop_all()
	check(audio.play(&"purchase"), "First purchase cue is accepted")
	check(not audio.play(&"purchase"), "Repeated purchase cue is cooldown limited")
	check(not audio.play(&"unknown_event"), "Unknown audio event safely rejects")
	audio.stop_all()
	check(audio.play(&"melee") and not audio.play(&"ranged"), "Different combat roles share an anti-spam gate")
	audio.stop_all()
	var suppressed_before: int = audio.suppressed_count
	for index in range(500):
		audio.play(&"melee")
	check(audio.suppressed_count - suppressed_before >= 499 and audio.active_voice_count() <= 1, "A 500-hit burst stays bounded")
	audio.stop_all()
	for key in [&"purchase", &"failed", &"ui_click", &"ui_hover", &"deposit", &"route", &"tower_build", &"tower_upgrade"]:
		audio.play(key)
	check(audio.active_voice_count() <= 8, "Ordinary feedback uses at most eight voices")
	check(audio.play(&"king_warning") and audio.play(&"king_death") and audio.play(&"victory"), "Critical cues retain reserved voices over a busy ordinary mix")
	check(audio.active_voice_count() <= 12 and audio.get_child_count() == 12, "Audio uses exactly twelve reusable players and never grows nodes")
	paused = true
	check(audio.can_process(), "Audio feedback remains active on pause and result screens")
	paused = false
	audio.stop_all()
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	await process_frame
	check(not audio.play(&"melee", Vector2(9000, 9000)), "Distant offscreen combat is inaudible")
	camera.queue_free()
	await process_frame
	var button := Button.new()
	root.add_child(button)
	audio.bind_button(button)
	button.disabled = true
	var before_hover: int = audio.played_count
	button.mouse_entered.emit()
	check(audio.played_count == before_hover, "Disabled buttons do not play hover cues")
	button.disabled = false
	button.mouse_entered.emit()
	check(audio.played_count == before_hover + 1, "Enabled button hover is connected")
	button.queue_free()
	audio.stop_all()
	var panel = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await process_frame
	localization.set_language("ru", false)
	check(panel.language_selector.selected == 1, "Open settings tracks external live locale changes")
	panel.master_slider.value = 27
	check(is_equal_approx(settings.master_volume, 0.27), "Settings slider updates the real audio bus preference")
	panel.onboarding_toggle.button_pressed = false
	check(not settings.onboarding_enabled, "Settings toggle updates persisted onboarding preference")
	panel.queue_free()
	await process_frame
	audio.stop_all()
	settings.set_master_volume(0.8, false)
	settings.set_sfx_volume(0.75, false)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.5
	var capture_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	audio.play(&"purchase")
	await create_timer(0.28).timeout
	var output: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var output_peak: float = 0.0
	for frame in output:
		output_peak = maxf(output_peak, maxf(absf(frame.x), absf(frame.y)))
	check(output_peak > 0.001 and output_peak < 1.0, "The actual audio mixer outputs a non-silent, nonclipping cue")
	AudioServer.remove_bus_effect(0, capture_index)
	capture = null
	settings.storage_path = original_path
	settings.set_master_volume(previous_master, false)
	settings.set_sfx_volume(previous_sfx, false)
	settings.set_fullscreen(previous_fullscreen, false)
	settings.set_onboarding_enabled(previous_onboarding, false)
	localization.set_language(previous_language, false)
	var final_bytes: PackedByteArray = FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()
	check(original_bytes == final_bytes, "Developer settings remain byte-for-byte unchanged")
	DirAccess.remove_absolute(TEST_PATH)
	print("AUDIO METRICS synthesis_us=", audio.synthesis_microseconds, " pcm_bytes=", total_bytes, " players=", audio.get_child_count())
	print("SETTINGS/AUDIO COMPLETE checks=", checks, " failures=", failures)
	audio.stop_all()
	# Let the audio mixer drain playback references before immediate test shutdown.
	await create_timer(0.1).timeout
	quit(1 if failures else 0)


func _persistence_launch(settings: Node, localization: Node) -> void:
	settings.storage_path = TEST_PATH
	if "write" in OS.get_cmdline_user_args():
		settings.set_master_volume(0.37, false)
		settings.set_sfx_volume(0.64, false)
		settings.set_fullscreen(false, false)
		settings.set_onboarding_enabled(false, false)
		localization.set_language("ru", false)
		check(settings.save() == OK, "First engine launch writes all preferences to isolated storage")
	else:
		settings.load_settings()
		localization.load_preference(TEST_PATH)
		check(is_equal_approx(settings.master_volume, 0.37) and is_equal_approx(settings.sfx_volume, 0.64), "Second engine process restores both audio settings")
		check(not settings.onboarding_enabled and not settings.fullscreen and localization.language == "ru", "Second engine process restores guidance, display and Russian")
		DirAccess.remove_absolute(TEST_PATH)
	print("SETTINGS LAUNCH COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
