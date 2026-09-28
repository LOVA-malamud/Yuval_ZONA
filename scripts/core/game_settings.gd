extends Node
## Small, version-tolerant preferences store. Saving replaces a temporary file
## atomically and preserves unrelated sections, including the locale preference.
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MASTER: float = 0.8
const DEFAULT_SFX: float = 0.75
var storage_path: String = SETTINGS_PATH
var master_volume: float = DEFAULT_MASTER
var sfx_volume: float = DEFAULT_SFX
var fullscreen: bool = false
var onboarding_enabled: bool = true
var last_save_error: Error = OK


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus()
	load_settings()


func load_settings(path: String = "") -> void:
	var config := ConfigFile.new()
	if config.load(storage_path if path.is_empty() else path) != OK:
		config.clear()
	master_volume = _volume(config.get_value("audio", "master", DEFAULT_MASTER), DEFAULT_MASTER)
	sfx_volume = _volume(config.get_value("audio", "sfx", DEFAULT_SFX), DEFAULT_SFX)
	fullscreen = _boolean(config.get_value("display", "fullscreen", false), false)
	onboarding_enabled = _boolean(config.get_value("interface", "onboarding", true), true)
	_apply_audio()
	_apply_display()
	settings_changed.emit()


func _volume(value: Variant, fallback: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), 0.0, 1.0)


func _boolean(value: Variant, fallback: bool) -> bool:
	return value if value is bool else fallback


func _ensure_audio_bus() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _apply_audio() -> void:
	_ensure_audio_bus()
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func set_master_volume(value: float, persist: bool = true) -> Error:
	master_volume = _volume(value, DEFAULT_MASTER)
	_apply_audio()
	return _changed(persist)


func set_sfx_volume(value: float, persist: bool = true) -> Error:
	sfx_volume = _volume(value, DEFAULT_SFX)
	_apply_audio()
	return _changed(persist)


func set_fullscreen(value: bool, persist: bool = true) -> Error:
	fullscreen = value
	_apply_display()
	return _changed(persist)


func set_onboarding_enabled(value: bool, persist: bool = true) -> Error:
	onboarding_enabled = value
	return _changed(persist)


func _changed(persist: bool) -> Error:
	settings_changed.emit()
	return save() if persist else OK


func reset_defaults() -> Error:
	master_volume = DEFAULT_MASTER
	sfx_volume = DEFAULT_SFX
	fullscreen = false
	onboarding_enabled = true
	Localization.set_language("en", false)
	_apply_audio()
	_apply_display()
	return _changed(true)


func save(path: String = "") -> Error:
	var destination: String = storage_path if path.is_empty() else path
	var config := ConfigFile.new()
	if config.load(destination) != OK:
		config.clear()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("interface", "onboarding", onboarding_enabled)
	config.set_value("interface", "language", Localization.language)
	var temporary: String = destination + ".tmp"
	last_save_error = config.save(temporary)
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(temporary, destination)
		if last_save_error != OK:
			DirAccess.remove_absolute(temporary)
	return last_save_error
