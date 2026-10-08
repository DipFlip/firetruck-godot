class_name TruckEffects
extends Node3D

const TRACK_LIFETIME := 5.0
const TRACK_FADE_TIME := 1.5
const TRACK_HALF_WIDTH := .13
# Front pair, then the rearmost pair. The middle axle shares the rear path.
const TRACK_WHEELS := [0,3,2,5]

var truck: FireEngine
var dust: Array[Dictionary]=[]
var tracks: Array[Dictionary]=[]
var dust_pool: Array[MeshInstance3D]=[]
var track_pool: Array[MeshInstance3D]=[]
var last_contacts: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var last_segments: Array[Dictionary]=[{},{},{},{}]
var wheel_skidding: Array[bool]=[false,false,false,false]
var wheel_strengths: Array[float]=[0.0,0.0,0.0,0.0]
var last_heading:=0.0
var heading_initialized:=false
var clock:=0.0
var track_index:=0
var dust_index:=0
var skid_strength:=0.0
var tire_sound_strength:=0.0
var tire_sound_hold:=0.0

func _ready() -> void:
	var dust_material:=TownProps.effect_material(preload("res://shaders/soft_particle.gdshader"))
	var track_material:=TownProps.effect_material(preload("res://shaders/trail.gdshader"))
	var dust_quad:=QuadMesh.new()
	var track_plane:=PlaneMesh.new()
	for i in 48:
		var mesh:=MeshInstance3D.new()
		mesh.mesh=dust_quad
		mesh.material_override=TownProps.effect_instance(dust_material)
		mesh.visible=false
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		dust_pool.append(mesh)
	for i in 480:
		var mesh:=MeshInstance3D.new()
		mesh.mesh=track_plane
		mesh.material_override=TownProps.effect_instance(track_material)
		mesh.visible=false
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		track_pool.append(mesh)

func _physics_process(dt: float) -> void:
	if not is_instance_valid(truck): return
	if not truck.is_physics_processing():
		_reset_contacts()
		heading_initialized=false
		tire_sound_strength=0
		return
	clock+=dt
	var velocity:=Vector3(truck.linear_velocity.x,0,truck.linear_velocity.z)
	var speed:=velocity.length()
	var yaw_rate:=clampf(angle_difference(last_heading,truck.heading)/maxf(dt,.001),-4,4) if heading_initialized else 0.0
	last_heading=truck.heading
	heading_initialized=true
	skid_strength=0
	for slot in TRACK_WHEELS.size():
		var wheel:=truck.wheel_steers[TRACK_WHEELS[slot]]
		var front:=slot<2
		var contact_velocity:=velocity+Vector3(0,yaw_rate,0).cross(wheel.global_position-truck.global_position)
		var lateral_speed:=absf(contact_velocity.dot(wheel.global_basis.x))
		# Steering alone is not a skid. Front tires follow their steering angle;
		# only appreciable sideways slip or hard braking leaves rubber behind.
		var slip:=clampf((lateral_speed-(2.5 if front else 1.8))/5.5,0,1)
		var braking:=clampf((speed-5)/10,0,1)*truck.brake_engagement*.75
		wheel_strengths[slot]=maxf(slip,braking)
		wheel_skidding[slot]=truck.grounded and not truck.freeze and speed>4 and wheel_strengths[slot]>(.15 if wheel_skidding[slot] else .24)
		if not wheel_skidding[slot]: _reset_contact(slot)
		skid_strength=maxf(skid_strength,wheel_strengths[slot] if wheel_skidding[slot] else 0.0)
	# Sound follows marks actually deposited on a surface, not steering input.
	tire_sound_hold=maxf(0,tire_sound_hold-dt)
	if tire_sound_hold<=0: tire_sound_strength=0
	if truck.grounded and not truck.freeze and speed>1.8 and clock>=.06:
		clock=0
		var deposited_strength:=0.0
		for slot in TRACK_WHEELS.size():
			if slot<2 and not wheel_skidding[slot]: continue
			var wheel:=truck.wheel_steers[TRACK_WHEELS[slot]]
			var p:=wheel.global_position
			var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.6,p+Vector3.DOWN*1.6,9,[truck.get_rid()])
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit:
				_reset_contact(slot)
				continue
			p=hit.position+hit.normal*.022
			if wheel_skidding[slot]:
				var previous:=last_contacts[slot]
				var distance:=p.distance_to(previous)
				if previous!=Vector3.ZERO and distance>.08 and distance<3:
					_lay_track(slot,previous,p,hit.normal,wheel_strengths[slot])
					deposited_strength=maxf(deposited_strength,.3+.7*wheel_strengths[slot])
				elif distance>=3: last_segments[slot]={}
				last_contacts[slot]=p
			# Dust stays on the rear axle; front marks do not double particles.
			if slot>=2: _add_dust(p,speed)
		if deposited_strength>0:
			tire_sound_strength=deposited_strength
			tire_sound_hold=.1
	elif not truck.grounded or truck.freeze or speed<1.8:
		_reset_contacts()
		tire_sound_strength=0
	for i in range(dust.size()-1,-1,-1):
		var d:=dust[i]
		d.life-=dt
		d.mesh.position+=d.velocity*dt
		d.mesh.scale=Vector3.ONE*d.size*(1+(.85-d.life)*1.8)
		TownProps.effect_opacity(d.mesh,maxf(0,d.life/.85)*d.alpha)
		if truck.camera: d.mesh.look_at(truck.camera.global_position)
		if d.life<=0: d.mesh.visible=false; dust.remove_at(i)
	for i in range(tracks.size()-1,-1,-1):
		var t:=tracks[i]
		t.life-=dt
		TownProps.effect_opacity(t.mesh,t.alpha*minf(1,maxf(0,t.life/TRACK_FADE_TIME)))
		if t.life<=0: t.mesh.visible=false; tracks.remove_at(i)

