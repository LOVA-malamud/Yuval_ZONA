class_name EntityArt
extends RefCounted
## Original procedural silhouettes shared by battlefield actors and shop cards.
const INK := Color("14262e")
const STEEL := Color("c3d5d8")
const GOLD := Color("edc46e")

static func paint(c: CanvasItem, kind: StringName, tint: Color, phase: float = 0.0, origin: Vector2 = Vector2.ZERO, amount: float = 1.0) -> void:
	var shadow_scale := Vector2(1.0, 0.42)
	c.draw_set_transform(origin + Vector2(0, 12) * amount, 0, shadow_scale * amount)
	c.draw_circle(Vector2.ZERO, 21 if kind != &"king" else 52, Color(0.02,0.04,0.05,0.4))
	c.draw_set_transform(origin, 0, Vector2.ONE * amount)
	match kind:
		&"king":
			c.draw_colored_polygon(PackedVector2Array([Vector2(-47,20),Vector2(0,43),Vector2(47,20),Vector2(0,-10)]), Color("697b7b"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(-34,-29),Vector2(34,-29),Vector2(38,22),Vector2(-38,22)]), INK)
			c.draw_rect(Rect2(-28,-26,56,45), tint.darkened(0.3))
			c.draw_rect(Rect2(-20,-20,40,37), tint)
			c.draw_rect(Rect2(-12,-14,24,25), Color("f0dfb9"))
			c.draw_line(Vector2(-19,11),Vector2(19,11),GOLD,5)
			c.draw_circle(Vector2(0,-24),15, Color("e9c998"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(-20,-32),Vector2(-24,-54),Vector2(-10,-43),Vector2(0,-60),Vector2(10,-43),Vector2(24,-54),Vector2(20,-32)]), GOLD)
			c.draw_circle(Vector2(0,-43),4,tint)
			for side in [-1,1]:
				c.draw_line(Vector2(side*49,20),Vector2(side*49,-58),GOLD,3)
				c.draw_colored_polygon(PackedVector2Array([Vector2(side*49,-55),Vector2(side*73,-48),Vector2(side*49,-23)]),tint)
		&"tower":
			c.draw_colored_polygon(PackedVector2Array([Vector2(-27,21),Vector2(-22,-33),Vector2(22,-33),Vector2(27,21)]),Color("a5b0a0"))
			c.draw_rect(Rect2(3,-30,18,50),Color("6d817e"))
			for y in [-22,-6,10]:
				c.draw_line(Vector2(-22,y),Vector2(22,y),Color("526965"),2)
			c.draw_rect(Rect2(-30,-42,60,16),INK)
			for x in [-26,-5,16]:
				c.draw_rect(Rect2(x,-51,12,16),STEEL)
			c.draw_rect(Rect2(-10,-24,20,24),tint)
			c.draw_colored_polygon(PackedVector2Array([Vector2(-10,0),Vector2(10,0),Vector2(0,10)]),tint)
			c.draw_line(Vector2(0,-54),Vector2(0,-76),GOLD,2)
			c.draw_colored_polygon(PackedVector2Array([Vector2(0,-76),Vector2(24,-70),Vector2(0,-63)]),tint)
		&"player":
			c.draw_colored_polygon(PackedVector2Array([Vector2(-12,-14),Vector2(12,-14),Vector2(22,21+sin(phase)*2),Vector2(0,15),Vector2(-22,21)]),tint.darkened(0.35))
			c.draw_rect(Rect2(-11,-13,22,27),INK)
			c.draw_rect(Rect2(-9,-12,18,22),STEEL)
			c.draw_rect(Rect2(-9,-3,18,12),tint)
			c.draw_circle(Vector2(0,-19),11,INK)
			c.draw_circle(Vector2(0,-21),9,STEEL)
			c.draw_line(Vector2(-7,-20),Vector2(7,-20),INK,3)
			c.draw_line(Vector2(0,-30),Vector2(3,-40),tint,5)
			_sword(c,Vector2(23,-1),1.2)
			_shield(c,Vector2(-18,2),tint,1.1)
		&"tank":
			c.draw_rect(Rect2(-19,-13,38,33),INK)
			c.draw_rect(Rect2(-16,-15,32,28),tint.darkened(0.3))
			c.draw_circle(Vector2(-18,-10),8,STEEL)
			c.draw_circle(Vector2(18,-10),8,STEEL)
			c.draw_rect(Rect2(-11,-27,22,21),STEEL)
			c.draw_line(Vector2(-8,-18),Vector2(8,-18),INK,4)
			_shield(c,Vector2(0,7),tint,1.6)
			# A broad siege hammer distinguishes the heavy unit from sword infantry.
			c.draw_line(Vector2(23,17),Vector2(25,-23),INK,6)
			c.draw_line(Vector2(23,17),Vector2(25,-23),GOLD,3)
			c.draw_rect(Rect2(16,-29,23,12),INK)
			c.draw_rect(Rect2(18,-27,19,8),STEEL)
		&"ranged":
			c.draw_colored_polygon(PackedVector2Array([Vector2(0,-28),Vector2(14,-10),Vector2(11,18),Vector2(-13,18),Vector2(-14,-10)]),tint.darkened(0.25))
			c.draw_circle(Vector2(0,-14),7,Color("e0c5a0"))
			c.draw_line(Vector2(-7,3),Vector2(8,11),GOLD,3)
			c.draw_arc(Vector2(12,-1),17,-1.3,1.3,16,GOLD,3,true)
			c.draw_line(Vector2(16,-17),Vector2(16,15),STEEL,1)
			c.draw_line(Vector2(6,0),Vector2(35,0),STEEL,2)
		&"worker":
			c.draw_rect(Rect2(-8,-6,16,22),tint.darkened(0.25))
			c.draw_rect(Rect2(-5,1,10,15),Color("b89868"))
			c.draw_circle(Vector2(0,-12),8,Color("e0c5a0"))
			c.draw_circle(Vector2(0,-20),9,GOLD)
			c.draw_line(Vector2(-13,-16),Vector2(13,-16),GOLD,4)
			c.draw_line(Vector2(13,14),Vector2(18,-14),Color("b88d5e"),3)
			c.draw_line(Vector2(10,-13),Vector2(25,-13),STEEL,5)
		_:
			c.draw_rect(Rect2(-10,-7,20,24),tint.darkened(0.2))
			c.draw_circle(Vector2(0,-14),10,INK)
			c.draw_circle(Vector2(0,-16),8,STEEL)
			c.draw_line(Vector2(-6,-13),Vector2(6,-13),INK,3)
			_sword(c,Vector2(17,0),0.8)
			_shield(c,Vector2(-11,6),tint,0.8)

static func _sword(c: CanvasItem, p: Vector2, amount: float) -> void:
	c.draw_line(p+Vector2(0,8)*amount,p+Vector2(0,-26)*amount,STEEL,4*amount)
	c.draw_line(p+Vector2(-7,-1)*amount,p+Vector2(7,-1)*amount,GOLD,3*amount)

static func _shield(c: CanvasItem, p: Vector2, tint: Color, amount: float) -> void:
	var points := PackedVector2Array([Vector2(-9,-11),Vector2(9,-11),Vector2(8,6),Vector2(0,13),Vector2(-8,6)])
	for i in range(points.size()):
		points[i] = points[i]*amount+p
	c.draw_colored_polygon(points,INK)
	c.draw_line(p+Vector2(0,-7)*amount,p+Vector2(0,7)*amount,tint,8*amount)
	c.draw_circle(p,2*amount,GOLD)
