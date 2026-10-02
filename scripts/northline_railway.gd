class_name NorthlineRailway
extends Node3D

const TRACK_Z:=-63.0
const LEFT_END:=-56.0
const RIGHT_END:=56.0
const RESISTANCE:=67.0
var game: Node3D
var engine: RigidBody3D
var driver: Node3D
var driver_guard: StaticBody3D
var wheels: Array[Node3D]=[]
var smoke: Array[Dictionary]=[]
var sound: AudioStreamPlayer3D
var started:=false
var boarded:=false
var briefed:=false
var pushed_once:=false
var push_locked:=false
var push_release_time:=0.0
var hint_pending:=false
var hint_sent:=false
var assist_time:=0.0
var boarding_time:=0.0
var driver_from:=Vector3.ZERO
var wait:=0.0
var direction:=1.0
var clock:=0.0
var puff_clock:=0.0
var chuff_clock:=0.0
var crossings: Array[MeshInstance3D]=[]

func _ready() -> void:
	name="NorthlineRailway"
	_clear_corridor()
	var tracks:=Node3D.new()
	add_child(tracks)
	TownProps.box(tracks,Vector3(0,.045,TRACK_Z),Vector3(138,.08,3.4),Color("9e9d87"))
	for z in [-.98,.98]: TownProps.box(tracks,Vector3(0,.13,TRACK_Z+z),Vector3(138,.12,.13),Color("667d83"))
	for x in range(-68,69,2):
		TownProps.box(tracks,Vector3(x,.085,TRACK_Z),Vector3(.30,.09,2.7),Color("857461"))
	for x in [-36,0,36]:
		TownProps.box(tracks,Vector3(x,.07,TRACK_Z),Vector3(8,.05,7),Color("7c8984"))
		for side in [-1,1]:
			var p:=Vector3(x+side*5,.0,TRACK_Z+3.0)
			TownProps.cylinder(tracks,p+Vector3.UP*1.1,.085,2.2,Color("eaf4ef"))
			var cross:=TownProps.box(tracks,p+Vector3.UP*2.2,Vector3(.12,.16,1.25),Color("eaf4ef"))
			cross.rotation.x=.65
			cross=TownProps.box(tracks,p+Vector3.UP*2.2,Vector3(.12,.16,1.25),Color("eaf4ef"))
			cross.rotation.x=-.65
			crossings.append(TownProps.ball(self,p+Vector3.UP*1.75,Vector3(.20,.20,.20),Color("e78970")))
	for child in tracks.get_children():
		if child is MeshInstance3D: child.set_meta("batch_static",true)
	TownProps.batch_decorations(tracks)
	engine=RigidBody3D.new()
	engine.name="NorthlineLocomotive"
	engine.mass=18
	engine.gravity_scale=0
	engine.collision_layer=2
	engine.collision_mask=19
	engine.axis_lock_linear_y=true
	engine.axis_lock_linear_z=true
	engine.lock_rotation=true
	engine.can_sleep=false
	engine.contact_monitor=true
	engine.max_contacts_reported=4
	engine.continuous_cd=true
	engine.linear_damp=.25
	add_child(engine)
	engine.position=Vector3(-14,.12,TRACK_Z)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(8.8,3.1,2.5)
	shape.shape=box
	shape.position.y=1.6
	engine.add_child(shape)
	_make_engine()
	driver=TownProps.person(self,engine.position+Vector3(-2.5,-.12,5.7),Color("7199ad"))
	driver.name="RowanTheDriver"
	TownProps.cylinder(driver,Vector3(0,2.55,0),.50,.20,Color("365868"))
	TownProps.box(driver,Vector3(0,2.47,-.28),Vector3(.65,.06,.35),Color("365868"))
	for x in [-.10,.10]: TownProps.ball(driver,Vector3(x,1.78,-.42),Vector3(.23,.075,.055),Color("694f3f"))
	driver_guard=game.interactions._visibility_guard("RailwayDriverSpace",driver.position)
	sound=AudioStreamPlayer3D.new()
	sound.stream=_chuff()
	sound.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	sound.volume_db=-23
	sound.max_distance=50
	sound.unit_size=9
	engine.add_child(sound)
	for i in 20:
		var cloud:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		cloud.mesh=quad
		cloud.material_override=TownProps.effect_material(preload("res://shaders/smoke.gdshader"))
		cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)
		cloud.hide()
		smoke.append({"mesh":cloud,"age":5.0,"velocity":Vector3.ZERO})

