class_name RaceRival
extends RigidBody3D

const MAX_SPEED:=17.25 # 1.5 times the original 11.5 m/s target.
const CORNER_SPEED:=12.0
const CAR_HALF_WIDTH:=1.2
var challenge: RaceChallenge
var driving:=false
var course_distance:=0.0
var progress:=0.0
var speed:=0.0
var lane:=-2.4
var lane_target:=-2.4
var avoiding:=false
var avoid_hold:=0.0
var segment:=0
var wheels: Array[Node3D]=[]
var wheel_angle:=0.0
var art: Node3D
var yaw:=0.0
var paused_velocity:=Vector3.ZERO
var paused_driving:=false

func _ready() -> void:
	mass=1.5
	custom_integrator=true
	continuous_cd=true
	can_sleep=false
	axis_lock_angular_x=true
	axis_lock_angular_y=true
	axis_lock_angular_z=true
	var finish:=PhysicsMaterial.new()
	finish.friction=.08
	finish.bounce=.08
	physics_material_override=finish
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(2.15,1.55,4.0)
	collision.shape=box
	collision.position.y=.9
	add_child(collision)
	_build_art()
	park()

func grid(distance: float) -> void:
	course_distance=distance
	progress=0
	lane=-2.4
	lane_target=lane
	avoid_hold=0
	avoiding=false
	segment=0
	for i in RaceCourse.distances.size()-1:
		if RaceCourse.distances[i]<=distance: segment=i
	var pose:=RaceChallenge.course_pose(distance,lane)
	global_transform=Transform3D(pose.basis,ToyRaceTrack.ORIGIN+pose.origin)
	yaw=pose.basis.get_euler().y
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	collision_layer=2
	collision_mask=1|2|Playroom.WALL_LAYER|ToyRaceTrack.BRIDGE_SAFETY_LAYER
	freeze=true
	driving=false
	show()
	reset_physics_interpolation()

func start_driving() -> void:
	driving=true
	freeze=false

func park() -> void:
	driving=false
	paused_driving=false
	freeze=true
	collision_layer=0
	collision_mask=0
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	hide()
	position=Vector3(0,-30,0)
	reset_physics_interpolation()

func set_paused(value: bool) -> void:
	if value and driving:
		paused_driving=true
		paused_velocity=linear_velocity
		freeze=true
	elif not value and paused_driving:
		paused_driving=false
		freeze=false
		linear_velocity=paused_velocity

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not driving or challenge.game.paused: return
	var dt:=state.step
	var local:=state.transform.origin-ToyRaceTrack.ORIGIN
	_update_progress(local)
	var current:=RaceChallenge.course_pose(course_distance,0)
	var forward: Vector3=-current.basis.z
	var right:=current.basis.x
	var player: Vector3=challenge.game.truck.global_position-ToyRaceTrack.ORIGIN
	var relative:=player-local
	var ahead:=relative.dot(forward)
	var sideways:=relative.dot(right)
	avoiding=ahead>0 and ahead<18 and absf(sideways)<3.8 and absf(player.y-local.y)<2
	if avoiding:
		var player_lane: float=(player-current.origin).dot(right)
		lane_target=3.2 if player_lane<0 else -3.2
		avoid_hold=1.2
	else:
		avoid_hold=maxf(0,avoid_hold-dt)
		if avoid_hold==0: lane_target=-2.4
	lane=move_toward(lane,lane_target,4.5*dt)
	var lookahead:=8.0+Vector2(state.linear_velocity.x,state.linear_velocity.z).length()*.25
	var target_pose:=RaceChallenge.course_pose(course_distance+lookahead,lane)
	var desired: Vector3=target_pose.origin-local
	desired.y=0
	desired=desired.normalized()
	var target_yaw:=atan2(-desired.x,-desired.z)
	yaw=lerp_angle(yaw,target_yaw,1-exp(-5*dt))
	var future:=RaceChallenge.course_pose(course_distance+5,0)
	var turn:=absf(angle_difference(current.basis.get_euler().y,future.basis.get_euler().y))
	var target_speed:=lerpf(MAX_SPEED,CORNER_SPEED,clampf(turn*2.5,0,1))
	# Contact impulses are retained. Acceleration is bounded rather than
	# overwriting the car's trajectory, so a truck can shove it off its line.
	var planar:=Vector3(state.linear_velocity.x,0,state.linear_velocity.z)
	var target_velocity:=desired*target_speed
	planar=planar.move_toward(target_velocity,10.5*dt)
	speed=planar.length()
	var surface:=RaceCourse.surface_at(local+Vector3.UP*.8)
	var pose:=state.transform
	pose.origin.y=ToyRaceTrack.ORIGIN.y+surface.height
	var pitch:=atan(surface.gradient.dot(Vector2(-sin(yaw),-cos(yaw))))
	pose.basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
	state.transform=pose
	state.linear_velocity=Vector3(planar.x,surface.gradient.dot(Vector2(planar.x,planar.z)),planar.z)
	wheel_angle-=speed*dt/.45
	for wheel in wheels: wheel.rotation.x=wheel_angle