func _reset_contact(slot: int) -> void:
	last_contacts[slot]=Vector3.ZERO
	last_segments[slot]={}

func _reset_contacts() -> void:
	for slot in TRACK_WHEELS.size():
		_reset_contact(slot)
		wheel_skidding[slot]=false

func _lay_track(slot: int, start: Vector3, end: Vector3, up: Vector3, strength: float) -> void:
	var along: Vector3=(end-start).slide(up).normalized()
	var right:=up.cross(along).normalized()*TRACK_HALF_WIDTH
	var start_right:=right
	var alpha:=lerpf(.09,.28,strength)
	var start_alpha:=alpha
	var previous:=last_segments[slot]
	if not previous.is_empty() and tracks.has(previous) and previous.direction.dot(along)>.1:
		# Both segments meet at the same miter. No transparent rectangles
		# overlap, so joints stay the same shade on straights and corners.
		var bisector: Vector3=(previous.direction+along).normalized()
		var joint_right:=up.cross(bisector).normalized()
		start_right=joint_right*TRACK_HALF_WIDTH/maxf(.65,joint_right.dot(right.normalized()))
		previous.end_left=start-start_right
		previous.end_right=start+start_right
		_update_track_shape(previous)
		start_alpha=previous.end_alpha
	var mesh:=track_pool[track_index]
	track_index=(track_index+1)%track_pool.size()
	# Recycled slots have one owner, so older fades cannot hide newer marks.
	tracks=tracks.filter(func(t: Dictionary): return t.mesh!=mesh)
	mesh.visible=true
	mesh.position=(start+end)*.5
	mesh.basis=Basis.IDENTITY
	var track: Dictionary={"mesh":mesh,"life":TRACK_LIFETIME,"alpha":alpha,"wheel":slot,"direction":along,"start_left":start-start_right,"start_right":start+start_right,"end_left":end-right,"end_right":end+right,"start_alpha":start_alpha,"end_alpha":alpha}
	_update_track_shape(track)
	tracks.append(track)
	last_segments[slot]=track

func _track_parameter(mesh: MeshInstance3D, parameter: StringName, value: Variant) -> void:
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		(mesh.material_override as ShaderMaterial).set_shader_parameter(parameter,value)
	else: mesh.set_instance_shader_parameter(parameter,value)

func _update_track_shape(track: Dictionary) -> void:
	var mesh: MeshInstance3D=track.mesh
	var bounds:=AABB(track.start_left-mesh.position,Vector3.ZERO)
	for key in ["start_left","start_right","end_left","end_right"]:
		var local: Vector3=track[key]-mesh.position
		_track_parameter(mesh,key,local)
		bounds=bounds.expand(local)
	_track_parameter(mesh,"end_opacity",Vector2(track.start_alpha/track.alpha,1))
	mesh.custom_aabb=bounds.grow(.03)

func _add_dust(p: Vector3, speed: float) -> void:
	var cloud:=dust_pool[dust_index]
	dust_index=(dust_index+1)%dust_pool.size()
	dust=dust.filter(func(d: Dictionary): return d.mesh!=cloud)
	cloud.visible=true
	cloud.position=p+Vector3.UP*.2
	dust.append({"mesh":cloud,"life":.85,"velocity":Vector3(randf_range(-.4,.4),.45,randf_range(-.4,.4))-truck.linear_velocity*.05,"size":randf_range(.45,.8),"alpha":minf(.36,speed*.018)})