func _clear_corridor() -> void:
	var driver_spot:=Vector3(-16.5,0,TRACK_Z+5.7)
	for prop in game.interactions.props:
		if absf(prop.position.x)>70 or (absf(prop.position.z-TRACK_Z)>4.8 and prop.position.distance_to(driver_spot)>11): continue
		# Place displaced scenery behind the line with room between canopies.
		var relocated:=false
		for attempt in 20:
			var candidate:=Vector3(-72+attempt*7.5,0,-74.5)
			var clear:=true
			for other in game.interactions.props:
				if other!=prop and other.position.distance_to(candidate)<6.5: clear=false; break
			if not clear: continue
			prop.position=candidate
			relocated=true
			break
		if not relocated: prop.position.z=-49
		prop.home=prop.global_transform
		prop.reset_physics_interpolation()

func _make_engine() -> void:
	var teal:=Color("528d94")
	var dark:=Color("365868")
	var brass:=Color("d9b579")
	TownProps.box(engine,Vector3(0,.95,0),Vector3(8.8,.45,2.9),dark)
	TownProps.box(engine,Vector3(-2.8,1.6,0),Vector3(2.6,1.1,2.7),teal)
	for z in [-1.28,1.28]:
		TownProps.box(engine,Vector3(-2.8,1.92,z),Vector3(2.4,.64,.18),teal)
		TownProps.box(engine,Vector3(-2.8,3.31,z),Vector3(2.4,.20,.18),teal)
		for x in [-3.9,-1.7]:
			TownProps.box(engine,Vector3(x,2.72,z),Vector3(.20,1.3,.18),teal)
		TownProps.box(engine,Vector3(-2.8,2.70,signf(z)*1.40),Vector3(1.8,.94,.035),Color("b2d9dd"))
	TownProps.box(engine,Vector3(-3.95,2.5,0),Vector3(.18,1.8,2.5),teal)
	TownProps.box(engine,Vector3(-2.8,3.52,0),Vector3(2.9,.24,3.05),dark)
	var boiler:=TownProps.cylinder(engine,Vector3(.65,2.05,0),.95,4.6,teal)
	boiler.rotation.z=PI/2
	for x in [-.8,1.5]:
		var band:=TownProps.cylinder(engine,Vector3(x,2.05,0),.975,.12,brass)
		band.rotation.z=PI/2
	TownProps.cylinder(engine,Vector3(2.15,3.18,0),.25,1.2,dark,.36)
	TownProps.cylinder(engine,Vector3(-.3,3.04,0),.38,.5,brass)
	var front:=TownProps.cylinder(engine,Vector3(3.01,2.05,0),.86,.20,dark)
	front.rotation.z=PI/2
	TownProps.ball(engine,Vector3(3.2,2.5,0),Vector3(.24,.38,.38),Color("fff0ba"))
	TownProps.box(engine,Vector3(4.12,.72,0),Vector3(.65,.65,2.75),Color("cf8471"))
	TownProps.box(engine,Vector3(-4.42,.7,0),Vector3(.23,.32,2.5),Color("cf8471"))
	for z in [-.92,.92]:
		TownProps.box(engine,Vector3(-4.6,.66,z),Vector3(.22,.30,.40),brass)
	for side in [-1,1]:
		for x in [-3.2,-1.6,.4,2.4]:
			var wheel:=Node3D.new()
			engine.add_child(wheel)
			wheel.position=Vector3(x,.48,side*1.34)
			var tire:=TownProps.cylinder(wheel,Vector3.ZERO,.48,.19,dark)
			tire.rotation.x=PI/2
			var hub:=TownProps.cylinder(wheel,Vector3(0,0,side*.12),.32,.025,brass)
			hub.rotation.x=PI/2
			for a in [0,PI/3,PI*2/3]:
				var spoke:=TownProps.box(wheel,Vector3(0,0,side*.145),Vector3(.07,.70,.035),dark)
				spoke.rotation.z=a
			wheels.append(wheel)
		TownProps.box(engine,Vector3(-.4,.5,side*1.52),Vector3(6,.10,.10),brass)
	var nameplate:=TownProps.label(engine,Vector3(-2.8,1.7,1.4),"NORTHLINE  07",48)
	nameplate.font=preload("res://assets/fonts/Nunito.ttf")
	nameplate.pixel_size=.007
	nameplate.billboard=BaseMaterial3D.BILLBOARD_DISABLED

