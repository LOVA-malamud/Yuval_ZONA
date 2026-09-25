extends SceneTree
## Two independent engine launches verify persistence without changing user settings.
const TEST_PATH := "user://localization_launch_test.cfg"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var localization = root.get_node("Localization")
	var writing: bool = "write" in OS.get_cmdline_user_args()
	if writing:
		var error: Error = localization.set_language("ru", true, TEST_PATH)
		print("PREFERENCE WRITE ", error)
		quit(0 if error == OK else 1)
	else:
		localization.load_preference(TEST_PATH)
		var valid: bool = localization.language == "ru" and tr("SETTINGS") == "Настройки"
		print("PREFERENCE NEXT LAUNCH ", valid)
		DirAccess.remove_absolute(TEST_PATH)
		quit(0 if valid else 1)
