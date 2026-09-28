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

func set_language(locale: String, persist: bool = true, path: String = "") -> Error:
	language = locale if locale in LANGUAGES else "en"
	TranslationServer.set_locale(language)
	language_changed.emit()
	if not persist:
		return OK
	var shared_settings := get_node_or_null("/root/GameSettings")
	if shared_settings != null:
		return shared_settings.save(path)
	var destination: String = SETTINGS_PATH if path.is_empty() else path
	var settings := ConfigFile.new()
	settings.load(destination)
	settings.set_value("interface", "language", language)
	# Also support isolated tools which instantiate localization without autoloads.
	var temporary: String = destination + ".tmp"
	var error: Error = settings.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, destination)
		if error != OK:
			DirAccess.remove_absolute(temporary)
	return error

func format_message(key: String, arguments: Array = []) -> String:
	var localized: Array = []
	for value in arguments:
		localized.append(tr(value) if value is String or value is StringName else value)
	return tr(key) % localized if not localized.is_empty() else tr(key)
