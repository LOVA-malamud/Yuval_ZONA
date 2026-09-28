extends SceneTree
## Build-time notice extraction only; excluded from the production source stage.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: --script export_licenses.gd -- /absolute/notices.txt")
		quit(2)
		return
	var file := FileAccess.open(arguments[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write engine license notices")
		quit(1)
		return
	file.store_string("GODOT ENGINE AND THIRD-PARTY NOTICES\nGenerated from " + Engine.get_version_info().string + "\n\n")
	file.store_string(Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHT NOTICES\n\n")
	for dependency in Engine.get_copyright_info():
		file.store_string(dependency.name + "\n" + "-".repeat(60) + "\n")
		for part in dependency.parts:
			file.store_string("Files:\n" + "\n".join(part.files) + "\nCopyright:\n" + "\n".join(part.copyright) + "\nLicense: " + part.license + "\n\n")
	file.store_string("\nLICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for license_name in names:
		file.store_string(license_name + "\n" + "-".repeat(60) + "\n" + licenses[license_name] + "\n\n")
	print("ENGINE NOTICES: ", file.get_length(), " bytes; ", licenses.size(), " license texts")
	file.close()
	quit()
