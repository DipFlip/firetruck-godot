class_name SpeechFrame
extends Panel

var tail_tip := Vector2(270,224)
var phone_mode := false
var portrait_center:=Vector2(74,92)
var portrait_radius:=53.0
var divider_start:=148.0
const INK := Color("294754")
const FACE := Color("eff8fc")

func _draw() -> void:
	# A drawn balloon tail and enamel portrait bezel, fixed independently of
	# the moving artwork inside the portrait's circular shader mask.
	# Attach the notch to whichever edge faces the speaker after collision avoidance.
	var relative:=tail_tip-size*.5
	var normal:=Vector2.ZERO
	var base:=Vector2.ZERO
	if absf(relative.x)/size.x>absf(relative.y)/size.y:
		normal=Vector2(signf(relative.x),0)
		base=Vector2(size.x-3 if normal.x>0 else 3,clampf(tail_tip.y,38,size.y-38))
	else:
		normal=Vector2(0,signf(relative.y))
		base=Vector2(clampf(tail_tip.x,38,size.x-38),size.y-3 if normal.y>0 else 3)
	var tangent:=Vector2(-normal.y,normal.x)
	# The world anchor sets the direction; keep the notch short even when the
	# card has to move far away from its speaker to clear the vehicle.
	var tip:=base+(tail_tip-base).limit_length(48)
	if not Rect2(Vector2.ZERO,size).has_point(tail_tip):
		draw_colored_polygon(PackedVector2Array([base-tangent*18,tip,base+tangent*18]),INK)
		draw_colored_polygon(PackedVector2Array([base-tangent*11-normal*3,tip-(tip-base).normalized()*9,base+tangent*11-normal*3]),FACE)
	draw_circle(portrait_center,portrait_radius,INK)
	draw_circle(portrait_center,portrait_radius-4,Color("70b7c7"))
	draw_circle(portrait_center,portrait_radius-8,FACE)
	for x in [18.0,size.x-18]:
		draw_circle(Vector2(x,18),3,Color("80b9c8"))
		draw_circle(Vector2(x,size.y-18),3,Color("80b9c8"))
	draw_line(Vector2(divider_start,30 if portrait_radius<50 else 34),Vector2(size.x-28,30 if portrait_radius<50 else 34),Color("c6dfe8"),2,true)

static func draw_phone(canvas: CanvasItem, center: Vector2, scale_factor: float, clock: float, active: bool) -> void:
	var shape:=PackedVector2Array()
	for p in [Vector2(-18,-20),Vector2(-10,-23),Vector2(-3,-11),Vector2(-8,-6),Vector2(0,3),Vector2(7,8),Vector2(12,2),Vector2(23,8),Vector2(22,17),Vector2(16,22),Vector2(7,22),Vector2(-7,15),Vector2(-16,5),Vector2(-22,-7),Vector2(-22,-15)]:
		shape.append(center+p*scale_factor*.8)
	canvas.draw_colored_polygon(shape,INK)
	var tint:=Color("51b5cc")
	tint.a=.45+absf(sin(clock*3))*.55 if active else .4
	for radius in [16.0,24.0]:
		canvas.draw_arc(center+Vector2(2,-2)*scale_factor,radius*scale_factor,-PI*.5,0,16,tint,2*scale_factor,true)
