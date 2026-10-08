class_name RaceCourse
extends RefCounted

const HALF_WIDTH:=6.5
const STEPS:=32
const POND_CENTRE:=Vector2(-29,40)
const POND_RADIUS:=Vector2(13,10)
const POND_DEPTH:=2.4
const CONTROLS: Array[Vector3]=[
	Vector3(-36,0,-54),Vector3(0,0,-54),Vector3(36,0,-54),Vector3(60,0,-46),
	Vector3(63,0,-27),Vector3(46,0,-13),Vector3(27,0,-17),Vector3(12,0,-9),
	Vector3(0,0,4),Vector3(-18,0,19),Vector3(-42,0,23),Vector3(-60,0,34),
	Vector3(-60,0,53),Vector3(-37,0,62),Vector3(-13,0,59),Vector3(5,0,43),
	Vector3(32,0,44),Vector3(40,0,27),Vector3(25,0,14),Vector3(0,7,4),
	Vector3(-18,3.5,-13),Vector3(-31,0,-26),Vector3(-50,0,-35),Vector3(-50,0,-49)]
const GATE_INDICES: Array[int]=[1,5,12,19]
static var samples: PackedVector3Array
static var distances: PackedFloat32Array

static func points() -> PackedVector3Array:
	if not samples.is_empty(): return samples
	var length_so_far:=0.0
	for i in CONTROLS.size():
		var a:=CONTROLS[posmod(i-1,CONTROLS.size())]
		var b:=CONTROLS[i]
		var c:=CONTROLS[(i+1)%CONTROLS.size()]
		var d:=CONTROLS[(i+2)%CONTROLS.size()]
		a.y=0; b.y=0; c.y=0; d.y=0
		# A C2-continuous B-spline rounds the toy track's corners. Its broad
		# inner offsets cannot fold back across the road at the bridge turn.
		for step in STEPS:
			var t:=float(step)/STEPS
			var p: Vector3=(pow(1-t,3)*a+(3*t*t*t-6*t*t+4)*b+(-3*t*t*t+3*t*t+3*t+1)*c+t*t*t*d)/6
			p.y=0
			if not samples.is_empty(): length_so_far+=samples[-1].distance_to(p)
			samples.append(p)
			distances.append(length_so_far)
	# The bridge's vertical profile is a smooth ease measured along the road,
	# independent of the corner knots. Both approaches and the crest are level.
	var begin:=distances[16*STEPS]
	var crest:=distances[19*STEPS]
	var end:=distances[22*STEPS]
	for i in samples.size():
		var distance:=distances[i]
		if distance>=begin and distance<=end:
			var t:=(distance-begin)/(crest-begin) if distance<=crest else (end-distance)/(end-crest)
			samples[i].y=7*smoothstep(0,1,t)
	samples.append(samples[0])
	distances.append(length_so_far+samples[-2].distance_to(samples[0]))
	return samples

static func gate_position(index: int) -> Vector3:
	return points()[GATE_INDICES[index]*STEPS]

static func gate_direction(index: int) -> Vector2:
	var path:=points()
	var i:=GATE_INDICES[index]*STEPS
	var tangent:=path[i+1]-path[i-1]
	return Vector2(tangent.x,tangent.z).normalized()

static func distance_to_track(point: Vector2) -> float:
	var path:=points()
	var closest:=INF
	for i in path.size()-1:
		var a:=Vector2(path[i].x,path[i].z)
		var b:=Vector2(path[i+1].x,path[i+1].z)
		var t:=clampf((point-a).dot(b-a)/maxf(.001,a.distance_squared_to(b)),0,1)
		closest=minf(closest,point.distance_squared_to(a.lerp(b,t)))
	return sqrt(closest)

static func ribbon(inner: float, outer: float, lift: float, paint: Material) -> MeshInstance3D:
	var path:=points()
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for i in path.size():
		var before:=path[maxi(0,i-1)] if i>0 else path[-2]
		var after:=path[mini(path.size()-1,i+1)] if i<path.size()-1 else path[1]
		var tangent: Vector3=(after-before).normalized()
		var side:=Vector3(-tangent.z,0,tangent.x).normalized()
		for width in [inner,outer]:
			vertices.append(path[i]+side*width+Vector3.UP*(lift+.055))
			normals.append(side.cross(tangent).normalized())
			uvs.append(Vector2(distances[i],width))
		if i<path.size()-1:
			var n:=i*2
			indices.append_array([n,n+2,n+1,n+1,n+2,n+3])
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var result:=MeshInstance3D.new()
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.mesh=mesh
	result.material_override=paint
	return result

# A broad, C1-continuous bowl: the rim and central floor meet the slopes
# without a step. The same shape supplies the terrain mesh and truck support.
static func pond_surface(point: Vector2) -> Dictionary:
	var local: Vector2=(point-POND_CENTRE)/POND_RADIUS
	var radius:=local.length()
	var t:=clampf((radius-.32)/.68,0,1)
	var height:=.03-POND_DEPTH*(1-smoothstep(0,1,t))
	var derivative:=POND_DEPTH*6*t*(1-t)/.68 if radius>.32 and radius<1 else 0.0
	var gradient:=local/radius/POND_RADIUS*derivative if radius>.0001 else Vector2.ZERO
	return {"height":height,"gradient":gradient,"normal":Vector3(-gradient.x,1,-gradient.y).normalized()}

# The drive surface is sampled independently of the render triangles and curbs.
# Upper and lower branches are selected by height, so an underpass never snaps
# a truck onto the bridge above it. The same profile drives the tires and body.
static func surface_at(at: Vector3) -> Dictionary:
	var path:=points()
	var point:=Vector2(at.x,at.z)
	var closest_flat:=INF
	var closest_bridge:=INF
	var bridge_height:=0.0
	var bridge_gradient:=Vector2.ZERO
	for i in path.size()-1:
		var a:=Vector2(path[i].x,path[i].z)
		var delta:=Vector2(path[i+1].x,path[i+1].z)-a
		var t:=clampf((point-a).dot(delta)/maxf(.00001,delta.length_squared()),0,1)
		var d:=point.distance_squared_to(a+delta*t)
		if i>=16*STEPS and i<22*STEPS:
			if d>=closest_bridge: continue
			closest_bridge=d
			bridge_height=lerpf(path[i].y,path[i+1].y,t)+.055
			bridge_gradient=delta*(path[i+1].y-path[i].y)/maxf(.00001,delta.length_squared())
		else: closest_flat=minf(closest_flat,d)
	var width_squared:=HALF_WIDTH*HALF_WIDTH
	var terrain:=pond_surface(point)
	var height: float=.055 if closest_flat<width_squared else terrain.height
	var gradient: Vector2=Vector2.ZERO if closest_flat<width_squared else terrain.gradient
	# Prefer the upper layer when already riding it, regardless of whether
	# the lower crossing happens to be closer in the horizontal projection.
	# Timber shoulders share the smooth support, without sampling the rails.
	if closest_bridge<8.0*8.0 and bridge_height<=at.y-.45:
		height=bridge_height
		gradient=bridge_gradient
	return {"height":height,"normal":Vector3(-gradient.x,1,-gradient.y).normalized(),"gradient":gradient}
