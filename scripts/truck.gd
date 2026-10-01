class_name FireEngine
extends RigidBody3D

signal bump(strength: float)

signal water_hit(point: Vector3, amount: float)

var hit_receiver: Callable
var aim_assist: Callable
var assisted := false
const WATER_SPEED := 22.0 # Nozzle speed relative to the moving truck.
const WATER_GRAVITY := 26.0
const WATER_LIFETIME := 1.15
const AIM_RANGE := 15.0
const WATER_COLORS := [Color("83cada"),Color("9bdce7"),Color("b1e6ed"),Color("cbf0f2"),Color("e0f5f4")]
var spray_pulse := 0
var jump_blocked_until_release := false
var pointer_spray_blocked := false
var touch_drive:=Vector2.ZERO
var touch_aim:=Vector2.ZERO

@export var acceleration := 26.25
@export var top_speed := 16.875
@export var recoil_acceleration := 17.0
@export var tank_capacity := 100.0
@export var full_jump_speed := 9.67
var water := 100.0
var heading := 0.0
var camera: Camera3D
var visual: Node3D
var body_materials: Array[ShaderMaterial]=[]
var body_squash:=1.0
var wheel_rig: Node3D
var cannon: Node3D
var wheels: Array[Node3D] = []
var wheel_steers: Array[Node3D] = []
var wheel_rest_positions: Array[Vector3] = []
var front_axles: Array[bool] = []
var steering := 0.0
var previous_velocity := Vector3.ZERO
var suspension_velocity := 0.0
var suspension_offset := 0.0
var suspension_grounded := false
var jump_pitch := 0.0
var jump_pitch_velocity := 0.0
var drive_pitch := 0.0
var ground_distance := INF
var ground_normal := Vector3.UP
var support_height := .8
const CANNON_MOUNT := Vector3(0,2.07,-0.35)
const LADDER_MOUNT := Vector3(0,2.18,1.25)
var wheel_travel := 0.0
var droplets: Array[Dictionary] = []
var pool: Array[MeshInstance3D] = []
var splashes: Array[Dictionary] = []
var splash_pool: Array[MeshInstance3D] = []
var spray_direction := Vector3.FORWARD
var aim_point := Vector3.ZERO
var spraying := false
var enabled := true
var grounded := false
var charge := 0.0
var emission_clock := 0.0
var elapsed := 0.0
var automated_drive := Vector2.ZERO
var automated_spray := false
var use_automation := false
var automated_aim := Vector3.ZERO
var ladder: Node3D
var ladder_sections: Node3D
var ladder_amount:=0.0
var ladder_deployed:=false
var ladder_busy:=false
var ladder_tip: Area3D
const LADDER_REACH:=6.0
var ladder_length:=6.0
var effects: TruckEffects
var splash_clock:=0.0
var rings: Array[Dictionary]=[]
var ring_pool: Array[MeshInstance3D]=[]
var lights: Array[MeshInstance3D] = []

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	mass = 2.0
	collision_mask=19
	lock_rotation = true
	linear_damp = 0.2
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.05
	physics_material.bounce = 0.06
	physics_material_override = physics_material
	# A single rigid chassis with two rounded supports. No competing joint motors.
	for z in [-1.1,1.1]:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.8
		shape.shape = sphere
		shape.position = Vector3(0,0,z)
		add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var model:=preload("res://assets/models/engine_body.glb").instantiate()
	visual.add_child(model)
	_setup_body_squash(model)
	# Tires follow the airborne attitude, but stay on the road when the body
	# compresses over them. Neither pose changes the rigid collision supports.
	wheel_rig=Node3D.new()
	wheel_rig.name="AxleRig"
	add_child(wheel_rig)
	for side in [-1,1]:
		for axle in range(3):
			var z: float=[-1.3,0.85,1.65][axle]
			var steer:=Node3D.new()
			wheel_rig.add_child(steer)
			steer.position=Vector3(side*0.94,-0.25,z)
			steer.name="Steer_%s_%d" % [side,axle]
			var spin:=Node3D.new()
			steer.add_child(spin)
			var tire:=preload("res://assets/models/wheel.glb").instantiate()
			spin.add_child(tire)
			if side<0: tire.rotation.y=PI
			wheels.append(spin)
			wheel_steers.append(steer)
			wheel_rest_positions.append(steer.position)
			front_axles.append(axle==0)
	for x in [-0.58,0.58]:
		lights.append(TownProps.box(visual,Vector3(x,2.07,-1.4),Vector3(0.45,0.14,0.32),Color("8ddce1")))
	cannon = Node3D.new()
	add_child(cannon)
	cannon.position = CANNON_MOUNT
	TownProps.cylinder(cannon,Vector3.ZERO,0.3,0.3,Color("fff0c9"))
	TownProps.box(cannon,Vector3(0,0,-0.55),Vector3(0.24,0.24,1.1),Color("577584"))
	TownProps.box(cannon,Vector3(0,0,-1.05),Vector3(0.36,0.35,0.24),Color("a6eef0"))
	for i in range(480):
		var drop := TownProps.ball(get_parent(),Vector3.ZERO,Vector3.ONE*0.2,WATER_COLORS[i%WATER_COLORS.size()])
		drop.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
		drop.visible = false
		drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.append(drop)
	for i in range(120):
		var splash := TownProps.ball(get_parent(),Vector3.ZERO,Vector3.ONE,WATER_COLORS[2+i%3])
		splash.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
		splash.visible=false
		splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splash_pool.append(splash)
	var ripple_plane:=PlaneMesh.new()
	for i in 32:
		var ring:=MeshInstance3D.new()
		ring.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
		ring.mesh=ripple_plane
		var ripple_material:=TownProps.effect_material(preload("res://shaders/ripple.gdshader"))
		ring.material_override=ripple_material
		ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(ring)
		ring.visible=false
		ring_pool.append(ring)
	ladder=Node3D.new()
	ladder.name="TelescopicLadder"
	add_child(ladder)
	ladder.position=LADDER_MOUNT
	TownProps.cylinder(ladder,Vector3.ZERO,.42,.2,Color("e4c995"))
	ladder_sections=Node3D.new()
	ladder.add_child(ladder_sections)
	for x in [-.32,.32]: TownProps.box(ladder_sections,Vector3(x,0,-.5),Vector3(.085,.11,1),Color("e7e2ce"))
	for i in 15: TownProps.box(ladder_sections,Vector3(0,0,-float(i)/14),Vector3(.7,.075,.012),Color("fff0c9"))
	ladder_sections.visible=false
	# The trigger is under the unscaled pivot, never the stretching ladder mesh.
	ladder_tip=Area3D.new()
	ladder_tip.name="LadderTip"
	ladder_tip.collision_layer=0
	ladder_tip.collision_mask=4
	ladder_tip.monitoring=true
	ladder_tip.monitorable=false
	ladder.add_child(ladder_tip)
	var tip_shape:=CollisionShape3D.new()
	var tip_sphere:=SphereShape3D.new()
	tip_sphere.radius=1.0
	tip_shape.shape=tip_sphere
	ladder_tip.add_child(tip_shape)
	effects=TruckEffects.new()
	effects.truck=self
	get_parent().add_child(effects)

