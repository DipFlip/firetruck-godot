class_name TownAudio
extends Node

# One reusable bank for quiet, varied local Foley. No per-particle audio nodes
# or sample generation in the frame loop, including the browser build.
const LEVELS:={"bird":-25.0,"dodge":-22.0,"woof":-21.0,"meow":-23.0,"wood":-18.0,"fence":-21.0,"metal":-22.0,"brick":-19.0,"bush":-28.0,"car_bump":-20.0,"splash":-20.0,"clean":-22.0,"honk":-24.0,"chuff":-25.0,"whistle":-25.0,"refill":-25.0,"fire_sizzle":-24.0}
var game: Node3D
var bank: Dictionary={}
var players: Array[AudioStreamPlayer]=[]
var ringtone: AudioStreamPlayer
var rng:=RandomNumberGenerator.new()
var time:=0.0
var last: Dictionary={}
var counts: Dictionary={}
var was_ringing:=false
var truck_velocity:=Vector3.ZERO
var in_pool:=false
var cat_time:=4.0
var loops: Dictionary={}
var loop_levels: Dictionary={"refill":0.0,"fire_sizzle":0.0}
var loop_active: Dictionary={"refill":false,"fire_sizzle":false}
var fire_contact_until:=-1.0

func _ready() -> void:
	name="TownAudio"
	rng.randomize()
	process_physics_priority=-30
	for kind in LEVELS.keys()+["voice"]:
		var variants: Array[AudioStreamWAV]=[]
		for i in 3: variants.append(load("res://assets/audio/town/%s_%d.wav" % [kind,i]))
		bank[kind]=variants
	for i in 12:
		var player:=AudioStreamPlayer.new()
		player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		players.append(player)
	ringtone=AudioStreamPlayer.new()
	ringtone.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	ringtone.stream=load("res://assets/audio/town/ringtone_0.wav")
	ringtone.volume_db=-24
	add_child(ringtone)
	for kind in ["refill","fire_sizzle"]:
		var player:=AudioStreamPlayer.new()
		player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		player.volume_db=-80
		add_child(player)
		loops[kind]=player
	# Baked houses retain editable box colliders even though their art is batched.
	for building in game.town.get_children():
		for child in building.get_children():
			if child is StaticBody3D:
				for shape in child.get_children():
					if shape is CollisionShape3D and shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(Vector3(8,5,6)): child.add_to_group("masonry_collision")
	game.truck.body_entered.connect(_truck_contact)

func play(kind: String, at: Vector3, strength: float=1.0, cooldown: float=.18) -> bool:
	if game.paused or not bank.has(kind): return false
	var listener: Vector3=game.truck.global_position
	if game.intro and game.intro.active: listener=game.camera.position-game.camera.global_basis.z*game.camera.position.distance_to(at)
	var distance:=listener.distance_to(at)
	if distance>42 or time-float(last.get(kind,-100))<cooldown: return false
	last[kind]=time
	counts[kind]=int(counts.get(kind,0))+1
	if DisplayServer.get_name()=="headless": return true
	for player in players:
		if player.playing: continue
		player.stream=bank[kind][rng.randi_range(0,2)]
		player.pitch_scale=rng.randf_range(.94,1.06)
		player.volume_db=float(LEVELS[kind])+linear_to_db(clampf(strength,.2,1.2))-20*log(1+distance/12)/log(10)
		player.play()
		return true
	return false

func prop_impact(kind: String, at: Vector3, speed: float) -> void:
	var sound: String={"tree":"wood","bench":"wood","fence":"fence","lamp":"metal","rail_sign":"wood","hydrant":"metal","bush":"bush","planter":"brick"}.get(kind,"wood")
	# A hedge can contain five adjacent bodies: one quiet rustle covers the pass.
	if kind=="bush":
		play(sound,at,clampf(speed/12,.35,.70),.85)
	else: play(sound,at,clampf(speed/10,.45,1.1))

func _truck_contact(body: Node) -> void:
	var speed:=Vector2(truck_velocity.x,truck_velocity.z).length()
	if speed<2.0: return
	if body is BreakableProp:
		if not body.loose: prop_impact(body.kind,body.global_position,speed)
	elif body is RigidBody3D and body.name.begins_with("NeighbourCar"):
		var delta: Vector3=truck_velocity-body.linear_velocity
		if delta.length()>2:
			play("car_bump",body.global_position,clampf(delta.length()/12,.4,1.0),.4)
			play("honk",body.global_position,.7,1.8)
			for car in game.life.cars:
				if car.node==body: car.coast=maxf(car.coast,.8)
	elif body.is_in_group("wooden_boundary"):
		play("wood",game.truck.global_position,clampf(speed/14,.4,.8),.65)
	elif body.is_in_group("masonry_collision"):
		play("brick",game.truck.global_position,clampf(speed/12,.4,1.1),.5)

func _physics_process(_dt: float) -> void:
	if not game.paused: truck_velocity=game.truck.linear_velocity

func _process(dt: float) -> void:
	for player in players: player.stream_paused=game.paused
	ringtone.stream_paused=game.paused
	for player in loops.values(): player.stream_paused=game.paused
	if game.paused: return
	time+=dt
	var refilling: bool=game.refill_hose!=null and game.refill_hose.active and game.truck.water<game.truck.tank_capacity
	_update_loop("refill",refilling,game.truck.global_position,dt)
	_update_loop("fire_sizzle",time<fire_contact_until,TownLayout.FIRE+Vector3.UP*1.6,dt)
	var ringing: bool=game.phone_ringing()
	if ringing and not was_ringing:
		counts.ringtone=int(counts.get("ringtone",0))+1
		if DisplayServer.get_name()!="headless": ringtone.play()
	elif not ringing and was_ringing: ringtone.stop()
	was_ringing=ringing
	var local: Vector3=game.truck.position-TownLayout.POOL
	var inside: bool=absf(local.x)<4.4 and absf(local.z)<2.4 and game.truck.position.y<game.town.pool_water.position.y+1.1
	if inside and not in_pool and game.truck.linear_velocity.y<-.8: play("splash",game.truck.position,1.0,2.0)
	in_pool=inside
	cat_time-=dt
	if cat_time<=0:
		cat_time=rng.randf_range(9,15)
		if not game.cat_rescued and not game.rescue_running: play("meow",game.town.cat.global_position,.7,3)

func fire_hit(amount: float) -> void:
	if game.paused or amount<=0: return
	# Renew a short contact window, rather than restarting audio per droplet.
	fire_contact_until=time+.12

func _update_loop(kind: String, active: bool, at: Vector3, dt: float) -> void:
	var distance: float=game.truck.global_position.distance_to(at)
	active=active and distance<42
	var player: AudioStreamPlayer=loops[kind]
	if active and float(loop_levels[kind])<.001:
		counts[kind]=int(counts.get(kind,0))+1
		var clip: AudioStreamWAV=bank[kind][rng.randi_range(0,2)]
		clip.loop_mode=AudioStreamWAV.LOOP_FORWARD
		clip.loop_end=clip.data.size()/2
		player.stream=clip
		player.pitch_scale=rng.randf_range(.97,1.03)
		if DisplayServer.get_name()!="headless": player.play()
	loop_active[kind]=active
	var gain:=lerpf(float(loop_levels[kind]),1.0 if active else 0.0,1-exp(-10*dt))
	loop_levels[kind]=gain
	player.volume_db=float(LEVELS[kind])+linear_to_db(maxf(.00001,gain))-20*log(1+distance/12)/log(10)
	if not active and gain<.001: player.stop()
