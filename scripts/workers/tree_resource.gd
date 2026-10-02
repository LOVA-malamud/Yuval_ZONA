class_name TreeResource
extends Node2D

@export var wood_remaining: int = 600
@export var renewable: bool = false
var game = null
var zone: StringName = &"home"
var initial_wood: int = 0

func _ready() -> void:
	initial_wood = wood_remaining
	add_to_group("trees")
	queue_redraw()

func available() -> bool:
	return renewable or wood_remaining > 0

func harvest(requested: int) -> int:
	var amount: int = maxi(0, requested) if renewable else mini(maxi(0, requested), wood_remaining)
	if not renewable:
		wood_remaining -= amount
		if amount > 0 and wood_remaining == 0 and game != null:
			game.session.publish({"type": "tree_depleted", "position": [position.x, position.y], "zone": String(zone), "wood": initial_wood})
	queue_redraw()
	return amount

func _draw() -> void:
	draw_set_transform(Vector2(6,12),0,Vector2(1,0.4))
	draw_circle(Vector2.ZERO,35,Color(0.03,0.08,0.06,0.4))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-7,-12,14,32),Color("876447"))
	draw_rect(Rect2(-2,-12,5,32),Color("b08858"))
	if available():
		var stock: float = 1.0 if renewable else clampf(float(wood_remaining) / maxf(1.0, initial_wood), 0.0, 1.0)
		var colors := [Color("1a4c3b"),Color("29634a"),Color("397e54")]
		for i in range(3):
			var width: float = 36-i*7
			var y: float = -i*22
			draw_colored_polygon(PackedVector2Array([Vector2(-width,y),Vector2(0,y-47),Vector2(width,y)]),colors[i].lerp(Color("a58a49"), (1.0 - stock) * 0.65))
		draw_line(Vector2(-4,-73),Vector2(-16,-49),Color("83a46d"),2)
	else:
		draw_circle(Vector2(0,9),9,Color("ad8c62"))
