class_name FireEngine
extends RigidBody3D

signal bump(strength: float)

signal water_hit(point: Vector3, amount: float)
signal empty_spray

var hit_receiver: Callable
var drive_guide: Callable
var drive_surface: Callable
var surface_sample: Dictionary={}
var train_push_z:=NAN
var aim_assist: Callable
var assisted := false
const WATER_SPEED := 22.0 # Nozzle speed relative to the moving truck.
const WATER_GRAVITY := 26.0
const WATER_LIFETIME := 1.15
const AIM_RANGE := 15.0
const FREE_SPRAY_REACH:=12.0
const FREE_SPRAY_DROP:=2.3
const CANNON_TURN_SECONDS:=.15
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
var cannon_turn_from:=Quaternion.IDENTITY
var cannon_turn_target:=Quaternion.IDENTITY
var cannon_turn_elapsed:=CANNON_TURN_SECONDS
var wheels: Array[Node3D] = []
var wheel_steers: Array[Node3D] = []
var wheel_rest_positions: Array[Vector3] = []
var front_axles: Array[bool] = []
var steering := 0.0
var brake_engagement:=0.0
var brake_holding:=false
var previous_velocity := Vector3.ZERO
var suspension_velocity := 0.0
var suspension_offset := 0.0
var suspension_grounded := false
var jump_pitch := 0.0
var jump_pitch_velocity := 0.0
var drive_pitch := 0.0
var body_roll := 0.0
var body_roll_velocity := 0.0
const WHEEL_LIFT_LIMIT:=.10 # Highest step a tire climbs relative to the chassis.
var ground_distance := INF
var ground_normal := Vector3.UP
var support_height := .8
const CANNON_MOUNT := Vector3(0,2.07,-0.35)
const LADDER_MOUNT := Vector3(0,1.78,1.85)
var wheel_travel := 0.0
var droplets: Array[Dictionary] = []
var pool: Array[MeshInstance3D] = []
var splashes: Array[Dictionary] = []
var splash_pool: Array[MeshInstance3D] = []
var water_batch: WaterDrawBatch
var drop_index:=0
var splash_index:=0
var water_materials: Array[Material]=[]
var spray_direction := Vector3.FORWARD
var aim_point := Vector3.ZERO
var mouse_aiming := false
var spraying := false
var spray_requested:=false
var empty_spray_cooldown:=0.0
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
var ladder_slides: Array[Node3D]=[]
var ladder_amount:=0.0
var ladder_deployed:=false
var ladder_busy:=false
var ladder_tip: Area3D
const LADDER_SECTION_LENGTH:=2.0
const LADDER_OVERLAP:=.20
const LADDER_REACH:=LADDER_SECTION_LENGTH*3-LADDER_OVERLAP*2
var ladder_length:=LADDER_REACH
var effects: TruckEffects
var splash_clock:=0.0
var rings: Array[Dictionary]=[]
var ring_pool: Array[MeshInstance3D]=[]
var lights: Array[MeshInstance3D] = []

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	mass = 2.0
	collision_mask=115 # Town contacts, mat boundary, and bridge safety (64).
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
	# Suspension supports alone cannot protect the tall cab from a low ceiling.
	# This upper hull hits the bridge without adding a tire-like ledge.
	var upper:=CollisionShape3D.new()
	var hull:=BoxShape3D.new()
	hull.size=Vector3(1.82,1.64,3.65)
	upper.shape=hull
	upper.position=Vector3(0,1.13,-.25)
	add_child(upper)
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
	var water_mesh:=SphereMesh.new()
	water_mesh.radial_segments=12
	water_mesh.rings=6
	for color in WATER_COLORS: water_materials.append(TownProps.material(color))
	for i in range(480):
		var drop := TownProps.ball(get_parent(),Vector3.ZERO,Vector3.ONE*0.2,WATER_COLORS[i%WATER_COLORS.size()])
		drop.mesh=water_mesh
		drop.layers=0
		drop.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
		drop.visible = false
		drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.append(drop)
	for i in range(120):
		var splash := TownProps.ball(get_parent(),Vector3.ZERO,Vector3.ONE,WATER_COLORS[2+i%3])
		splash.mesh=water_mesh
		splash.layers=0
		splash.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
		splash.visible=false
		splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splash_pool.append(splash)
	water_batch=WaterDrawBatch.new()
	water_batch.truck=self
	get_parent().add_child(water_batch)
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
	ladder_sections=Node3D.new()
	ladder_sections.name="RoofLadder"
	ladder.add_child(ladder_sections)
	# The original roof ladder and two fixed-size copies slide over one another.
	# Geometry and rung spacing never stretch, including during retraction.
	for i in 3:
		var section:=preload("res://assets/models/roof_ladder.glb").instantiate()
		section.name="LadderSection%d" % i
		ladder_sections.add_child(section)
		section.position.y=i*.105
		ladder_slides.append(section)
	# The trigger follows the last rung, outside the sliding visual sections.
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
	if not ladder_deployed: _ladder_sound("ladder_extend")
	ladder_deployed=true
	if target!=Vector3.ZERO:
		ladder_length=clampf(ladder.global_position.distance_to(target),LADDER_SECTION_LENGTH,LADDER_REACH)

