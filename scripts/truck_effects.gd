class_name TruckEffects
extends Node3D

const TRACK_LIFETIME := 5.0
const TRACK_FADE_TIME := 1.5

var truck: FireEngine
var dust: Array[Dictionary]=[]
var tracks: Array[Dictionary]=[]
var dust_pool: Array[MeshInstance3D]=[]
var track_pool: Array[MeshInstance3D]=[]
var last_contacts: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var clock:=0.0
var track_index:=0
var dust_index:=0
var skid_strength:=0.0

func _ready() -> void:
	var dust_material:=TownProps.effect_material(preload("res://shaders/soft_particle.gdshader"))
	var track_material:=TownProps.effect_material(preload("res://shaders/trail.gdshader"))
	for i in 48:
		var mesh:=MeshInstance3D.new()
		mesh.mesh=QuadMesh.new()
		mesh.material_override=TownProps.effect_instance(dust_material)
		mesh.visible=false
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		dust_pool.append(mesh)
	for i in 480:
		var mesh:=MeshInstance3D.new()
		mesh.mesh=PlaneMesh.new()
		mesh.material_override=TownProps.effect_instance(track_material)
		mesh.visible=false
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		track_pool.append(mesh)

func _physics_process(dt: float) -> void:
	if not is_instance_valid(truck) or not truck.is_physics_processing(): return
	clock+=dt
	var speed:=Vector3(truck.linear_velocity.x,0,truck.linear_velocity.z).length()
	var side_speed:=absf(truck.linear_velocity.dot(truck.global_basis.x))
	var turn_load:=absf(truck.steering)*speed/10.0
	var braking:=speed/18.0 if truck.enabled and Input.is_action_pressed("brake") else 0.0
	skid_strength=maxf(side_speed/7.0,maxf(turn_load,braking))
	var skidding:=truck.grounded and speed>3.0 and skid_strength>.25
	if not skidding: last_contacts=[Vector3.ZERO,Vector3.ZERO]
	if truck.grounded and speed>1.8 and clock>.06:
		clock=0
		for side in 2:
			var p:=truck.global_position+truck.global_basis*Vector3(-.94 if side==0 else .94,-.25,1.65)
			var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.6,p+Vector3.DOWN*1.6,9,[truck.get_rid()])
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit: continue
			p=hit.position+hit.normal*.022
			var previous:=last_contacts[side]
			last_contacts[side]=p if skidding else Vector3.ZERO
			if skidding and previous!=Vector3.ZERO and p.distance_to(previous)<3 and p.distance_to(previous)>.08:
				var mesh:=track_pool[track_index]
				track_index=(track_index+1)%track_pool.size()
				# Recycled slots have one owner, so older fades cannot hide newer marks.
				tracks=tracks.filter(func(t: Dictionary): return t.mesh!=mesh)
				mesh.visible=true
				mesh.position=(p+previous)*.5
				var up: Vector3=hit.normal
				var along: Vector3=(p-previous).slide(up).normalized()
				mesh.basis=Basis(up.cross(along).normalized(),up,along)
				if up.y>.99: mesh.position.y=maxf(p.y,previous.y)
				mesh.scale=Vector3(.14,1,p.distance_to(previous)*.54)
				var alpha:=clampf(skid_strength*.45,.15,.5)*.85
				tracks.append({"mesh":mesh,"life":TRACK_LIFETIME,"alpha":alpha})
			var cloud:=dust_pool[dust_index]
			dust_index=(dust_index+1)%dust_pool.size()
			dust=dust.filter(func(d: Dictionary): return d.mesh!=cloud)
			cloud.visible=true
			cloud.position=p+Vector3.UP*.2
			dust.append({"mesh":cloud,"life":.85,"velocity":Vector3(randf_range(-.4,.4),.45,randf_range(-.4,.4))-truck.linear_velocity*.05,"size":randf_range(.45,.8),"alpha":minf(.36,speed*.018)})
	elif not truck.grounded or speed<1.8:
		last_contacts=[Vector3.ZERO,Vector3.ZERO]
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
