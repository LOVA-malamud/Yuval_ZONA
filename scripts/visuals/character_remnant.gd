extends Node2D
## A short visual snapshot, independent of the dead actor's lifetime/targetability.
const Visual = preload("res://scripts/visuals/character_visual.gd")
var game
var role: StringName = &"melee"
var team_id: int = 1
var facing_index: int = 2
var born_tick: int = 0
var age := 0.0
const DURATION := 0.5

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	born_tick = game.session.ticks
	z_index = -1

func _process(_delta: float) -> void:
	var next_age: float = (game.session.ticks - born_tick) * MatchSession.STEP
	if next_age >= DURATION:
		queue_free()
	elif next_age != age:
		age = next_age
		queue_redraw()

func _draw() -> void:
	var frame: int = clampi(int(age / DURATION * Visual.FRAMES),0,Visual.FRAMES-1)
	Visual.paint_pose(self,role,team_id,&"death",facing_index,frame,false,0,Vector2.ZERO,1.0,Color(1,1,1,1.0-age/DURATION))