func retract_ladder() -> void:
	if ladder_busy:
		return
	if ladder_deployed: _ladder_sound("ladder_retract")
	ladder_deployed=false

func release_ladder() -> void:
	ladder_busy=false
	retract_ladder()

func _ladder_sound(kind: String) -> void:
	var game:=get_parent()
	if game.get("sounds")!=null: game.sounds.play(kind,global_position,.85,.25)

func arrival_pose(at: Vector3, forward_heading: float, distance: float, age: float) -> void:
	# Baked touchdown, followed by normal rolling, while physics is suspended.
	global_position=at+Vector3.UP*(5.5*pow(maxf(0,1-age/.55),2)+.16*absf(sin(maxf(0,age-.55)*18))*exp(-maxf(0,age-.55)*7))
	heading=forward_heading
	rotation.y=heading
	wheel_travel=distance/.5
	for wheel in wheels: wheel.rotation.x=wheel_travel
	reset_physics_interpolation()
	show()

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
		ladder_amount=move_toward(ladder_amount,1.0 if ladder_deployed else 0.0,dt*1.6)
		var stowed:=visual.basis.get_rotation_quaternion()
		var desired: Quaternion=(visual.basis*Basis(Vector3.RIGHT,deg_to_rad(28))).get_rotation_quaternion()
		var length:=LADDER_REACH
		if target:
			var direction:=global_basis.inverse()*(target.dock_position()-ladder.global_position).normalized()
			desired=Basis.looking_at(direction,Vector3.FORWARD if absf(direction.y)>.98 else Vector3.UP).get_rotation_quaternion()
			length=clampf(nearest,LADDER_SECTION_LENGTH,LADDER_REACH)
		# Lift the stacked roof ladder before sliding the two upper sections out.
		# Reversing the same timeline retracts them before lowering onto the roof.
		desired=stowed.slerp(desired,smoothstep(0.0,.30,ladder_amount))
		ladder.quaternion=stowed if ladder_amount==0 else ladder.quaternion.slerp(desired,1-exp(-12*dt))
		ladder_length=lerpf(ladder_length,length,1-exp(-7*dt))
	var extension:=smoothstep(.30,1.0,ladder_amount)*(ladder_length-LADDER_SECTION_LENGTH)
	for i in ladder_slides.size(): ladder_slides[i].position.z=-extension*float(i)/2.0
	ladder_tip.position=Vector3(0,.21,-LADDER_SECTION_LENGTH-extension)
	# Poll overlaps so an event becoming available while already touching the tip
	# (for example, after closing dialogue) does not require another button press.
	if ladder_deployed and ladder_amount>.92 and not ladder_busy:
		for area in ladder_tip.get_overlapping_areas():
			if area is LadderEvent and _ladder_path_clear(area.dock_position()):
				if area.try_activate(self): break

var world_origin:=Vector3.ZERO
var recovery_spawn:=Vector3(0,1,12)

