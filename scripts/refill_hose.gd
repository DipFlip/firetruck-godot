class_name RefillHose
extends Node3D

const REAR_SOCKET:=Vector3(0,.45,2.22)
const EXTEND_TIME:=.7
const RETRACT_TIME:=.55
var game: Node3D
var active:=false
var hydrant: BreakableProp
var rest: Array[Transform3D]=[]
var segments: Array[MeshInstance3D]=[]
var flow_drops: Array[MeshInstance3D]=[]
var couplings: Array[MeshInstance3D]=[]
var points:=PackedVector3Array()
var time:=0.0
var extension:=0.0
var outlet:=Vector3.ZERO
var tip:=Vector3.ZERO

func _ready() -> void:
	name="RefillHose"
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=1
	cylinder.bottom_radius=1
	cylinder.height=1
	cylinder.radial_segments=10
	for i in 16:
		var mesh:=MeshInstance3D.new()
		mesh.mesh=cylinder
		var material:=ShaderMaterial.new()
		material.shader=preload("res://shaders/refill_hose.gdshader")
		material.set_shader_parameter("rubber",Color("365868"))
		material.set_shader_parameter("water",Color("a9e8eb"))
		mesh.material_override=material
		add_child(mesh)
		segments.append(mesh)
	for i in 6:
		var drop:=TownProps.ball(self,Vector3.ZERO,Vector3.ONE*.16,FireEngine.WATER_COLORS[2+i%3])
		drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flow_drops.append(drop)
	for i in 2: couplings.append(TownProps.cylinder(self,Vector3.ZERO,.10,.18,Color("c7b486")))
	points.resize(17)
	visible=false

func update(source: BreakableProp, dt: float) -> void:
	if not is_instance_valid(source) or source.loose: source=null
	if hydrant==null and source!=null:
		hydrant=source
	var connecting:=source!=null and source==hydrant
	if connecting and rest.is_empty():
		for mesh in hydrant.meshes: rest.append(mesh.transform)
	if not connecting:
		_restore_hydrant()
		rest.clear()
	extension=move_toward(extension,1.0 if connecting else 0.0,dt/(EXTEND_TIME if connecting else RETRACT_TIME))
	active=connecting and extension>=1.0
	visible=extension>0.0
	if not visible:
		hydrant=null
		return
	time+=dt
	var pulse:=1+.05*(.5+.5*sin(time*TAU*1.6)) if active else 1.0
	for i in rest.size():
		hydrant.meshes[i].transform=Transform3D(rest[i].basis.scaled(Vector3.ONE*pulse),rest[i].origin*pulse)
	var truck_pose: Transform3D=game.truck.get_global_transform_interpolated()
	var end: Vector3=truck_pose*(game.truck.visual.transform*game.truck.body_point(REAR_SOCKET))
	if connecting:
		var side:=1.0 if hydrant.to_local(end).x>=0 else -1.0
		outlet=hydrant.global_transform*(Vector3(side*.47,.65,0)*pulse)
	# Keep the last outlet when disconnected, including a toppled hydrant.
	# Only the truck end follows the moving chassis while the hose reels in.
	var start:=outlet
	# Keep the hose outside the body, then loop behind the rear bumper.
	# Two curves avoid cutting through the truck when a hydrant is alongside it.
	var local_start:=truck_pose.affine_inverse()*start
	var truck_side:=1.0 if local_start.x>=0 else -1.0
	var corner: Vector3=truck_pose*Vector3(truck_side*1.9,-truck_pose.origin.y+.10,3.2)
	var control_a: Vector3=truck_pose*Vector3(truck_side*maxf(absf(local_start.x),1.9),-truck_pose.origin.y+.10,local_start.z)
	var control_b: Vector3=corner-truck_pose.basis.z*.7
	var rear_a: Vector3=corner+truck_pose.basis.z*.55
	var rear_b: Vector3=end+truck_pose.basis.z*1.05+Vector3.DOWN*.4
	for i in points.size():
		var t:=float(i)/10.0 if i<=10 else float(i-10)/6.0
		var u:=1-t
		var p: Vector3
		if i<=10:
			p=start*u*u*u+control_a*3*u*u*t+control_b*3*u*t*t+corner*t*t*t
		else:
			p=corner*u*u*u+rear_a*3*u*u*t+rear_b*3*u*t*t+end*t*t*t
		var excluded: Array[RID]=[game.truck.get_rid()]
		if is_instance_valid(hydrant): excluded.append(hydrant.get_rid())
		var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP,p+Vector3.DOWN*2,9,excluded)
		var road:=get_world_3d().direct_space_state.intersect_ray(query)
		if road and road.normal.y>.5: p.y=maxf(p.y,road.position.y+.07)
		points[i]=p
	var total_length:=0.0
	for i in segments.size(): total_length+=points[i].distance_to(points[i+1])
	# Reveal actual tube length from the rear socket, never scale the full hose.
	var cut:=total_length*(1-smoothstep(0.0,1.0,extension))
	var offset:=0.0
	var found_tip:=false
	for i in segments.size():
		var along:=points[i+1]-points[i]
		var length:=maxf(.001,along.length())
		segments[i].visible=offset+length>cut
		var clipped_start:=points[i].lerp(points[i+1],clampf((cut-offset)/length,0,1))
		var shown_length:=maxf(.001,clipped_start.distance_to(points[i+1]))
		if segments[i].visible and not found_tip:
			tip=clipped_start
			found_tip=true
		segments[i].transform=Transform3D(_basis(along)*Basis.from_scale(Vector3(.065,shown_length,.065)),(clipped_start+points[i+1])*.5)
		var material: ShaderMaterial=segments[i].material_override
		material.set_shader_parameter("path_offset",offset)
		material.set_shader_parameter("path_length",length)
		material.set_shader_parameter("flow_time",time)
		material.set_shader_parameter("flow_strength",1.0 if active else 0.0)
		offset+=length
	for i in flow_drops.size():
		flow_drops[i].visible=active
		var t:=fmod(time*.55+float(i)/flow_drops.size(),1.0)*segments.size()
		var index:=mini(int(t),segments.size()-1)
		flow_drops[i].position=points[index].lerp(points[index+1],t-index)
		flow_drops[i].basis=_basis(points[index+1]-points[index])*Basis.from_scale(Vector3(.16,.23,.16))
	couplings[0].transform=Transform3D(_basis(tip-end),tip)
	couplings[1].transform=Transform3D(_basis(points[16]-points[15]),end)

func _basis(along: Vector3) -> Basis:
	if along.length_squared()<.000001: return Basis.IDENTITY
	var y:=along.normalized()
	var reference:=Vector3.RIGHT if absf(y.dot(Vector3.UP))>.98 else Vector3.UP
	var x:=reference.cross(y).normalized()
	return Basis(x,y,x.cross(y).normalized())

func _restore_hydrant() -> void:
	if not is_instance_valid(hydrant): return
	for i in rest.size():
		if is_instance_valid(hydrant.meshes[i]): hydrant.meshes[i].transform=rest[i]
