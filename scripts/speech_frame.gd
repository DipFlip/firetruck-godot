class_name SpeechFrame
extends Panel

var tail_tip := Vector2(270,224)
var phone_mode := false
const INK := Color("294754")
const FACE := Color("eff8fc")

func _draw() -> void:
	# A drawn balloon tail and enamel portrait bezel, fixed independently of
	# the moving artwork inside the portrait's circular shader mask.
	var base_x:=clampf(tail_tip.x,52,size.x-52)
	var base:=Vector2(base_x,size.y-3)
	draw_colored_polygon(PackedVector2Array([base+Vector2(-18,0),tail_tip,base+Vector2(18,0)]),INK)
	draw_colored_polygon(PackedVector2Array([base+Vector2(-11,-3),tail_tip+Vector2(0,-9),base+Vector2(11,-3)]),FACE)
	draw_circle(Vector2(74,92),53,INK)
	draw_circle(Vector2(74,92),49,Color("70b7c7"))
	draw_circle(Vector2(74,92),45,FACE)
	for x in [18.0,size.x-18]:
		draw_circle(Vector2(x,18),3,Color("80b9c8"))
		draw_circle(Vector2(x,size.y-18),3,Color("80b9c8"))
	draw_line(Vector2(148,34),Vector2(size.x-28,34),Color("c6dfe8"),2,true)

static func draw_phone(canvas: CanvasItem, center: Vector2, scale_factor: float, clock: float, active: bool) -> void:
	var shape:=PackedVector2Array()
	for p in [Vector2(-18,-20),Vector2(-10,-23),Vector2(-3,-11),Vector2(-8,-6),Vector2(0,3),Vector2(7,8),Vector2(12,2),Vector2(23,8),Vector2(22,17),Vector2(16,22),Vector2(7,22),Vector2(-7,15),Vector2(-16,5),Vector2(-22,-7),Vector2(-22,-15)]:
		shape.append(center+p*scale_factor*.8)
	canvas.draw_colored_polygon(shape,INK)
	var tint:=Color("51b5cc")
	tint.a=.45+absf(sin(clock*3))*.55 if active else .4
	for radius in [16.0,24.0]:
		canvas.draw_arc(center+Vector2(2,-2)*scale_factor,radius*scale_factor,-PI*.5,0,16,tint,2*scale_factor,true)
