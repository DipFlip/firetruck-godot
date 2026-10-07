class_name TownSidewalks
extends Node3D

# Pavements wrap each block with rounded corners and a low curb. They stop at
# junctions, where the road surface fills the corner radius and zebra
# crossings continue the pavement lines across the street.
const LINES:=[-79.5,-36.0,0.0,36.0,79.5] # Outer entries sit inside the toy-block wall.
const ROAD_HALF:=4.0
const WIDTH:=2.0
const RADIUS:=3.0
const HEIGHT:=.10
const ROAD_TOP:=.055
var road_material: Material
var top_tool:=SurfaceTool.new()
var curb_tool:=SurfaceTool.new()
var fill_tool:=SurfaceTool.new()
var collision_faces:=PackedVector3Array()

func build() -> void:
	name="Sidewalks"
	for tool in [top_tool,curb_tool,fill_tool]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in LINES.size()-1:
		for j in LINES.size()-1:
			var x0: float=LINES[i]+(ROAD_HALF if i>0 else 0.0)
			var x1: float=LINES[i+1]-(ROAD_HALF if i<LINES.size()-2 else 0.0)
			var z0: float=LINES[j]+(ROAD_HALF if j>0 else 0.0)
			var z1: float=LINES[j+1]-(ROAD_HALF if j<LINES.size()-2 else 0.0)
			# North, east, south, west: does that side face a street?
			_block(Rect2(x0,z0,x1-x0,z1-z0),[j>0,i<LINES.size()-2,j<LINES.size()-2,i>0])
	_add_mesh(top_tool,TownProps.material(Color("d5cbb3")))
	_add_mesh(curb_tool,TownProps.material(Color("bdb39e")))
	_add_mesh(fill_tool,road_material)
	var body:=StaticBody3D.new()
	body.name="PavementSurface"
	# Query-only, like the other drive surfaces: tires read it, the chassis does not.
	body.collision_layer=8
	body.collision_mask=0
	add_child(body)
	var shape:=CollisionShape3D.new()
	var faces:=ConcavePolygonShape3D.new()
	faces.set_faces(collision_faces)
	shape.shape=faces
	body.add_child(shape)
	_crossings()

func _add_mesh(tool: SurfaceTool, paint: Material) -> void:
	tool.index()
	var art:=MeshInstance3D.new()
	art.mesh=tool.commit()
	art.material_override=paint
	add_child(art)

func _block(r: Rect2, street: Array) -> void:
	var corners:=[r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	var inward:=[Vector2(0,1),Vector2(-1,0),Vector2(0,-1),Vector2(1,0)]
	for side in 4:
		if not street[side]: continue
		var a: Vector2=corners[side]
		var b: Vector2=corners[(side+1)%4]
		var along:=(b-a).normalized()
		# Rounded only where two streets meet; otherwise run into the wall.
		if street[(side+3)%4]: a+=along*RADIUS
		if street[(side+1)%4]: b-=along*RADIUS
		for run in _split_at_track(a,b): _strip([run[0],run[1]],[inward[side],inward[side]])
		if street[(side+1)%4]: _corner(corners[(side+1)%4],inward[side],inward[(side+1)%4])

# Leave the railway crossing clear of pavement.
func _split_at_track(a: Vector2, b: Vector2) -> Array:
	var track: float=NorthlineRailway.TRACK_Z
	if absf(a.x-b.x)>.01 or (a.y-track)*(b.y-track)>0: return [[a,b]]
	var gap:=3.6*signf(b.y-a.y)
	return [[a,Vector2(a.x,track-gap)],[Vector2(b.x,track+gap),b]]

func _corner(corner: Vector2, in_a: Vector2, in_b: Vector2) -> void:
	var centre:=corner+(in_a+in_b)*RADIUS
	var points: Array[Vector2]=[]
	var normals: Array[Vector2]=[]
	var start:=(-in_a).angle()
	var finish:=(-in_b).angle()
	var sweep:=angle_difference(start,finish)
	for k in 13:
		var direction:=Vector2.from_angle(start+sweep*k/12.0)
		points.append(centre+direction*RADIUS)
		normals.append(-direction)
	_strip(points,normals)
	# Asphalt fills the junction corner outside the curb.
	for k in 12:
		_tri(fill_tool,_v(corner,ROAD_TOP),_v(points[k],ROAD_TOP),_v(points[k+1],ROAD_TOP),Vector3.UP,true)

# Extrude a pavement band inward from the street-side edge.
func _strip(points: Array, normals: Array) -> void:
	for k in points.size()-1:
		var o0: Vector2=points[k]
		var o1: Vector2=points[k+1]
		var i0: Vector2=o0+normals[k]*WIDTH
		var i1: Vector2=o1+normals[k+1]*WIDTH
		_quad(top_tool,_v(o0,HEIGHT),_v(o1,HEIGHT),_v(i1,HEIGHT),_v(i0,HEIGHT),Vector3.UP,true)
		var out: Vector2=-(normals[k]+normals[k+1]).normalized()
		var outward:=Vector3(out.x,0,out.y)
		_quad(curb_tool,_v(o0,0),_v(o1,0),_v(o1,HEIGHT),_v(o0,HEIGHT),outward,true)
		_quad(curb_tool,_v(i0,0),_v(i1,0),_v(i1,HEIGHT),_v(i0,HEIGHT),-outward,false)

func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x,y,p.y)

func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, collide: bool) -> void:
	_tri(tool,a,b,c,normal,collide)
	_tri(tool,a,c,d,normal,collide)

func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, collide: bool) -> void:
	# Wind every face towards its normal, whichever way the outline runs.
	var points:=[a,b,c] if (b-a).cross(c-a).dot(normal)<0 else [a,c,b]
	for p in points:
		tool.set_normal(normal)
		tool.add_vertex(p)
	if collide: collision_faces.append_array(PackedVector3Array(points))

# Zebra crossings on every arm of each junction. They sit in line with the
# pavement bands, just before the corner curves begin, as on real streets.
func _crossings() -> void:
	var paint:=SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset:=ROAD_HALF+RADIUS+WIDTH*.5
	for cx in [-36.0,0.0,36.0]:
		for cz in [-36.0,0.0,36.0]:
			for k in 6:
				var across:=-3.25+k*1.3
				for side in [-1,1]:
					_stripe(paint,Vector2(cx+across,cz+side*offset),Vector2(.32,WIDTH*.5))
					_stripe(paint,Vector2(cx+side*offset,cz+across),Vector2(WIDTH*.5,.32))
	_add_mesh(paint,TownProps.material(Color("f2e5c8")))

func _stripe(tool: SurfaceTool, centre: Vector2, half: Vector2) -> void:
	var y:=ROAD_TOP+.012
	_quad(tool,_v(centre-half,y),_v(centre+Vector2(half.x,-half.y),y),_v(centre+half,y),_v(centre+Vector2(-half.x,half.y),y),Vector3.UP,false)