func talk_to_driver(manual: bool=false) -> bool:
	if boarded or boarding_time>0 or game.paused: return false
	if not manual and briefed: return false
	briefed=true
	var words:="Morning! Northline's engine has stalled. Could you give the back bumper a little push? The track runs east, so push me that way."
	if pushed_once:
		words="She's too heavy for driving alone. Keep pushing the rear bumper, and spray your water cannon backwards, away from the train. The recoil should give you enough extra shove!"
		hint_sent=true
	game.talk("ROWAN  /  NORTHLINE",words,game.stage)
	return true

func guide_push(desired: Vector3, dt: float) -> Vector3:
	push_release_time=maxf(0,push_release_time-dt)
	if started or game.paused: push_locked=false; return desired
	var truck: FireEngine=game.truck
	var local:=truck.position-engine.position
	var behind:=local.x< -4.0 and local.x> -8.0 and absf(local.z)<2.2 and truck.grounded
	# Input is camera-relative at the controls, but the lock uses the actual
	# requested world direction. A deliberate right-angle turn releases it.
	if push_locked and desired.length()>.1 and desired.x<=.00001:
		push_locked=false
		push_release_time=.6
	if not behind: push_locked=false
	if not push_locked and behind and push_release_time==0 and desired.x>.1 and engine.get_colliding_bodies().has(truck): push_locked=true
	if not push_locked: return desired
	var correction:=clampf(-local.z*5-truck.linear_velocity.z*3,-5,5)
	truck.apply_central_force(Vector3(0,0,correction*truck.mass))
	return Vector3.RIGHT*desired.length()

