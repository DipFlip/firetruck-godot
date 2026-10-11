class_name RaceAwards
extends Node3D

const PODIUM:=Vector3(-43,0,-4)
const ANNOUNCEMENT:="Well, everyone, we've got a new champion of the Motorway Race Club. It's our hero and now our race champion, Fire Truck!"
var challenge: RaceChallenge
var game: Node3D
var race: ToyRaceTrack
var active:=false
var won:=false
var clock:=0.0
var closing:=false
var close_clock:=0.0
var placed:=false
var announced:=false
var troupe: Node3D
var reporter: Node3D
var operator: Node3D
var tv_camera: Node3D
var confetti: MultiMeshInstance3D
var confetti_states: Array[Dictionary]=[]
var actor_poses: Array[Dictionary]=[]
var camera_from:=Transform3D.IDENTITY
var lens_from:=25.8
var broadcast_pose:=Transform3D.IDENTITY
var operator_pose:=Transform3D.IDENTITY

func _ready() -> void:
	name="VictoryCeremony"
	set_meta("assembly_ignore",true)
	troupe=Node3D.new()
	add_child(troupe)
	reporter=race._person(troupe,PODIUM+Vector3(1.5,0,7.6),Color("739dae"))
	reporter.name="Reporter"
	TownProps.cylinder(reporter,Vector3(.6,1.7,-.3),.075,.38,Color("374c55"))
	TownProps.ball(reporter,Vector3(.6,1.94,-.3),Vector3.ONE*.23,Color("405e70"))
	operator=race._person(troupe,PODIUM+Vector3(5.3,0,13),Color("6d9cb2"),false,true)
	tv_camera=Node3D.new()
	troupe.add_child(tv_camera)
	tv_camera.position=PODIUM+Vector3(5.3,0,11.8)
	for i in 3:
		var end:=Vector3(sin(i*TAU/3)*.85,.05,cos(i*TAU/3)*.85)
		var top:=Vector3(0,2.2,0)
		var leg:=TownProps.cylinder(tv_camera,(top+end)*.5,.07,top.distance_to(end),Color("536872"))
		leg.quaternion=Quaternion(Vector3.UP,(end-top).normalized())
	var head:=Node3D.new()
	head.name="FilmCameraHead"
	tv_camera.add_child(head)
	head.position=Vector3(0,2.4,0)
	TownProps.box(head,Vector3.ZERO,Vector3(.85,.75,1.4),Color("5b727b"))
	var lens:=TownProps.cylinder(head,Vector3(0,0,-.85),.28,.55,Color("364c58"))
	lens.rotation.x=PI/2
	TownProps.ball(head,Vector3(.4,.32,-.64),Vector3.ONE*.12,Color("ed8065"))
	TownProps.box(head,Vector3(-.55,.18,.3),Vector3(.24,.35,.5),Color("364c58"))
	TownProps.merge_fixed_geometry(tv_camera,[head],"ceremony_tv_tripod")
	TownProps.merge_fixed_geometry(head,[],"ceremony_tv_head")
	_build_confetti()
	troupe.hide()

func start(victory: bool) -> void:
	won=victory
	active=true
	clock=0
	placed=false
	announced=false
	closing=false
	close_clock=0
	camera_from=game.camera.global_transform
	lens_from=game.camera.size
	broadcast_pose=race.broadcast_head.transform
	operator_pose=race.camera_operator.transform
	actor_poses.clear()
	for actor in race.people:
		actor_poses.append({"actor":actor,"transform":actor.transform,"visible":actor.visible,"right":actor.get_node("ArmRight").rotation,"left":actor.get_node("ArmLeft").rotation})
	game.end_dialogue()
	game.truck.enabled=false
	game.truck.freeze=true
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO
	game.truck.spraying=false
	game.truck.spray_requested=false
	game.truck.charge=0
	game.hud.map_open=false
	game.hud.toast_label.text=""
	game.toast_time=0
	challenge.opponent.park()

