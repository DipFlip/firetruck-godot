class_name JobRewards
extends Node3D

const THANK_YOU_DELAY := 1.8
var game: Node3D
var pending: Array[Dictionary] = []
var sparkles: Array[Dictionary] = []
var completed: Dictionary = {}
var sound: AudioStreamPlayer

func _ready() -> void:
	sound=AudioStreamPlayer.new()
	sound.stream=_chime()
	sound.volume_db=-15
	add_child(sound)

func celebrate(job: String, at: Vector3, speaker: String, words: String) -> void:
	if completed.has(job): return
	completed[job]=true
	if game.dialogue_active and game.hud.speaker_key==speaker: game.end_dialogue()
	pending.append({"speaker":speaker,"words":words,"remaining":THANK_YOU_DELAY})
	if DisplayServer.get_name()!="headless": sound.play()
	for i in 28:
		var star:=MeshInstance3D.new()
		var mesh:=ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in 8:
			var a:=j*TAU/8
			var b:=(j+1)*TAU/8
			mesh.surface_add_vertex(Vector3.ZERO)
			mesh.surface_add_vertex(Vector3(cos(a),sin(a),0)*(.22 if j%2==0 else .065))
			mesh.surface_add_vertex(Vector3(cos(b),sin(b),0)*(.22 if (j+1)%2==0 else .065))
		mesh.surface_end()
		star.mesh=mesh
		var mat:=TownProps.material([Color("fff0ad"),Color("b2fff2"),Color("ffffff")][i%3],true).duplicate() as StandardMaterial3D
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		star.material_override=mat
		star.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(star)
		var angle:=i*TAU/28
		var radius:=1.1 if job!="pool" else 3.4
		star.position=at+Vector3(cos(angle)*radius,.25+float(i%4)*.22,sin(angle)*radius*(.55 if job=="pool" else 1.0))
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
			s.mesh.queue_free()
			sparkles.remove_at(i)
	for reward in pending: reward.remaining=maxf(0,reward.remaining-dt)
	if game.dialogue_active or game.rescue_running: return
	for i in pending.size():
		var reward:=pending[i]
		var index: int={"LEO":1,"JUNE":2,"OLIVER":3}[reward.speaker]
		if reward.remaining>0 or game.truck.global_position.distance_to(game.town.people[index].global_position)>9: continue
		game.talk(reward.speaker+"  /  THANK YOU",reward.words,game.stage)
		game.proximity_latches[index]=true
		pending.remove_at(i)
		break

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
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	result.data=bytes
	return result
