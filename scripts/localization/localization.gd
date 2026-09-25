extends Node
## Native TranslationServer owns translation and notifies every Control/CanvasItem.
## The explicit preference overrides the OS locale, including on the first launch.
signal language_changed
const LANGUAGES := ["en", "ru"]
const SETTINGS_PATH := "user://settings.cfg"
var language: String = "en"

func _ready() -> void:
	# Text Translation resources load after engine resource loaders are initialized.
	TranslationServer.add_translation(preload("res://localization/en.tres"))
	TranslationServer.add_translation(preload("res://localization/ru.tres"))
	load_preference()

func load_preference(path: String = SETTINGS_PATH) -> void:
	var settings := ConfigFile.new()
	var chosen: String = "en"
	if settings.load(path) == OK:
		chosen = str(settings.get_value("interface", "language", "en"))
	set_language(chosen, false)

func set_language(locale: String, persist: bool = true, path: String = SETTINGS_PATH) -> Error:
	language = locale if locale in LANGUAGES else "en"
	TranslationServer.set_locale(language)
	language_changed.emit()
	if not persist:
		return OK
	var settings := ConfigFile.new()
	settings.load(path)
	settings.set_value("interface", "language", language)
	return settings.save(path)

func format_message(key: String, arguments: Array = []) -> String:
	var localized: Array = []
	for value in arguments:
		localized.append(tr(value) if value is String or value is StringName else value)
	return tr(key) % localized if not localized.is_empty() else tr(key)