func update(dt: float) -> void:
	if not active or game.paused: return
	clock+=dt
	if closing:
		close_clock+=dt
		challenge.fade.color.a=smoothstep(0,.3,close_clock)*(1-smoothstep(.35,.7,close_clock))
		if close_clock>=.3 and placed:
			_restore_scene()
			placed=false
		if close_clock>=.7:
			active=false
			challenge.result_open=false
			challenge.overlay.hide()
			game.truck.freeze=false
			game.truck.enabled=true
			game.truck.input_blocked_until_release=true
			game.truck.jump_blocked_until_release=true
		return
	challenge.fade.color.a=smoothstep(0,.3,clock)*(1-smoothstep(.4,.75,clock))
	if clock>=.35 and not placed: _place_scene()
	if clock>=1.35 and not announced:
		announced=true
		if won:
			game.talk("REPORTER  /  MOTORWAY TV",ANNOUNCEMENT,game.stage,true)
			game.sounds.play("cheer",ToyRaceTrack.ORIGIN+PODIUM,1.0,0)
		else:
			game.talk("QUINN  /  PODIUM RACER","Well, better luck next time! Come back anytime and challenge me again.",game.stage,true)
	if announced and not game.dialogue_active: finish()

func finish() -> void:
	if not active or closing: return
	closing=true
	close_clock=0
	if game.dialogue_active: game.end_dialogue()
	game.truck.freeze=true
	game.truck.enabled=false

func cancel() -> void:
	if active:
		if game.dialogue_active: game.end_dialogue()
		_restore_scene()
	active=false
	closing=false
	troupe.hide()

func _place_scene() -> void:
	placed=true
	game.truck.reset_truck()
	game.truck.global_position=ToyRaceTrack.ORIGIN+PODIUM+Vector3(0,2.755,0) if won else ToyRaceTrack.ORIGIN+PODIUM+Vector3(0,.855,6)
	game.truck.heading=PI
	game.truck.rotation.y=PI
	game.truck.reset_physics_interpolation()
	game.camera_subject=null
	game.camera_requested_subject=null
	game.camera_framing.reset()
	game.conversation_blend=0
	game.conversation_pan=0
	race.people[RaceChallenge.NPC_INDEX].show()
	if won:
		if DisplayServer.get_name()!="headless": game.rewards.sound.play()
		troupe.show()
		for i in race.people.size():
			var actor:=race.people[i]
			actor.show()
			actor.position=PODIUM+([Vector3(-4,1.2,.8),Vector3(6,0,.8),Vector3(-6,0,2.4),Vector3(-4,1.2,-.8)][i] as Vector3)
			actor.rotation.y=PI
		var head: Node3D=tv_camera.get_node("FilmCameraHead")
		head.look_at(reporter.global_position+Vector3.UP*1.7)
		race.broadcast_head.look_at(reporter.global_position+Vector3.UP*1.7)
		race.camera_operator.look_at(reporter.global_position)
		operator.look_at(reporter.global_position)
		for arm in ["ArmLeft","ArmRight"]: operator.get_node(arm).rotation=Vector3(2,0,.12 if arm=="ArmRight" else -.12)
		reporter.rotation.y=atan2(-(tv_camera.position.x-reporter.position.x),-(tv_camera.position.z-reporter.position.z))

func _restore_scene() -> void:
	troupe.hide()
	race.broadcast_head.transform=broadcast_pose
	race.camera_operator.transform=operator_pose
	for state in actor_poses:
		state.actor.transform=state.transform
		state.actor.visible=state.visible
		state.actor.get_node("ArmRight").rotation=state.right
		state.actor.get_node("ArmLeft").rotation=state.left
	race.people[RaceChallenge.NPC_INDEX].show()
	race.chatter_latches[RaceChallenge.NPC_INDEX]=true
	game.truck.global_position=ToyRaceTrack.ORIGIN+PODIUM+Vector3(0,.855,6)
	game.truck.reset_physics_interpolation()
	game.camera_subject=null
	game.camera_requested_subject=null
	game.camera_focus=game.truck.global_position
	game.camera.global_position=game.camera_focus+game.gameplay_camera_offset()
	game.camera.look_at(game.camera_focus)
	game.camera.size=25.8
	game.camera.v_offset=0