func extend_ladder(target: Vector3=Vector3.ZERO) -> void:
	ladder_deployed=true
	if target!=Vector3.ZERO:
		ladder_length=clampf(ladder.global_position.distance_to(target),2.0,LADDER_REACH)
		ladder.look_at(target)

func retract_ladder() -> void:
	if ladder_busy:
		return
	ladder_deployed=false

func release_ladder() -> void:
	ladder_busy=false
	ladder_deployed=false

func _ladder_path_clear(target: Vector3) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(ladder.global_position,target,3,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_ladder(dt: float) -> void:
	if not ladder_busy:
		var target: LadderEvent=null
		var nearest:=LADDER_REACH+1.4
		if ladder_deployed:
			for candidate in get_tree().get_nodes_in_group("ladder_events"):
				if not candidate is LadderEvent or not candidate.is_available(): continue
				var distance: float=ladder.global_position.distance_to(candidate.dock_position())
				if distance<nearest and _ladder_path_clear(candidate.dock_position()):
					target=candidate
					nearest=distance
		var desired: Quaternion=(visual.basis*Basis(Vector3.RIGHT,deg_to_rad(28))).get_rotation_quaternion()
		var length:=LADDER_REACH
		if target:
			var direction:=global_basis.inverse()*(target.dock_position()-ladder.global_position).normalized()
			desired=Basis.looking_at(direction,Vector3.FORWARD if absf(direction.y)>.98 else Vector3.UP).get_rotation_quaternion()
			length=clampf(nearest,2.0,LADDER_REACH)
		ladder.quaternion=ladder.quaternion.slerp(desired,1-exp(-7*dt))
		ladder_length=lerpf(ladder_length,length,1-exp(-7*dt))
		ladder_amount=move_toward(ladder_amount,1.0 if ladder_deployed else 0.0,dt*1.8)
	ladder_sections.visible=ladder_amount>.01
	ladder_sections.scale.z=maxf(.05,ladder_amount*ladder_length)
	ladder_tip.position=Vector3(0,0,-ladder_amount*ladder_length)
	# Poll overlaps so an event becoming available while already touching the tip
	# (for example, after closing dialogue) does not require another button press.
	if ladder_deployed and ladder_amount>.92 and not ladder_busy:
		for area in ladder_tip.get_overlapping_areas():
			if area is LadderEvent and _ladder_path_clear(area.dock_position()):
				if area.try_activate(self): break

func reset_truck() -> void:
	global_position = Vector3(0,1.0,12)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	heading = 0
	rotation.y=0
	charge=0
	suspension_offset=0
	suspension_velocity=0
	jump_pitch=0
	jump_pitch_velocity=0
	drive_pitch=0
	suspension_grounded=false
	previous_velocity=Vector3.ZERO
	visual.transform=Transform3D.IDENTITY
	wheel_rig.rotation=Vector3.ZERO
	wheel_rig.position=Vector3.ZERO
	cannon.position=CANNON_MOUNT
	if not ladder_busy: ladder.position=LADDER_MOUNT
	reset_physics_interpolation()
	body_squash=1.0
	for material in body_materials: material.set_shader_parameter("squash",1.0)

func drive_input() -> Vector2:
	if not enabled: return Vector2.ZERO
	if use_automation: return automated_drive
	return touch_drive if touch_drive.length()>.01 else Input.get_vector("left","right","forward","back")

func _physics_process(dt: float) -> void:
	elapsed += dt
	splash_clock=maxf(0,splash_clock-dt)
	var probe := PhysicsRayQueryParameters3D.create(global_position,global_position+Vector3.DOWN*3,1,[get_rid()])
	var ground_hit:=get_world_3d().direct_space_state.intersect_ray(probe)
	ground_distance=global_position.y-ground_hit.position.y if ground_hit else INF
	ground_normal=ground_hit.normal if ground_hit else Vector3.UP
	# The level rigid body rests higher on a slope because its two spherical
	# supports are separated. Account for that geometry when detecting contact.
	support_height=(.8+absf(ground_normal.dot(global_basis.z))*1.1)/maxf(.4,ground_normal.y)
	grounded = ground_distance<=support_height+.3
	var input := drive_input()
	var desired := Vector3.ZERO
	if camera:
		var forward := -camera.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := camera.global_basis.x
		right.y = 0
		desired = (right*input.x-forward*input.y).normalized()*input.length()
	if desired.length() > 0.1:
		var target_heading := atan2(-desired.x,-desired.z)
		var heading_error:=angle_difference(heading,target_heading)
		steering=lerpf(steering,clampf(heading_error,-0.55,0.55),1-exp(-9*dt))
		heading=lerp_angle(heading,target_heading,1-exp(-3.8*dt))
		var facing := Vector3(-sin(heading),0,-cos(heading))
		var speed := linear_velocity.dot(facing)
		var throttle := clampf((top_speed-speed)/5,0,1)
		apply_central_force(facing*acceleration*mass*throttle*(1.0 if grounded else 0.28))
	else:
		steering=lerpf(steering,0.0,1-exp(-7*dt))
	# Modest sideways grip leaves room for recoil and playful slides.
	# Soft drag keeps sustained rearward spraying playful without runaway speed.
	var planar:=Vector3(linear_velocity.x,0,linear_velocity.z)
	if planar.length()>top_speed*1.55:
		apply_central_force(-planar.normalized()*(planar.length()-top_speed*1.55)*mass*5)
	var lateral := Vector3(cos(heading),0,-sin(heading))
	apply_central_force(-lateral*linear_velocity.dot(lateral)*mass*(2.2 if input.length()>0 else 0.7))
	if input.length()<0.1 and grounded:
		apply_central_force(-Vector3(linear_velocity.x,0,linear_velocity.z)*mass*1.5)
	if (enabled and Input.is_action_pressed("brake")) or not enabled:
		apply_central_force(-Vector3(linear_velocity.x,0,linear_velocity.z)*mass*(22 if grounded else 8))
	if jump_blocked_until_release and not Input.is_action_pressed("jump"):
		jump_blocked_until_release=false
		charge=0
	if enabled and not jump_blocked_until_release and Input.is_action_pressed("jump") and grounded: charge = minf(charge+dt,0.75)
	if enabled and not jump_blocked_until_release and Input.is_action_just_released("jump") and charge>0:
		if grounded:
			apply_central_impulse(Vector3.UP*mass*lerpf(4,full_jump_speed,charge/0.75))
			jump_pitch_velocity+=lerpf(.8,1.6,charge/.75)
			bump.emit(.30+charge*.35)
		charge = 0
	rotation.y = heading
	var forward_speed:=linear_velocity.dot(Vector3(-sin(heading),0,-cos(heading)))
	var acceleration_local: Vector3=global_basis.inverse()*(linear_velocity-previous_velocity)/maxf(dt,0.001)
	_update_suspension(dt,acceleration_local,forward_speed)
	previous_velocity=linear_velocity
	cannon.position=visual.transform*body_point(CANNON_MOUNT)
	if not ladder_busy: ladder.position=visual.transform*body_point(LADDER_MOUNT)
	for light in lights: light.position.y=body_point(Vector3(0,2.07,0)).y
	_update_ladder(dt)
	# Steer on Y at the parent; spin on the actual local X axle at the child.
	# Signed longitudinal velocity / tire radius gives correct reverse motion too.
	var axle_angle: float=-forward_speed*dt/0.48
	wheel_travel+=axle_angle
	for i in wheels.size():
		wheels[i].rotation.x=wheel_travel
		wheel_steers[i].rotation.y=steering if front_axles[i] else 0.0
	for i in lights.size(): lights[i].material_override = TownProps.material(Color("92efff") if sin(elapsed*9+i*PI)>0 else Color("47738d"),true)
	_update_aim()
	if not Input.is_action_pressed("spray"): pointer_spray_blocked=false
	spraying = enabled and water>0 and (automated_spray if use_automation else touch_aim.length()>.12 or (Input.is_action_pressed("spray") and not pointer_spray_blocked) or Input.is_action_pressed("aim_up") or Input.is_action_pressed("aim_down") or Input.is_action_pressed("aim_left") or Input.is_action_pressed("aim_right"))
	if spraying:
		water = maxf(0,water-dt*5.5)
		apply_central_force(-spray_direction*recoil_acceleration*mass)
		emission_clock += dt
		while emission_clock > 0.018:
			emission_clock -= 0.018
			_emit_drop()
	_update_drops(dt)
	if global_position.y < -8 or absf(global_position.x)>85 or absf(global_position.z)>85: reset_truck()

func _update_suspension(dt: float, acceleration_local: Vector3, forward_speed: float) -> void:
	# Contact is tighter than the forgiving gameplay jump probe, so impact
	# compression happens at the road rather than while still falling toward it.
	var touching:=ground_distance<support_height+.09 and linear_velocity.y<2.8
	if touching and not suspension_grounded and previous_velocity.y < -2:
		var impact: float=absf(previous_velocity.y)
		suspension_velocity-=minf(4.5,impact*.65)
		jump_pitch_velocity-=minf(.65,impact*.055)
		bump.emit(clampf(impact*.075,.2,.72))
	suspension_grounded=touching
	var compression: float=-.30*smoothstep(0.0,1.0,charge/.75) if touching else .035
	suspension_velocity+=((compression-suspension_offset)*110-suspension_velocity*14)*dt
	suspension_offset=clampf(suspension_offset+suspension_velocity*dt,-.36,.10)
	# Positive X lifts our -Z-facing nose. Vertical speed naturally takes the
	# pose through nose-up, level near the apex, and nose-down on descent.
	var slope_pitch:=atan2(ground_normal.dot(global_basis.z),ground_normal.y)
	var target_pitch:=slope_pitch if touching else clampf(linear_velocity.y/9.0,-1,1)*(.20 if linear_velocity.y>0 else .14)
	jump_pitch_velocity+=((target_pitch-jump_pitch)*100-jump_pitch_velocity*15)*dt
	jump_pitch+=jump_pitch_velocity*dt
	var road_pitch:=clampf(acceleration_local.z*.005,-.085,.085) if touching else 0.0
	drive_pitch=lerpf(drive_pitch,road_pitch,1-exp(-6*dt))
	visual.rotation.x=jump_pitch+drive_pitch
	visual.rotation.z=lerpf(visual.rotation.z,-steering*absf(forward_speed)*.024,1-exp(-7*dt))
	body_squash=1.0+minf(0,suspension_offset)/1.80
	for material in body_materials: material.set_shader_parameter("squash",body_squash)
	visual.position.y=maxf(0,suspension_offset)+(sin(elapsed*13)*minf(.012,absf(forward_speed)*.001) if touching else 0.0)
	# Blend axle attitude only once there's room beneath the tires. They stay
	# level and above the surface during wind-up and touchdown compression.
	wheel_rig.rotation.x=lerpf(slope_pitch,jump_pitch,smoothstep(support_height+.02,support_height+.75,ground_distance))
	wheel_rig.position.y=0
	# Each tire reads the visible paving beneath it, including raised white
	# intersection pieces. Axle travel follows curbs without moving the chassis.
	for i in wheel_steers.size():
		var axle:=wheel_steers[i]
		axle.position=wheel_rest_positions[i]
		var center:=axle.global_position
		var forward:=(-axle.global_basis.z*Vector3(1,0,1)).normalized()
		var side: Vector3=(axle.global_basis.x*Vector3(1,0,1)).normalized()
		var tire_y: float=-INF
		# Sample the curved tread ahead/behind and both sidewalls too. This
		# starts the roll onto a curb before the tire's centre crosses its edge.
		var samples: Array[Vector3]=[Vector3.ZERO,forward*.24,-forward*.24,side*.13,-side*.13]
		for j in samples.size():
			var sample:=center+samples[j]
			var query:=PhysicsRayQueryParameters3D.create(sample+Vector3.UP*.7,sample+Vector3.DOWN*1.25,9,[get_rid()])
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit: continue
			var radius:=.4386 if j==1 or j==2 else .50
			tire_y=maxf(tire_y,hit.position.y+radius/maxf(.7,hit.normal.y)+.012)
		var correction: float=tire_y-center.y
		if correction>0 or (touching and correction>-.22):
			axle.global_position=center+Vector3.UP*correction

func body_point(point: Vector3) -> Vector3:
	if point.y>.38: point.y=.38+(point.y-.38)*body_squash
	return point

func _setup_body_squash(node: Node3D) -> void:
	if node is MeshInstance3D:
		var body_from_mesh:=visual.global_transform.affine_inverse()*node.global_transform
		for surface in node.mesh.get_surface_count():
			var original: StandardMaterial3D=node.get_active_material(surface)
			var material:=ShaderMaterial.new()
			material.shader=preload("res://shaders/truck_squash.gdshader")
			material.set_shader_parameter("paint",original.albedo_color)
			material.set_shader_parameter("roughness",original.roughness)
			material.set_shader_parameter("metal",original.metallic)
			material.set_shader_parameter("body_from_mesh",body_from_mesh)
			material.set_shader_parameter("mesh_from_body",body_from_mesh.affine_inverse())
			node.set_surface_override_material(surface,material)
			body_materials.append(material)
	for child in node.get_children():
		if child is Node3D: _setup_body_squash(child)

func _update_aim() -> void:
	if not camera: return
	var origin := cannon.global_position
	if use_automation:
		aim_point = automated_aim
	else:
		var mouse := get_viewport().get_mouse_position()
		var ray_origin := camera.project_ray_origin(mouse)
		var ray_direction := camera.project_ray_normal(mouse)
		var query := PhysicsRayQueryParameters3D.create(ray_origin,ray_origin+ray_direction*200,3,[get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit: aim_point = hit.position
		else:
			var intersection = Plane(Vector3.UP,0.5).intersects_ray(ray_origin,ray_direction)
			if intersection != null: aim_point = intersection
		var keys := touch_aim if touch_aim.length()>.12 else Input.get_vector("aim_left","aim_right","aim_up","aim_down")
		if keys.length()>0:
			var f := -camera.global_basis.z
			f.y=0
			aim_point = origin+(camera.global_basis.x*keys.x-f.normalized()*keys.y).normalized()*12
	# Like the browser prototype, select a nearby target ahead of the nozzle,
	# then solve the arc. This changes the shot, never the collision result.
	assisted=false
	if aim_assist.is_valid():
		var target: Variant=aim_assist.call(origin,aim_point)
		if target is Vector3:
			aim_point=target
			assisted=true
	var offset:=aim_point-origin
	var horizontal:=Vector3(offset.x,0,offset.z)
	if horizontal.length()>AIM_RANGE:
		aim_point=origin+horizontal.normalized()*AIM_RANGE+Vector3.UP*minf(0,offset.y)
	# Free spray retains the truck's momentum and naturally travels farther.
	# Assisted shots compensate for it so moving past a job still hits the target.
	var shot:=solve_shot(origin,aim_point,linear_velocity if assisted else Vector3.ZERO)
	spray_direction=shot.get("direction",Vector3.ZERO)
	if spray_direction==Vector3.ZERO:
		spray_direction=(aim_point-origin).normalized()
	if spray_direction.length()<.1: spray_direction=Vector3.FORWARD
	cannon.look_at(origin+spray_direction,Vector3.FORWARD if absf(spray_direction.y)>.98 else Vector3.UP)

func solve_shot(origin: Vector3, target: Vector3, inherited_velocity: Vector3=Vector3.ZERO) -> Dictionary:
	# Solve target-origin-v*t+0.5*g*t² = direction*(nozzle_length+speed*t).
	# Including the nozzle offset here makes the assisted arc and emitted water agree.
	var offset:=target-origin
	var previous_time:=0.001
	var previous_error:=_flight_error(offset,inherited_velocity,previous_time)
	for step in range(1,49):
		var t:=lerpf(.001,WATER_LIFETIME,step/48.0)
		var error:=_flight_error(offset,inherited_velocity,t)
		if previous_error>=0 and error<=0:
			var low:=previous_time
			var high:=t
			for iteration in 16:
				var mid: float=(low+high)*.5
				if _flight_error(offset,inherited_velocity,mid)>0: low=mid
				else: high=mid
			var travel: float=(low+high)*.5
			var direction: Vector3=(offset-inherited_velocity*travel+Vector3.UP*.5*WATER_GRAVITY*travel*travel).normalized()
			return {"direction":direction,"velocity":inherited_velocity+direction*WATER_SPEED,"time":travel}
		previous_time=t
		previous_error=error
	return {}

func _flight_error(offset: Vector3, inherited_velocity: Vector3, time: float) -> float:
	return (offset-inherited_velocity*time+Vector3.UP*.5*WATER_GRAVITY*time*time).length()-(1.1+WATER_SPEED*time)

func shot_direction(origin: Vector3, target: Vector3) -> Vector3:
	return solve_shot(origin,target).get("direction",Vector3.ZERO)

func shot_is_clear(origin: Vector3, target: Vector3) -> bool:
	var shot:=solve_shot(origin,target,linear_velocity)
	if shot.is_empty(): return false
	var start: Vector3=origin+shot.direction*1.1
	var previous:=start
	for step in range(1,17):
		var t: float=shot.time*step/16.0
		var point: Vector3=start+shot.velocity*t+Vector3.DOWN*.5*WATER_GRAVITY*t*t
		var query:=PhysicsRayQueryParameters3D.create(previous,point,3,[get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query): return false
		previous=point
	return true

func _emit_drop() -> void:
	var side:=spray_direction.cross(Vector3.UP).normalized()
	if side.length()<.1: side=Vector3.RIGHT
	var up:=side.cross(spray_direction).normalized()
	# Equal droplets keep one compact stream; every shot inherits chassis velocity.
	for pellet in 5:
		var angle:=randf()*TAU
		var radius:=sqrt(randf())*.052
		var direction: Vector3=(spray_direction+side*cos(angle)*radius+up*sin(angle)*radius).normalized()
		_spawn_drop(direction,linear_velocity+direction*WATER_SPEED,WATER_LIFETIME,.018/5.0,false)
	# One small breakaway droplet per fifteen stream droplets, purely decorative.
	spray_pulse+=1
	if spray_pulse%3==0:
		var relative:=spray_direction*randf_range(10,16)+side*randf_range(-4,4)+up*randf_range(-2.5,4)
		_spawn_drop(relative.normalized(),linear_velocity+relative,randf_range(.35,.55),0.0,true)

func _spawn_drop(direction: Vector3, velocity: Vector3, lifetime: float, amount: float, stray: bool) -> void:
	for mesh in pool:
		if mesh.visible: continue
		mesh.visible=true
		var width:=randf_range(.055,.085) if stray else randf_range(.115,.14)
		mesh.scale=Vector3(width,width,randf_range(.10,.17) if stray else randf_range(.27,.37))
		mesh.material_override=TownProps.material(WATER_COLORS[randi()%WATER_COLORS.size()])
		mesh.global_position=cannon.global_position+direction*1.1
		mesh.look_at(mesh.global_position+velocity,Vector3.FORWARD if absf(velocity.normalized().y)>.98 else Vector3.UP)
		mesh.reset_physics_interpolation()
		droplets.append({"mesh":mesh,"velocity":velocity,"life":lifetime,"amount":amount,"stray":stray})
		break

func _update_drops(dt: float) -> void:
	for i in range(droplets.size()-1,-1,-1):
		var d: Dictionary=droplets[i]
		var mesh: MeshInstance3D=d.mesh
		var start:=mesh.global_position
		var end: Vector3=start+d.velocity*dt+Vector3.DOWN*.5*WATER_GRAVITY*dt*dt
		d.velocity+=Vector3.DOWN*WATER_GRAVITY*dt
		var query:=PhysicsRayQueryParameters3D.create(start,end,3,[get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		var consumed:=false
		if d.amount>0:
			if hit_receiver.is_valid(): consumed=hit_receiver.call(hit.position if hit else end,d.amount)
			water_hit.emit(hit.position if hit else end,d.amount)
		mesh.global_position=end
		mesh.look_at(end+d.velocity,Vector3.FORWARD if absf(d.velocity.normalized().y)>.98 else Vector3.UP)
		d.life-=dt
		if hit or consumed or d.life<=0:
			if (hit or consumed) and not d.stray: _splash(hit.position if hit else end,hit.normal if hit else Vector3.UP,not hit.is_empty())
			mesh.visible=false
			droplets.remove_at(i)
	for i in range(splashes.size()-1,-1,-1):
		var s: Dictionary=splashes[i]
		s.life-=dt
		s.velocity+=Vector3.DOWN*18*dt
		s.mesh.position+=s.velocity*dt
		s.mesh.scale=Vector3.ONE*s.size*minf(1,maxf(.01,s.life*5))
		if s.life<=0 or s.mesh.position.y<s.floor:
			s.mesh.visible=false
			splashes.remove_at(i)
	for i in range(rings.size()-1,-1,-1):
		var r:=rings[i]
		r.life-=dt
		var expansion: float=1+(.38-r.life)*3
		r.mesh.scale=Vector3(expansion*.55,1,expansion*.55)
		TownProps.effect_opacity(r.mesh,maxf(0,r.life)*1.1)
		if r.life<=0: r.mesh.visible=false; rings.remove_at(i)

func _splash(point: Vector3, normal: Vector3=Vector3.UP, surface: bool=true) -> void:
	if splash_clock>0: return
	splash_clock=.045
	var tangent:=normal.cross(Vector3.RIGHT).normalized()
	if tangent.length()<.1: tangent=normal.cross(Vector3.FORWARD).normalized()
	var across:=normal.cross(tangent).normalized()
	for i in 7:
		for mesh in splash_pool:
			if mesh.visible: continue
			var angle:=TAU*i/7+randf_range(-.25,.25)
			mesh.visible=true
			mesh.global_position=point+normal*.06
			mesh.reset_physics_interpolation()
			var velocity:=normal*randf_range(1.8,3.6)+(tangent*cos(angle)+across*sin(angle))*randf_range(1,2.7)
			splashes.append({"mesh":mesh,"life":randf_range(.3,.6),"velocity":velocity,"size":randf_range(.07,.16),"floor":point.y+.01})
			break
	if not surface: return
	for mesh in ring_pool:
		if mesh.visible: continue
		mesh.visible=true
		mesh.global_position=point+normal*.035
		mesh.basis=Basis(tangent,normal,tangent.cross(normal)).orthonormalized()
		mesh.scale=Vector3.ONE*.5
		mesh.reset_physics_interpolation()
		rings.append({"mesh":mesh,"life":.38})
		break