func _physics_process(dt: float) -> void:
	engine.freeze=game.paused
	sound.stream_paused=game.paused
	if game.paused or game.loading: return
	clock+=dt
	driver_guard.rotation.y=atan2(game.camera.global_basis.z.x,game.camera.global_basis.z.z)
	if not started:
		var velocity:=engine.linear_velocity.x
		engine.apply_central_force(Vector3(-signf(velocity)*minf(absf(velocity)*engine.mass/maxf(dt,.001),RESISTANCE),0,0))
		var local: Vector3=game.truck.position-engine.position
		var rear_contact:=local.x< -4.2 and local.x> -7.5 and absf(local.z)<1.55 and engine.get_colliding_bodies().has(game.truck)
		var pushing: bool=rear_contact and (game.truck.linear_velocity.x>.1 or game.truck.drive_input().length()>.2)
		if pushing:
			pushed_once=true
			if not hint_sent: hint_pending=true
		var recoil_push: bool=game.truck.spraying and game.truck.spray_direction.x<-.55
		if pushing and recoil_push and velocity>.18:
			assist_time+=dt
		else: assist_time=maxf(0,assist_time-dt*1.5)
		if hint_pending and not game.dialogue_active and not hint_sent:
			hint_pending=false
			talk_to_driver(true)
		elif hint_pending and game.dialogue_actor==driver and game.hud.char_count==game.hud.full_text.length():
			game.end_dialogue()
		if assist_time>=1.0: _start_engine()
	else:
		if not boarded:
			boarding_time+=dt
			var door: Vector3=engine.position+Vector3(-2.9,.12,1.65)
			driver.position=driver_from.lerp(door,smoothstep(0,1,clampf((boarding_time-.65)/1.3,0,1)))
			driver.position.y+=sin(clampf((boarding_time-1.6)/.6,0,1)*PI)*.65
			if boarding_time>=2.4:
				boarded=true
				driver.hide()
				if game.dialogue_actor==driver: game.end_dialogue()
				var seated:=TownProps.person(engine,Vector3(-2.6,1.5,.9),Color("7199ad"))
				seated.scale=Vector3.ONE*.48
		else:
			wait=maxf(0,wait-dt)
			if wait==0 and (engine.position.x>RIGHT_END and direction>0 or engine.position.x<LEFT_END and direction<0):
				wait=4.5
				direction=-direction
		var desired:=direction*3.6 if boarded and wait==0 else .45 if not boarded else 0.0
		engine.apply_central_force(Vector3((desired-engine.linear_velocity.x)*engine.mass*2.6,0,0))
		puff_clock-=dt
		if puff_clock<=0:
			puff_clock=.25 if absf(engine.linear_velocity.x)>.8 else .48
			_puff()
		chuff_clock-=dt
		if chuff_clock<=0:
			chuff_clock=.6 if absf(engine.linear_velocity.x)>.8 else 1.0
			if DisplayServer.get_name()!="headless": sound.play()
	for wheel in wheels: wheel.rotation.z-=engine.linear_velocity.x*dt/.48
	for light in crossings:
		light.material_override=TownProps.material(Color("ef927b") if started and wait==0 and sin(clock*6)>0 else Color("925d53"),started and wait==0)
	for cloud in smoke:
		cloud.age+=dt
		if cloud.age>2.8: cloud.mesh.hide(); continue
		cloud.mesh.position+=cloud.velocity*dt
		cloud.mesh.look_at(game.camera.global_position)
		cloud.mesh.scale=Vector3.ONE*(.55+cloud.age*1.05)
		TownProps.effect_opacity(cloud.mesh,.64*(1-cloud.age/2.8))
		cloud.mesh.show()

func _start_engine() -> void:
	started=true
	push_locked=false
	boarding_time=.001
	driver_from=driver.position
	driver_guard.collision_layer=0
	if game.dialogue_active and game.dialogue_actor==driver: game.end_dialogue()
	game.rewards.sparkle_burst(engine.position+Vector3.UP*2,22,2.5)
	if DisplayServer.get_name()!="headless": game.rewards.sound.play()
	game.talk("ROWAN  /  NORTHLINE","There she goes! Thanks! I'll keep Northline rolling. Mind the tracks!",game.stage)
	_puff()

func _puff() -> void:
	for cloud in smoke:
		if cloud.age<2.8: continue
		cloud.age=0
		cloud.mesh.position=engine.position+Vector3(2.15,3.85,0)
		cloud.velocity=Vector3(-engine.linear_velocity.x*.15,1.2,.3)
		break

func _chuff() -> AudioStreamWAV:
	var wav:=AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=22050
	var bytes:=PackedByteArray()
	bytes.resize(6615*2)
	var rng:=RandomNumberGenerator.new()
	rng.seed=713
	var low:=0.0
	for i in 6615:
		var t:=float(i)/wav.mix_rate
		low=lerpf(low,rng.randf_range(-1,1),.16)
		var value: float=(low*.8+sin(t*TAU*90)*.13)*sin(PI*t/.3)*exp(-t*6)
		bytes.encode_s16(i*2,int(value*20000))
	wav.data=bytes
	return wav