func reset_truck() -> void:
	train_push_z=NAN
	axis_lock_linear_z=false
	global_position = world_origin+recovery_spawn
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	heading = 0
	rotation.y=0
	charge=0
	brake_engagement=0
	brake_holding=false
	suspension_offset=0
	suspension_velocity=0
	jump_pitch=0
	jump_pitch_velocity=0
	drive_pitch=0
	body_roll=0
	body_roll_velocity=0
	suspension_grounded=false
	previous_velocity=Vector3.ZERO
	visual.transform=Transform3D.IDENTITY
	wheel_rig.rotation=Vector3.ZERO
	wheel_rig.position=Vector3.ZERO
	cannon.position=CANNON_MOUNT
	cannon.quaternion=Quaternion.IDENTITY
	cannon_turn_from=Quaternion.IDENTITY
	cannon_turn_target=Quaternion.IDENTITY
	cannon_turn_elapsed=CANNON_TURN_SECONDS
	if not ladder_busy: ladder.position=LADDER_MOUNT
	reset_physics_interpolation()
	body_squash=1.0
	for material in body_materials: material.set_shader_parameter("squash",1.0)

func drive_input() -> Vector2:
	if not enabled: return Vector2.ZERO
	if use_automation: return automated_drive
	return touch_drive if touch_drive.length()>.01 else Input.get_vector("left","right","forward","back")

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if drive_surface.is_valid():
		surface_sample=drive_surface.call(state.transform.origin)
		var surface_y: float=surface_sample.height+.8
		var gradient: Vector2=surface_sample.gradient
		var slope_velocity: float=gradient.dot(Vector2(state.linear_velocity.x,state.linear_velocity.z))
		var gap: float=state.transform.origin.y-surface_y
		# Preserve deliberate jumps and free falls. Grounded motion follows the
		# continuous height profile instead of striking each triangle's edge.
		if gap<.16 and state.linear_velocity.y<slope_velocity+1.8:
			var velocity:=state.linear_velocity
			velocity.y=slope_velocity-gap/state.step
			state.linear_velocity=velocity
	if is_nan(train_push_z): return
	# Constrain only sideways motion. Forward contact forces, hose recoil,
	# vertical suspension and gravity stay with the physics solver.
	var pose:=state.transform
	pose.origin.z=lerpf(pose.origin.z,train_push_z,1-exp(-14*state.step))
	state.transform=pose
	var velocity:=state.linear_velocity
	velocity.z=0
	state.linear_velocity=velocity