func _update_progress(local: Vector3) -> void:
	var path:=RaceCourse.points()
	var count:=path.size()-1
	var best:=INF
	var next_segment:=segment
	var along:=fposmod(course_distance,RaceCourse.distances[-1])
	for offset in range(-16,49):
		var i:=posmod(segment+offset,count)
		var a:=path[i]
		var delta:=path[i+1]-a
		var t:=clampf(Vector2(local.x-a.x,local.z-a.z).dot(Vector2(delta.x,delta.z))/maxf(.001,Vector2(delta.x,delta.z).length_squared()),0,1)
		var nearest:=a.lerp(path[i+1],t)
		var error:=Vector2(local.x-nearest.x,local.z-nearest.z).length_squared()+pow(local.y-nearest.y,2)*3
		if error>=best: continue
		best=error
		next_segment=i
		along=lerpf(RaceCourse.distances[i],RaceCourse.distances[i+1],t)
	var total:=RaceCourse.distances[-1]
	var delta:=along-fposmod(course_distance,total)
	if delta>total*.5: delta-=total
	if delta< -total*.5: delta+=total
	if absf(delta)<20:
		course_distance+=delta
		segment=next_segment
	progress=course_distance-(challenge.start_distance-RaceChallenge.GRID_BACK)

func _build_art() -> void:
	art=Node3D.new()
	art.name="RacerBody"
	add_child(art)
	var red:=Color("cd7058")
	var navy:=Color("405e70")
	var cream:=Color("fff0cf")
	TownProps.box(art,Vector3(0,.55,0),Vector3(2.35,.65,4.3),red)
	TownProps.box(art,Vector3(0,.84,-1.22),Vector3(2.2,.4,1.75),red)
	TownProps.box(art,Vector3(0,1.16,.15),Vector3(1.8,.7,1.6),Color("e4a45e"))
	TownProps.box(art,Vector3(0,1.35,-.66),Vector3(1.64,.48,.10),Color("a3cecf"))
	# Twin cream racing stripes, a low splitter, hood vents and a framed cockpit.
	for x in [-.24,.24]:
		TownProps.box(art,Vector3(x,1.06,-1.28),Vector3(.25,.035,1.45),cream)
		TownProps.box(art,Vector3(x,1.535,.18),Vector3(.25,.035,1.45),cream)
	TownProps.box(art,Vector3(0,.3,-2.18),Vector3(2.65,.14,.42),navy)
	TownProps.box(art,Vector3(0,.58,-2.19),Vector3(1.3,.3,.09),navy)
	for x in [-.45,-.15,.15,.45]: TownProps.box(art,Vector3(x,.58,-2.25),Vector3(.06,.25,.03),Color("8299a1"))
	for side in [-1,1]:
		for z in [-1.45,-1.25,-1.05]: TownProps.box(art,Vector3(side*.84,1.06,z),Vector3(.25,.03,.06),navy)
		TownProps.box(art,Vector3(side*.96,1.15,.15),Vector3(.13,.72,1.85),navy)
		TownProps.box(art,Vector3(side*1.3,.83,.0),Vector3(.28,.13,.4),red)
		TownProps.box(art,Vector3(side*1.27,.27,0),Vector3(.2,.22,3.3),navy)
		TownProps.box(art,Vector3(side*.88,1.1,1.68),Vector3(.16,.7,.18),navy)
		TownProps.box(art,Vector3(side*.81,.52,2.2),Vector3(.34,.2,.1),Color("f0ac69"))
		var exhaust:=TownProps.cylinder(art,Vector3(side*.58,.3,2.23),.12,.32,Color("94a8ae"))
		exhaust.rotation.x=PI/2
		var number:=TownProps.label(art,Vector3(side*1.215,.7,.15),"7",42)
		number.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		number.rotation.y=side*PI/2
		number.pixel_size=.018
	TownProps.box(art,Vector3(0,1.49,1.75),Vector3(2.9,.15,.65),navy)
	for x in [-.7,.7]:
		TownProps.ball(art,Vector3(x,.8,-2.14),Vector3(.4,.25,.1),cream)
		TownProps.box(art,Vector3(x,1.6,1.76),Vector3(.4,.035,.54),cream)
	for x in [-1.2,1.2]:
		for z in [-1.3,1.3]:
			var wheel:=Node3D.new()
			add_child(wheel)
			wheel.position=Vector3(x,.45,z)
			var tire:=TownProps.cylinder(wheel,Vector3.ZERO,.45,.4,Color("374c55"))
			tire.rotation.z=PI/2
			var hub:=TownProps.cylinder(wheel,Vector3(signf(x)*.22,0,0),.28,.065,Color("dca45f"))
			hub.rotation.z=PI/2
			for i in 5:
				var spoke:=TownProps.box(wheel,Vector3(signf(x)*.26,0,0),Vector3(.04,.48,.07),cream)
				spoke.rotation.x=i*TAU/5
			wheels.append(wheel)
	var helmet:=TownProps.ball(art,Vector3(0,1.68,.3),Vector3(.64,.69,.62),navy)
	TownProps.box(art,helmet.position+Vector3(0,-.03,-.29),Vector3(.46,.2,.08),Color("b7d9d6"))
	TownProps.cylinder(art,Vector3(0,1.99,.3),.12,.06,cream)
	TownProps.merge_fixed_geometry(art,[],"quinn_race_car_v2")
	for wheel in wheels: TownProps.merge_fixed_geometry(wheel,[],"quinn_race_wheel_v2_"+str(signf(wheel.position.x)))
