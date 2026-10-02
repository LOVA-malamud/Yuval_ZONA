class_name CommandResult
extends RefCounted
var success: bool
var reason: StringName

func _init(accepted: bool = false, explanation: StringName = &"invalid_request") -> void:
	success = accepted
	reason = explanation