func _physics_process(dt: float) -> void:
	elapsed += dt
	splash_clock=maxf(0,splash_clock-dt)
	var probe := PhysicsRayQueryParameters3D.create(global_position,global_position+Vector3.DOWN*3,1,[get_rid()])
	var ground_hit:=get_world_3d().direct_space_state.intersect_ray(probe)
	ground_distance=global_position.y-ground_hit.position.y if ground_hit else INF
	ground_normal=ground_hit.normal if ground_hit else Vector3.UP
	if drive_surface.is_valid() and not surface_sample.is_empty():
		ground_distance=global_position.y-float(surface_sample.height)
		ground_normal=surface_sample.normal
	# The level rigid body rests higher on a slope because its two spherical
	# supports are separated. Account for that geometry when detecting contact.
	support_height=.8 if drive_surface.is_valid() else (.8+absf(ground_normal.dot(global_basis.z))*1.1)/maxf(.4,ground_normal.y)
	grounded = ground_distance<=support_height+.3
	var braking:=enabled and Input.is_action_pressed("brake")
	brake_engagement=lerpf(brake_engagement,1.0 if braking else 0.0,1-exp(-10*dt))
	var planar:=Vector3(linear_velocity.x,0,linear_velocity.z)
	# Sliding brakes and stationary bracing need different responses. Once
	# stopped, tire grip absorbs horizontal hose recoil without locking gravity.
	brake_holding=braking and grounded and planar.length()<.35
	var input := drive_input()
	var desired := Vector3.ZERO
	if camera:
		var forward := -camera.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := camera.global_basis.x
		right.y = 0
		desired = (right*input.x-forward*input.y).normalized()*input.length()
	if drive_guide.is_valid(): desired=drive_guide.call(desired,dt)
	if desired.length() > 0.1:
		var target_heading := atan2(-desired.x,-desired.z)
		var heading_error:=angle_difference(heading,target_heading)
		steering=lerpf(steering,clampf(heading_error,-0.55,0.55),1-exp(-9*dt))
		heading=lerp_angle(heading,target_heading,1-exp(-3.8*dt))
		var facing := Vector3(-sin(heading),0,-cos(heading))
		var speed := linear_velocity.dot(facing)
		var throttle := clampf((top_speed-speed)/5,0,1)
		apply_central_force(facing*acceleration*mass*throttle*(1.0 if grounded else 0.28)*(0.0 if brake_holding else 1-brake_engagement))
	else:
		steering=lerpf(steering,0.0,1-exp(-7*dt))
	# Modest sideways grip leaves room for recoil and playful slides.
	# Soft drag keeps sustained rearward spraying playful without runaway speed.
	if planar.length()>top_speed*1.55:
		apply_central_force(-planar.normalized()*(planar.length()-top_speed*1.55)*mass*5)
	var lateral := Vector3(cos(heading),0,-sin(heading))
	apply_central_force(-lateral*linear_velocity.dot(lateral)*mass*(2.2 if input.length()>0 else 0.7))
	if input.length()<0.1 and grounded:
		apply_central_force(-Vector3(linear_velocity.x,0,linear_velocity.z)*mass*1.5)
	if brake_holding:
		apply_central_force(-planar*mass/maxf(dt,.001))
	elif braking:
		# Limit deceleration instead of multiplying driving speed by a huge
		# damping factor. Pressure eases in so momentum carries a short slide.
		apply_central_force(-planar.normalized()*minf(planar.length()/maxf(dt,.001),26)*mass*brake_engagement*(1.0 if grounded else .25))
	elif not enabled:
		apply_central_force(-planar*mass*(22 if grounded else 8))
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
	if not Input.is_action_pressed("spray"): pointer_spray_blocked=false
	spray_requested = enabled and (automated_spray if use_automation else touch_aim.length()>.12 or (Input.is_action_pressed("spray") and not pointer_spray_blocked) or Input.is_action_pressed("aim_up") or Input.is_action_pressed("aim_down") or Input.is_action_pressed("aim_left") or Input.is_action_pressed("aim_right"))
	_update_aim(dt)
	spraying=water>0 and spray_requested
	empty_spray_cooldown=maxf(0,empty_spray_cooldown-dt)
	if not spray_requested: empty_spray_cooldown=0
	if spray_requested and water<=0 and empty_spray_cooldown==0:
		empty_spray_cooldown=.65
		empty_spray.emit()
		_emit_empty_sputter()
	if spraying:
		water = maxf(0,water-dt*5.5)
		var recoil: Vector3=-spray_direction*recoil_acceleration*mass
		if brake_holding:
			recoil.x=0
			recoil.z=0
		apply_central_force(recoil)
		emission_clock += dt
		while emission_clock > 0.018:
			emission_clock -= 0.018
			_emit_drop()
	_update_drops(dt)
	if global_position.y < -8 or absf(global_position.x-world_origin.x)>87 or absf(global_position.z-world_origin.z)>87: reset_truck()

func _emit_empty_sputter() -> void:
	# A few weak, cosmetic drops: no recoil, water budget or mission hits.
	var side:=spray_direction.cross(Vector3.UP).normalized()
	for i in 4:
		var velocity:=linear_velocity+spray_direction*randf_range(2.5,4.0)+side*randf_range(-.9,.9)+Vector3.UP*randf_range(.8,1.6)
		_spawn_drop(spray_direction,velocity,randf_range(.40,.52),0.0,true,2.2)

