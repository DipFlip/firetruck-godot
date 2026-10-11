class_name JobRewards
extends Node3D

const THANK_YOU_DELAY := 1.8
var game: Node3D
var pending: Array[Dictionary] = []
var sparkles: Array[Dictionary] = []
var completed: Dictionary = {}
var sound: AudioStreamPlayer
var star_pool: Array[MeshInstance3D]=[]
var free_stars: Array[MeshInstance3D]=[]

func _ready() -> void:
	sound=AudioStreamPlayer.new()
	sound.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	sound.stream=_chime()
	sound.volume_db=-15
	add_child(sound)

	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 8:
		var a:=j*TAU/8
		var b:=(j+1)*TAU/8
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(cos(a),sin(a),0)*(.22 if j%2==0 else .065))
		mesh.surface_add_vertex(Vector3(cos(b),sin(b),0)*(.22 if (j+1)%2==0 else .065))
	mesh.surface_end()
	var colors: Array[Material]=[]
	for color in [Color("fff0ad"),Color("b2fff2"),Color("ffffff")]:
		var mat:=TownProps.material(color,true).duplicate() as StandardMaterial3D
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		colors.append(mat)
	for i in 84:
		var star:=MeshInstance3D.new()
		star.mesh=mesh
		star.material_override=colors[i%3]
		star.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.hide()
		add_child(star)
		star_pool.append(star)
		free_stars.append(star)

func celebrate(job: String, at: Vector3, speaker: String, words: String, animate_actor: bool=true) -> void:
	if completed.has(job): return
	completed[job]=true
	var actor: Node3D
	var race_job: bool=game.travel and game.travel.in_race
	if race_job:
		actor=game.travel.race.people[ToyRaceTrack.NAMES.find(speaker)]
	elif speaker=="ROWAN": actor=game.railway.driver
	else:
		actor=game.town.people[{"MAYA":0,"LEO":1,"JUNE":2,"OLIVER":3}[speaker]]
	pending.append({"speaker":speaker,"words":words,"actor":actor,"race":race_job,"remaining":THANK_YOU_DELAY,"started":false,"animate":animate_actor,"job":job})
	if pending.size()==1: _begin_reward(pending[0])
	sparkle_burst(at,28,3.4 if job=="pool" else 1.1,.55 if job=="pool" else 1.0)

func controls_locked() -> bool:
	return not pending.is_empty() and pending[0].race==game.travel.in_race

func _begin_reward(reward: Dictionary) -> void:
	reward.started=true
	# Queue first, so closing an existing speech bubble retains the input lock.
	if game.dialogue_active: game.end_dialogue(true)
	game.dialogue_control.begin(true)
	game.camera_subject=reward.actor
	game._set_conversation_camera(true)
	if reward.animate:
		reward.home_y=reward.actor.position.y
		reward.left=reward.actor.get_node("ArmLeft").rotation
		reward.right=reward.actor.get_node("ArmRight").rotation
		reward.actor.set_meta("mission_celebrating",true)
	if DisplayServer.get_name()!="headless": sound.play()
	if reward.job=="dog": game.sounds.play("woof",game.town.dog.global_position,1.0,2.0)

func _pose_celebration(reward: Dictionary) -> void:
	if not reward.animate: return
	var age: float=THANK_YOU_DELAY-reward.remaining
	var lift:=smoothstep(0,.2,age)*(1-smoothstep(1.35,THANK_YOU_DELAY,age))
	# Two little hops, with a soft landing before the speech begins.
	var hop:=maxf(0,sin(clampf((age-.15)/.55,0,1)*PI))
	hop+=maxf(0,sin(clampf((age-.8)/.55,0,1)*PI))*.72
	reward.actor.position.y=reward.home_y+hop*.65
	reward.actor.get_node("ArmLeft").rotation=(reward.left as Vector3).lerp(Vector3(0,0,-2.65),lift)
	reward.actor.get_node("ArmRight").rotation=(reward.right as Vector3).lerp(Vector3(0,0,2.65),lift)
	if reward.remaining==0:
		reward.actor.position.y=reward.home_y
		reward.actor.remove_meta("mission_celebrating")

func sparkle_burst(at: Vector3, count: int=12, radius: float=1.1, squash: float=1.0) -> void:
	for i in count:
		if free_stars.is_empty(): break
		var star:=free_stars.pop_back() as MeshInstance3D
		star.scale=Vector3.ONE*.001
		star.show()
		var angle:=i*TAU/count
		star.position=at+Vector3(cos(angle)*radius,.25+float(i%4)*.22,sin(angle)*radius*squash)
		sparkles.append({"mesh":star,"age":-float(i%5)*.045,"velocity":Vector3(cos(angle)*.7,1.15+float(i%3)*.2,sin(angle)*.7),"spin":angle})

func waiting_for(speaker: String) -> bool:
	for reward in pending:
		if reward.speaker==speaker: return true
	return false

func playing_reward() -> bool:
	for reward in pending:
		if reward.remaining>0: return true
	return false

func _exit_tree() -> void:
	sound.stop()
	sound.stream=null

func _process(dt: float) -> void:
	sound.stream_paused=game.paused
	if game.paused: return
	for i in range(sparkles.size()-1,-1,-1):
		var s:=sparkles[i]
		s.age+=dt
		if s.age<0: s.mesh.hide(); continue
		s.mesh.show()
		s.mesh.position+=s.velocity*dt
		s.mesh.look_at(game.camera.global_position)
		s.mesh.rotate_object_local(Vector3.FORWARD,s.spin+s.age*1.5)
		s.mesh.scale=Vector3.ONE*maxf(.001,sin(clampf(s.age/1.65,0,1)*PI))
		if s.age>=1.65:
			s.mesh.hide()
			free_stars.append(s.mesh)
			sparkles.remove_at(i)
	if not controls_locked() or game.rescue_running: return
	var reward:=pending[0]
	if not reward.started:
		if game.dialogue_active: return
		_begin_reward(reward)
	reward.remaining=maxf(0,reward.remaining-dt)
	_pose_celebration(reward)
	if reward.remaining>0 or game.dialogue_active: return
	pending.pop_front()
	game.talk(reward.speaker+"  /  THANK YOU",reward.words,game.stage,true)
	if reward.race:
		game.travel.race.chatter_latches[ToyRaceTrack.NAMES.find(reward.speaker)]=true
	elif reward.speaker!="ROWAN":
		game.proximity_latches[{"MAYA":0,"LEO":1,"JUNE":2,"OLIVER":3}[reward.speaker]]=true

func _chime() -> AudioStreamWAV:
	var result:=AudioStreamWAV.new()
	result.format=AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate=22050
	var bytes:=PackedByteArray()
	bytes.resize(int(1.5*22050)*2)
	for i in bytes.size()/2:
		var t:=float(i)/22050
		var sample:=0.0
		for n in 4:
			var age:=t-n*.14
			if age<0: continue
			var frequency: float=[659.25,830.61,987.77,1318.51][n]
			var envelope:=minf(age/.007,1)*exp(-age*5.5)
			sample+=(sin(age*TAU*frequency)+.22*sin(age*TAU*frequency*2))*envelope*.19
		sample*=smoothstep(0.0,.012,t)*(1-smoothstep(1.22,1.5,t))
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	result.data=bytes
	return result
