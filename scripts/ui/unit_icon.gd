extends Control
var kind: StringName = &"melee"
var tint := Color("68c5ed")
const VISUAL = preload("res://scripts/visuals/character_visual.gd")
const ART = preload("res://scripts/visuals/entity_art.gd")
func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if VISUAL.SHEETS.has(kind):
		var scale: float = minf(size.x / 54.0, size.y / 58.0)
		VISUAL.paint_pose(self, kind, 1 if tint.b > tint.r else 2, &"idle", 1, 0, false, 0, Vector2(size.x * 0.5, size.y * 0.5 + 20.0 * scale), scale)
	else:
		ART.paint(self, kind, tint, 0.0, size * 0.5 + Vector2(0,5), 0.8)
