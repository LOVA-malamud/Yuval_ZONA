extends SceneTree

func _initialize() -> void:
	call_deferred("configure")

func configure() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var settings := EditorInterface.get_editor_settings()
	if settings == null:
		push_error("Android export setup requires editor settings")
		quit(1)
		return
	settings.set("export/android/android_sdk_path", args[0])
	settings.set("export/android/java_sdk_path", args[1])
	quit()
