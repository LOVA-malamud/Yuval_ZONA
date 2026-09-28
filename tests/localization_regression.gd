extends SceneTree
var failures: int = 0
const TEST_PATH := "user://localization_test.cfg"

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("LOCALIZATION PASS: ", message)

func _run() -> void:
	var localization = root.get_node("Localization")
	var previous: String = localization.language
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	TranslationServer.set_locale("ru")
	localization.load_preference(TEST_PATH)
	check(localization.language == "en" and TranslationServer.get_locale() == "en", "Fresh install overrides Russian OS locale with English")
	check(localization.set_language("ru", true, TEST_PATH) == OK, "Russian preference saves")
	localization.set_language("en", false)
	localization.load_preference(TEST_PATH)
	check(localization.language == "ru", "Saved preference reloads independently of current locale")
	localization.set_language("unsupported", false)
	check(localization.language == "en", "Unsupported preference falls back to English")
	var english: Translation = load("res://localization/en.tres")
	var russian: Translation = load("res://localization/ru.tres")
	check(english.get_message_list().size() == russian.get_message_list().size(), "Catalog key counts match")
	var token_pattern := RegEx.new()
	token_pattern.compile("%[-+0-9.]*[sdf]")
	var catalog_ok: bool = true
	var glyphs_ok: bool = true
	for key in english.get_message_list():
		var en: String = english.get_message(key)
		var ru: String = russian.get_message(key)
		var en_tokens: Array = []
		var ru_tokens: Array = []
		for token in token_pattern.search_all(en): en_tokens.append(token.get_string())
		for token in token_pattern.search_all(ru): ru_tokens.append(token.get_string())
		catalog_ok = catalog_ok and not ru.is_empty() and en_tokens == ru_tokens
		for character in ru:
			if character.unicode_at(0) >= 0x400 and character.unicode_at(0) <= 0x4ff:
				glyphs_ok = glyphs_ok and ThemeDB.fallback_font.has_char(character.unicode_at(0))
	check(catalog_ok, "Every Russian entry is present and preserves formatting placeholders")
	check(glyphs_ok, "Game font contains every Cyrillic glyph used by the catalog")
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud.notify("RECRUITED", ["UNIT_TANK"])
	localization.set_language("ru", false)
	await process_frame
	check(game.hud.army_buttons[&"worker"].text.contains("Рабочий"), "Live shop updates to Russian")
	check(game.hud.feedback_label.text.contains("Тяжёлый"), "Active formatted notice and unit name update immediately")
	check(game.hud.route_selector.get_item_text(0).contains("СЕВЕР"), "Route choices update immediately")
	check(game.hud.tabs.get_tab_title(2) == "Экономика", "Tab titles update")
	game.hud._toggle_pause()
	game.hud._open_settings()
	await process_frame
	check(game.hud.settings_panel.language_selector.selected == 1 and paused, "Settings shows selected language while match remains paused")
	localization.set_language("en", false)
	check(game.hud.army_buttons[&"worker"].text.contains("Worker"), "English switch works while paused")
	game.hud._close_settings()
	game.hud._toggle_pause()
	game.teams[1].king.take_damage(99999,1)
	localization.set_language("ru", false)
	check(game.hud.result_details.text.contains("Вражеский король"), "End-screen details update after match conclusion")
	localization.set_language(previous, false)
	DirAccess.remove_absolute(TEST_PATH)
	paused = false
	# The final result cues were just queued; let the audio mixer release playback.
	root.get_node("AudioFeedback").stop_all()
	await create_timer(0.1).timeout
	print("LOCALIZATION COMPLETE failures=", failures)
	quit(1 if failures else 0)
