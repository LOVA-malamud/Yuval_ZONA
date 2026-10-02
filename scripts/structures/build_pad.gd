extends Node2D
## Pads never block movement. Only the command boundary can spend/build on them.
var game = null
var pad_name: String = "PAD_DEFAULT"
var home_team_id: int = 0
var tower = null
var rebuild_remaining: float = 0.0

func _ready() -> void:
	add_to_group("build_pads")

func step_gameplay(delta: float) -> void:
	rebuild_remaining = maxf(0.0, rebuild_remaining - delta)
	queue_redraw()

func occupied() -> bool:
	return is_instance_valid(tower) and tower.alive

func released(_entity: CombatEntity) -> void:
	tower = null
	rebuild_remaining = game.balance.tower_rebuild_delay

func _draw() -> void:
	var tint := Color("d7c28a")
	if occupied():
		tint = tower.team.color
	elif home_team_id != 0:
		tint = game.team_by_id(home_team_id).color
	draw_circle(Vector2(0, 7), 45, Color(0.04, 0.07, 0.08, 0.4))
	draw_colored_polygon(PackedVector2Array([Vector2(-34,-22),Vector2(0,-40),Vector2(34,-22),Vector2(34,22),Vector2(0,40),Vector2(-34,22)]), Color("53625a"))
	draw_arc(Vector2.ZERO, 42, 0, TAU, 6, Color(tint, 0.7), 3, true)
	if occupied():
		draw_arc(Vector2.ZERO, 47, 0, TAU, 6, tint, 4, true)
		# Pennants carry ownership even when the tower is surrounded.
		for side in [-1,1]:
			draw_colored_polygon(PackedVector2Array([Vector2(side*43,15),Vector2(side*56,23),Vector2(side*43,31)]),tint)
	elif rebuild_remaining > 0:
		tint = Color("83908c")
		draw_line(Vector2(-10,-10),Vector2(10,10),tint,4)
		draw_line(Vector2(-10,10),Vector2(10,-10),tint,4)
		draw_arc(Vector2.ZERO,29,-PI/2,-PI/2+TAU*(1-rebuild_remaining/game.balance.tower_rebuild_delay),24,tint,3,true)
	else:
		draw_line(Vector2(-11,0),Vector2(11,0),tint,4)
		draw_line(Vector2(0,-11),Vector2(0,11),tint,4)
		draw_arc(Vector2.ZERO,29,0,TAU,24,Color(tint,0.4),1.5,true)
		if is_instance_valid(game.player) and game.player.position.distance_to(position) < 200:
			draw_string(ThemeDB.fallback_font,Vector2(-70,61),tr("BUILD_HINT"),HORIZONTAL_ALIGNMENT_CENTER,140,13,tint)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()