func _update_suspension(dt: float, acceleration_local: Vector3, forward_speed: float) -> void:
	# Contact is tighter than the forgiving gameplay jump probe, so impact
	# compression happens at the road rather than while still falling toward it.
	var contact_speed:=linear_velocity.dot(ground_normal) if drive_surface.is_valid() else linear_velocity.y
	var touching:=ground_distance<support_height+.09 and contact_speed<2.8
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
	# The body leans out of corners on soft springs and sways back past level.
	# Cornering force comes from sideways acceleration plus steering at speed,
	# so a sharp turn is felt even before the chassis has fully rotated.
	var corner:=clampf(acceleration_local.x*.011-steering*absf(forward_speed)*.016,-.14,.14) if touching else 0.0
	body_roll_velocity+=((corner-body_roll)*70-body_roll_velocity*7.5)*dt
	body_roll=clampf(body_roll+body_roll_velocity*dt,-.17,.17) # Stays clear of the tires.
	visual.rotation.z=body_roll
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
		if drive_surface.is_valid() and not surface_sample.is_empty():
			var normal: Vector3=surface_sample.normal
			var offset:=center-global_position
			var tire_surface: float=surface_sample.height-(normal.x*offset.x+normal.z*offset.z)/normal.y
			var correction:=tire_surface+.494/normal.y+.002-center.y
			if touching or correction>0:
				axle.global_position=center+Vector3.UP*minf(correction,WHEEL_LIFT_LIMIT)
			continue
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
			# Tires follow fixed ground, curbs and ramps. Loose props, traffic
			# and the train are pushed by the chassis instead of climbed.
			if not hit or hit.collider is RigidBody3D: continue
			var radius:=.4386 if j==1 or j==2 else .50
			tire_y=maxf(tire_y,hit.position.y+radius/maxf(.7,hit.normal.y)+.012)
		var correction: float=minf(tire_y-center.y,WHEEL_LIFT_LIMIT)
		if correction>0 or (touching and correction>-.22):
			axle.global_position=center+Vector3.UP*correction
	_bump_stop()

# Tires must stay inside their arches however the body leans. When one would
# rise into its arch, ease that side's roll first, then lift the body over it,
# as a real suspension does when it reaches its bump stops.
const ARCH_TRAVEL:=.11 # Upward room between a resting tire and its fender lip.
func _bump_stop() -> void:
	for pass_index in 2:
		var to_body:=visual.transform.affine_inverse()
		var side_excess:=[0.0,0.0]
		for i in wheel_steers.size():
			var tire: Vector3=to_body*(wheel_rig.transform*wheel_steers[i].position)
			var rest: Vector3=wheel_rest_positions[i]
			var side:=0 if rest.x<0 else 1
			side_excess[side]=maxf(side_excess[side],tire.y-rest.y-ARCH_TRAVEL)
		var left: float=maxf(0,side_excess[0])
		var right: float=maxf(0,side_excess[1])
		if left==0 and right==0: return
		# Positive Z roll raises the right (+X) side away from its tires.
		var roll_fix:=(right-left)/(2*.94)
		if pass_index==0:
			body_roll+=roll_fix
			if signf(body_roll_velocity)!=signf(roll_fix): body_roll_velocity=0
			visual.rotation.z=body_roll
		else:
			visual.position.y+=maxf(left,right)

func body_point(point: Vector3) -> Vector3:
	if point.y>.38: point.y=.38+(point.y-.38)*body_squash
	return point

func _setup_body_squash(node: Node3D) -> void:
	if node is MeshInstance3D:
		var body_from_mesh:=visual.global_transform.affine_inverse()*node.global_transform
		for surface in node.mesh.get_surface_count():
			var original: StandardMaterial3D=TownProps.toy_finish(node.get_active_material(surface))
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

func world_aim_direction(stick: Vector2) -> Vector3:
	if not camera: return -global_basis.z
	var right:=camera.global_basis.x
	right.y=0
	var forward:=-camera.global_basis.z
	forward.y=0
	return (right.normalized()*stick.x-forward.normalized()*stick.y).normalized()

