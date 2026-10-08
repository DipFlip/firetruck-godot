class_name SpeechFrame
extends Panel

var tail_tip := Vector2(270,224)
var phone_mode := false
var portrait_center:=Vector2(74,92)
var portrait_radius:=53.0
var divider_start:=148.0
const INK := Color("294754")
const FACE := Color("eff8fc")
const PHONE:=preload("res://assets/ui/phone.svg")

func _draw() -> void:
	var relative:=tail_tip-size*.5
	var normal:=Vector2.ZERO
	var base:=Vector2.ZERO
	if absf(relative.x)/size.x>absf(relative.y)/size.y:
		normal=Vector2(signf(relative.x),0)
		base=Vector2(size.x-2 if normal.x>0 else 2,clampf(tail_tip.y,28,size.y-28))
	else:
		normal=Vector2(0,signf(relative.y))
		base=Vector2(clampf(tail_tip.x,28,size.x-28),size.y-2 if normal.y>0 else 2)
	var tangent:=Vector2(-normal.y,normal.x)
	var tip:=base+(tail_tip-base).limit_length(36)
	if not Rect2(Vector2.ZERO,size).has_point(tail_tip):
		var left:=base-tangent*14-normal*2
		var right:=base+tangent*14-normal*2
		var direction: Vector2=(tip-base).normalized()
		var perpendicular:=Vector2(-direction.y,direction.x)
		var curve:=PackedVector2Array()
		for i in 17:
			curve.append(left.bezier_interpolate(left+direction*12,tip-direction*8-perpendicular*3,tip-perpendicular*.8,float(i)/16))
		for i in range(1,17):
			curve.append((tip-perpendicular*.8).bezier_interpolate(tip+direction*1.2,tip+direction*1.2,tip+perpendicular*.8,float(i)/16))
		for i in range(1,17):
			curve.append((tip+perpendicular*.8).bezier_interpolate(tip-direction*8+perpendicular*3,right+direction*12,right,float(i)/16))
		draw_colored_polygon(curve,FACE)
		draw_polyline(curve,INK,3,true)
		draw_line(left+tangent,right-tangent,FACE,5,true)
	# One smooth, fixed-colour rim; only the portrait artwork moves inside it.
	draw_circle(portrait_center,portrait_radius,INK,true,-1,true)

static func draw_phone(canvas: CanvasItem, center: Vector2, scale_factor: float, clock: float, active: bool) -> void:
	canvas.draw_texture_rect(PHONE,Rect2(center-Vector2.ONE*20*scale_factor,Vector2.ONE*40*scale_factor),false)
	var tint:=Color("51b5cc")
	tint.a=.45+absf(sin(clock*3))*.55 if active else .4
	for radius in [16.0,24.0]:
		canvas.draw_arc(center+Vector2(2,-2)*scale_factor,radius*scale_factor,-PI*.5,0,48,tint,2*scale_factor,true)
