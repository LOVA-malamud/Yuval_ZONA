class_name MapDefinition
extends Resource
@export var bounds := Vector2(4600, 2600)
@export var obstacles: Array[Rect2] = []
@export var routes: Array[PackedVector2Array] = []
@export var bases: Array[Vector2] = [Vector2(400, 1300), Vector2(4200, 1300)]
@export var home_pads: Array[Vector2] = [Vector2(750, 1250), Vector2(1090, 900), Vector2(1090, 1770)]
@export var neutral_pads: Array[Vector2] = [Vector2(2300, 810), Vector2(2300, 1570), Vector2(2300, 2070)]
@export var groves: Array[Vector2] = [Vector2(450, 950), Vector2(450, 1650), Vector2(1150, 650), Vector2(1150, 1950)]

func _init() -> void:
	obstacles = RouteMap.OBSTACLES.duplicate()
	# Defaults live here; navigation consumes the same resolved map as drawing.
	routes = [
		PackedVector2Array([Vector2(400,1300), Vector2(1000,1100), Vector2(1550,550), Vector2(2300,700), Vector2(3050,550), Vector2(3600,1100), Vector2(4200,1300)]),
		PackedVector2Array([Vector2(400,1300), Vector2(1000,1400), Vector2(1550,1250), Vector2(2300,1470), Vector2(3050,1250), Vector2(3600,1400), Vector2(4200,1300)]),
		PackedVector2Array([Vector2(400,1300), Vector2(1000,1600), Vector2(1550,2050), Vector2(2300,1950), Vector2(3050,2050), Vector2(3600,1600), Vector2(4200,1300)]),
	]