func mouse_aim_direction(pointer: Vector2) -> Vector3:
	# Treat the truck's on-screen centre as the centre of a virtual stick.
	# Cursor distance, scene depth, rooftops and camera zoom never set range.
	var center:=camera.unproject_position(get_global_transform_interpolated().origin)
	var stick:=pointer-center
	if stick.length()<8:
		var resting:=-cannon.global_basis.z
		resting.y=0
		return resting.normalized()
	return world_aim_direction(stick.normalized())

func _update_aim(dt: float=1.0/60) -> void:
	if not camera: return
	mouse_aiming=false
	if not spray_requested:
		# Keep the turret's local pose. Its truck parent supplies idle rotation;
		# moving the pointer while driving cannot lock it to a compass heading.
		assisted=false
		cannon_turn_from=cannon.quaternion
		cannon_turn_target=cannon.quaternion
		cannon_turn_elapsed=CANNON_TURN_SECONDS
		spray_direction=-cannon.global_basis.z
		return
	var origin:=cannon.global_position
	if use_automation:
		aim_point=automated_aim
	else:
		var stick:=touch_aim if touch_aim.length()>.12 else Input.get_vector("aim_left","aim_right","aim_up","aim_down")
		mouse_aiming=stick.length()<=.01
		var direction:=world_aim_direction(stick) if not mouse_aiming else mouse_aim_direction(get_viewport().get_mouse_position())
		aim_point=origin+direction*FREE_SPRAY_REACH+Vector3.DOWN*FREE_SPRAY_DROP
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
	var direction: Vector3=shot.get("direction",Vector3.ZERO)
	if direction==Vector3.ZERO: direction=(aim_point-origin).normalized()
	if direction.length()<.1: direction=-global_basis.z
	_turn_cannon(direction,dt)
	# Recoil and water follow the actual barrel throughout the short turn.
	spray_direction=-cannon.global_basis.z

func _turn_cannon(direction: Vector3, dt: float) -> void:
	var up:=Vector3.FORWARD if absf(direction.y)>.98 else Vector3.UP
	var target:=(global_basis.inverse()*Basis.looking_at(direction,up)).get_rotation_quaternion().normalized()
	if target.angle_to(cannon_turn_target)>.0001:
		cannon_turn_from=cannon.quaternion
		cannon_turn_target=target
		cannon_turn_elapsed=0
	cannon_turn_elapsed=minf(CANNON_TURN_SECONDS,cannon_turn_elapsed+dt)
	cannon.quaternion=cannon_turn_from.slerp(cannon_turn_target,cannon_turn_elapsed/CANNON_TURN_SECONDS)


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

func shot_is_clear(origin: Vector3, target: Vector3, receiver: RID=RID()) -> bool:
	var shot:=solve_shot(origin,target,linear_velocity)
	if shot.is_empty(): return false
	var start: Vector3=origin+shot.direction*1.1
	var previous:=start
	for step in range(1,17):
		var t: float=shot.time*step/16.0
		var point: Vector3=start+shot.velocity*t+Vector3.DOWN*.5*WATER_GRAVITY*t*t
		var excluded: Array[RID]=[get_rid()]
		if receiver.is_valid(): excluded.append(receiver)
		var query:=PhysicsRayQueryParameters3D.create(previous,point,3,excluded)
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

func _spawn_drop(direction: Vector3, velocity: Vector3, lifetime: float, amount: float, stray: bool, size_multiplier: float=1.0) -> void:
	for offset in pool.size():
		var slot: int=(drop_index+offset)%pool.size()
		var mesh:=pool[slot]
		if mesh.visible: continue
		drop_index=(slot+1)%pool.size()
		mesh.visible=true
		var width:=randf_range(.055,.085) if stray else randf_range(.115,.14)
		mesh.scale=Vector3(width,width,randf_range(.10,.17) if stray else randf_range(.27,.37))*size_multiplier
		mesh.material_override=water_materials[randi()%water_materials.size()]
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
		for offset in splash_pool.size():
			var slot: int=(splash_index+offset)%splash_pool.size()
			var mesh:=splash_pool[slot]
			if mesh.visible: continue
			splash_index=(slot+1)%splash_pool.size()
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
