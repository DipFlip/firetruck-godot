class_name SpeechFrame
extends Panel

static func departure_blend(anchor: Vector2, view: Vector2) -> float:
	var edge_distance:=minf(minf(anchor.x,view.x-anchor.x),minf(anchor.y,view.y-anchor.y))
	return 1-smoothstep(0,minf(180,minf(view.x,view.y)*.25),edge_distance)

var tail_tip := Vector2(270,224)
var phone_mode := false
var portrait_center:=Vector2(74,92)
var portrait_radius:=53.0
var divider_start:=148.0
const INK := Color("294754")
const FACE := Color("eff8fc")
const PHONE:=preload("res://assets/ui/phone.svg")

func _draw() -> void:
	var path:=outline()
	var shadow:=PackedVector2Array()
	for vertex in path: shadow.append(vertex+Vector2(0,5))
	draw_colored_polygon(shadow,Color(.10,.20,.27,.25))
	draw_colored_polygon(path,FACE)
	path.append(path[0])
	draw_polyline(path,INK,3,true)
	# One smooth, fixed-colour rim; only the portrait artwork moves inside it.
	draw_circle(portrait_center,portrait_radius,INK,true,-1,true)

# A single silhouette avoids the painted-over rectangular border at the tail
# base. Both joins leave/rejoin the edge tangentially, with rounded shoulders.
func outline() -> PackedVector2Array:
	var edge:=-1
	var relative:=tail_tip-size*.5
	if not Rect2(Vector2.ZERO,size).has_point(tail_tip):
		edge=(1 if relative.x>0 else 3) if absf(relative.x)/size.x>absf(relative.y)/size.y else (2 if relative.y>0 else 0)
	var lo:=Vector2.ONE*1.5
	var hi:=size-lo
	var path:=PackedVector2Array()
	var top_left:=lo+Vector2(26,0)
	_append_edge(path,top_left,Vector2(hi.x-16,lo.y),Vector2.UP,edge==0)
	_append_corner(path,Vector2(hi.x-16,lo.y),Vector2(hi.x,lo.y),Vector2(hi.x,lo.y+16))
	_append_edge(path,Vector2(hi.x,lo.y+16),Vector2(hi.x,hi.y-26),Vector2.RIGHT,edge==1)
	_append_corner(path,Vector2(hi.x,hi.y-26),hi,Vector2(hi.x-26,hi.y))
	_append_edge(path,Vector2(hi.x-26,hi.y),Vector2(lo.x+16,hi.y),Vector2.DOWN,edge==2)
	_append_corner(path,Vector2(lo.x+16,hi.y),Vector2(lo.x,hi.y),Vector2(lo.x,hi.y-16))
	_append_edge(path,Vector2(lo.x,hi.y-16),Vector2(lo.x,lo.y+26),Vector2.LEFT,edge==3)
	_append_corner(path,Vector2(lo.x,lo.y+26),lo,top_left)
	if path[-1].is_equal_approx(path[0]): path.resize(path.size()-1)
	return path

func _append_edge(path: PackedVector2Array, start: Vector2, finish: Vector2, normal: Vector2, tail: bool) -> void:
	if path.is_empty() or not path[-1].is_equal_approx(start): path.append(start)
	if tail and start.distance_to(finish)>46:
		var tangent: Vector2=(finish-start).normalized()
		var along:=clampf((tail_tip-start).dot(tangent),22,start.distance_to(finish)-22)
		var base:=start+tangent*along
		var delta:=tail_tip-base
		var depth:=minf(36,delta.dot(normal))
		if depth<2:
			path.append(finish)
			return
		var left:=base-tangent*20
		var right:=base+tangent*20
		# A shallow tail must not bend back through the balloon's edge while
		# the speaker crosses it. Keep both joins outside the silhouette.
		var tip:=base+(normal*depth+tangent*clampf(delta.dot(tangent),-10,10)).limit_length(36)
		var bend:=minf(14,depth*.45)
		path.append(left)
		_append_curve(path,left,left+tangent*12,tip-normal*bend-tangent*3,tip-tangent*.8)
		_append_curve(path,tip-tangent*.8,tip+normal*1.2,tip+normal*1.2,tip+tangent*.8)
		_append_curve(path,tip+tangent*.8,tip-normal*bend+tangent*3,right-tangent*12,right)
	path.append(finish)

func _append_corner(path: PackedVector2Array, start: Vector2, corner: Vector2, finish: Vector2) -> void:
	_append_curve(path,start,start.lerp(corner,.5523),finish.lerp(corner,.5523),finish,10)

func _append_curve(path: PackedVector2Array, start: Vector2, a: Vector2, b: Vector2, finish: Vector2, steps: int=16) -> void:
	for i in range(1,steps+1): path.append(start.bezier_interpolate(a,b,finish,float(i)/steps))

static func draw_phone(canvas: CanvasItem, center: Vector2, scale_factor: float, clock: float, active: bool) -> void:
	canvas.draw_texture_rect(PHONE,Rect2(center-Vector2.ONE*20*scale_factor,Vector2.ONE*40*scale_factor),false)
	var tint:=Color("51b5cc")
	tint.a=.45+absf(sin(clock*3))*.55 if active else .4
	for radius in [16.0,24.0]:
		canvas.draw_arc(center+Vector2(2,-2)*scale_factor,radius*scale_factor,-PI*.5,0,48,tint,2*scale_factor,true)
