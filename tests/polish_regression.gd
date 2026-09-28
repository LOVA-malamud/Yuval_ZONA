extends SceneTree
## Bounded effects, critical feedback and presentation caching regression.
## Run with the real renderer too: draw-signal checks are skipped headlessly.
const TEST_PATH := "user://polish_feedback_test.cfg"
var failures: int = 0
var checks: int = 0
var game = null


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("POLISH PASS: ", message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	var settings = root.get_node("GameSettings")
	var audio = root.get_node("AudioFeedback")
	var localization = root.get_node("Localization")
	var original_path: String = settings.storage_path
	var original_locale: String = localization.language
	var original_guidance: bool = settings.onboarding_enabled
	var original_audio := Vector2(settings.master_volume, settings.sfx_volume)
	var original_bytes := FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()
	settings.storage_path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	localization.set_language("en", false)
	game = load("res://scenes/main/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	_clear_effects()
	check(game.effect_count == 0, "Effects release their budget when removed")
	for index in range(500):
		game.spawn_effect(Vector2(400, 1300), Color.WHITE, "impact")
	check(game.effect_count == game.MAX_EFFECTS and _effects().size() == game.MAX_EFFECTS, "500 simultaneous ordinary effects remain capped at 48")
	game.spawn_effect(Vector2(400, 1300), Color.WHITE, "crownfall")
	check(game.effect_count == game.MAX_EFFECTS + 1, "King destruction bypasses an exhausted ordinary visual budget")
	for effect in _effects():
		effect._process(2.0)
	await process_frame
	check(game.effect_count == 0 and _effects().is_empty(), "Expired effects free their nodes and restore the full budget")
	game.spawn_effect(Vector2(400, 1300), Color.WHITE, "crownfall")
	paused = true
	await create_timer(1.3, true).timeout
	check(game.effect_count == 0, "Crown destruction finishes even while the result screen pauses gameplay")
	paused = false
	var hud = game.hud
	game.match_seconds = 20
	game.teams[0].king.take_damage(90, 2)
	check(hud.notice_key == "KING_DANGER" and game.teams[0].king.danger_remaining > 0, "Sustained friendly King damage produces the priority warning")
	game.player.take_damage(9999, 2)
	hud.notify("RECRUITED", ["UNIT_WORKER"])
	check(hud.notice_key == "KING_DANGER", "Commander loss and purchases cannot replace active King danger")
	game.player._physics_process(12.1)
	check(game.player.alive and hud.notice_key == "KING_DANGER", "Respawn restores commander without erasing critical objective feedback")
	hud.notice_time = 0
	hud.notify("COMMANDER_RETURNED")
	check(hud.notice_key == "COMMANDER_RETURNED", "Normal feedback resumes after the critical notice expires")
	game.teams[0].add_resources(9, 9)
	localization.set_language("ru", false)
	check(hud.resource_hint.text == tr("RESOURCE_GAIN") % [9, 9], "An active resource deposit notice switches language immediately")
	localization.set_language("en", false)
	settings.storage_path = "user://polish_missing_directory/settings.cfg"
	hud.notice_time = 0
	hud._dismiss_guidance()
	check(not settings.onboarding_enabled and hud.notice_key == "SETTINGS_SAVE_FAILED", "Guidance remains dismissed for the session and reports failed persistence")
	settings.storage_path = TEST_PATH
	check(localization.set_language("ru") == OK and FileAccess.file_exists(TEST_PATH), "Default locale persistence honors the configured isolated settings store")
	var config := ConfigFile.new()
	check(config.load(TEST_PATH) == OK and config.get_value("interface", "language") == "ru", "Isolated locale save writes the actual selected language")
	localization.set_language("en", false)
	game.teams[0].money = 0
	hud._refresh()
	check(hud.army_buttons[&"melee"].disabled, "Shop invalidation reflects unaffordable units")
	game.teams[0].money = 1000
	hud._refresh()
	check(not hud.army_buttons[&"melee"].disabled, "Shop invalidation responds when resources become available")
	var unit = game.UNIT_SCENE.instantiate()
	unit.configure(game.teams[0], game, game.unit_data[&"melee"])
	game.entities.add_child(unit)
	var transform: Transform2D = unit.get_canvas_transform()
	unit.global_position = transform.affine_inverse() * (root.get_visible_rect().size * 0.5)
	unit.tick(0.01)
	check(unit.presentation_visible, "An actor inside the viewport retains visible presentation")
	var center: Vector2 = unit.global_position
	unit.global_position = transform.affine_inverse() * Vector2(-5000, -5000)
	unit.tick(0.01)
	check(not unit.presentation_visible, "Distant offscreen actors skip idle presentation")
	unit.shot_end = center
	unit.shot_time = 0.22
	check(unit._presentation_in_view(), "An offscreen shooter retains traces that enter the viewport")
	unit.shot_time = 0
	unit.take_damage(10, 2)
	unit.tick(1.0)
	unit.global_position = center
	unit.tick(0.01)
	check(unit.presentation_visible and is_zero_approx(unit.hit_flash) and unit.health < unit.max_health, "Returning actors refresh current health without a stale hit flash")
	if DisplayServer.get_name() != "headless":
		var observed := {"draws": 0}
		unit.draw.connect(func(): observed.draws += 1)
		unit.queue_redraw()
		await process_frame
		await process_frame
		var count: int = observed.draws
		for index in range(6):
			unit.tick(0.02)
			await process_frame
		check(observed.draws == count and count > 0, "Rendered idle infantry reuses cached silhouette draw commands")
		unit.take_damage(1, 2)
		await process_frame
		await process_frame
		check(observed.draws > count, "Rendered damage invalidates the cached silhouette")
		var after_damage: int = observed.draws
		unit.tick(1.0)
		await process_frame
		await process_frame
		check(observed.draws > after_damage, "Final hit-flash expiry performs its own silhouette redraw")
	else:
		print("POLISH NOTE: Actual draw-signal assertions require a rendered run")
	# Measure the shared mixer under a dense event burst, including reserved cues.
	audio.stop_all()
	settings.set_master_volume(1.0, false)
	settings.set_sfx_volume(1.0, false)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.5
	var capture_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	for cue in [&"purchase", &"failed", &"ui_click", &"ui_hover", &"deposit", &"route", &"tower_build", &"tower_upgrade", &"commander_death", &"respawn", &"king_warning", &"king_death"]:
		audio.play(cue)
	await create_timer(0.35).timeout
	var peak: float = 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(peak > 0.001 and peak < 0.95, "A dense ordinary and critical cue mix retains headroom at maximum volume")
	print("POLISH AUDIO MIX peak=", peak)
	AudioServer.remove_bus_effect(0, capture_index)
	capture = null
	audio.stop_all()
	audio.play(&"victory")
	hud._restart()
	check(audio.active_voice_count() == 0, "Restart immediately stops previous-match feedback voices")
	await process_frame
	await process_frame
	game = current_scene
	game.process_mode = Node.PROCESS_MODE_DISABLED
	check(not paused and not game.match_finished and game.commanders.size() == 4, "Polished feedback survives a clean four-commander restart")
	settings.storage_path = original_path
	settings.set_onboarding_enabled(original_guidance, false)
	settings.set_master_volume(original_audio.x, false)
	settings.set_sfx_volume(original_audio.y, false)
	localization.set_language(original_locale, false)
	DirAccess.remove_absolute(TEST_PATH)
	var final_bytes := FileAccess.get_file_as_bytes(original_path) if FileAccess.file_exists(original_path) else PackedByteArray()
	check(original_bytes == final_bytes, "Polish regression never modifies the real developer settings")
	audio.stop_all()
	await create_timer(0.1).timeout
	print("POLISH COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)


func _effects() -> Array:
	var result: Array = []
	for child in game.get_children():
		if child.get_script() == game.EFFECT_SCRIPT:
			result.append(child)
	return result


func _clear_effects() -> void:
	for effect in _effects():
		effect.free()