func podium_screen_rect(camera: Camera3D) -> Rect2:
	var bounds:=Rect2(camera.unproject_position(ToyRaceTrack.ORIGIN+PODIUM),Vector2.ZERO)
	for x in [-6.5,6.5]:
		for y in [0,5.5]:
			for z in [-3.5,3.5]:
				bounds=bounds.expand(camera.unproject_position(ToyRaceTrack.ORIGIN+PODIUM+Vector3(x,y,z)))
	return bounds.grow(8)

func frame(_dt: float) -> void:
	if not active or closing and close_clock>=.3: return
	var focus:=ToyRaceTrack.ORIGIN+PODIUM+Vector3(0,2,4)
	var offset:=Vector3(15,16,29).normalized()*160
	var target:=Transform3D(Basis.IDENTITY,focus+offset).looking_at(focus)
	var blend:=smoothstep(.3,1.25,clock)
	game.camera.global_transform=camera_from.interpolate_with(target,blend)
	var aspect: float=game.hud.size.x/maxf(1,game.hud.size.y)
	game.camera.size=lerpf(lens_from,maxf(25,25/maxf(.6,aspect)),blend)
	game.camera.v_offset=0
	game.camera.far=500
	game.camera_focus=focus

func animate(dt: float) -> void:
	if not active or not won or not placed or game.paused or closing: return
	for i in race.people.size():
		var actor:=race.people[i]
		var clap:=.5+.5*sin(clock*12+i*.7)
		actor.get_node("ArmLeft").rotation=Vector3(1.35,0,lerpf(.28,.65,clap))
		actor.get_node("ArmRight").rotation=Vector3(1.35,0,-lerpf(.28,.65,clap))
		var cheering:=1-smoothstep(1.05,1.35,clock)
		actor.position.y=(1.2 if i in [0,3] else 0.0)+maxf(0,sin(clampf((clock-.4)/.65,0,1)*PI))*.55
		actor.get_node("ArmLeft").rotation=actor.get_node("ArmLeft").rotation.lerp(Vector3(0,0,-2.65),cheering)
		actor.get_node("ArmRight").rotation=actor.get_node("ArmRight").rotation.lerp(Vector3(0,0,2.65),cheering)
		race.actor_rigs[actor].head.rotation.x=.04*sin(clock*3+i)
	reporter.get_node("ArmRight").rotation=Vector3(.8,0,.35)
	for i in confetti_states.size():
		var piece:=confetti_states[i]
		piece.age+=dt
		if piece.age>4.5: piece.age-=4.5
		var t: float=piece.age
		var p: Vector3=piece.home+piece.velocity*t+Vector3(0,-.55*t*t,0)
		p.x+=sin(t*4+float(i))*.45
		var basis:=Basis.from_euler(Vector3(t*3+float(i),t*2,t*4))
		confetti.multimesh.set_instance_transform(i,Transform3D(basis,p))

func _build_confetti() -> void:
	confetti=MultiMeshInstance3D.new()
	troupe.add_child(confetti)
	confetti.name="ChampionshipConfetti"
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(.12,.025,.24)
	var paint:=StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo=true
	paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material=paint
	var batch:=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true
	batch.mesh=mesh
	batch.instance_count=96
	var rng:=RandomNumberGenerator.new()
	rng.seed=7407
	for i in 96:
		var home:=PODIUM+Vector3(rng.randf_range(-5,5),rng.randf_range(6,10),rng.randf_range(-2,7))
		confetti_states.append({"home":home,"velocity":Vector3(rng.randf_range(-.7,.7),-.8,rng.randf_range(-.6,.6)),"age":rng.randf_range(0,4.5)})
		batch.set_instance_transform(i,Transform3D(Basis.IDENTITY,home))
		batch.set_instance_color(i,[Color("ec806c"),Color("efc671"),Color("76b9c4"),Color("fff0cf")][i%4])
	confetti.multimesh=batch
	confetti.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
