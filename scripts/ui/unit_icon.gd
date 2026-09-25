extends Control
var kind: StringName = &"melee"
var tint := Color("68c5ed")
const ART = preload("res://scripts/visuals/entity_art.gd")
func _draw() -> void:
	ART.paint(self, kind, tint, 0.0, size * 0.5 + Vector2(0,5), 0.8)
