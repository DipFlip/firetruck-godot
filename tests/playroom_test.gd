extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func place(p: Vector3, velocity: Vector3=Vector3.ZERO) -> void:
	game.end_dialogue()
	game.truck.position=p
	game.truck.linear_velocity=velocity
	game.truck.heading=atan2(-velocity.x,-velocity.z) if velocity.length_squared()>.01 else 0
	game.truck.rotation.y=game.truck.heading
	game.truck.reset_physics_interpolation()
	game.camera_focus=p
	await frames(3)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	await frames(3)
	check(game.railway.signs.size()==6 and game.railway.signs.all(func(sign): return sign.meshes.size()==4 and sign.freeze),"All six crossing signs have attached artwork and anchored breakable bodies")
	check(game.playroom.block_sizes.size()>50 and game.playroom.painted_blocks>10 and game.playroom.block_sizes[0]!=game.playroom.block_sizes[1],"The enclosure has varied whole blocks, including fully painted pieces")
	check(game.railway.gates.size()==2 and game.railway.gates.all(func(gate): return gate.opening==0 and gate.boom_body.collision_layer==Playroom.WALL_LAYER),"Both wooden archways start with closed player-blocking booms")
	var gate: ToyRailGate=game.railway.gates[1]
	game.railway.set_physics_process(false)
	gate.update_train(50,true,2)
	check(gate.opening==0,"A train elsewhere in town leaves the exit boom shut")
	gate.update_train(67,true,.575)
	check(is_equal_approx(gate.opening,.5) and gate.hinge.rotation.x<-.5 and gate.hinge.rotation.x> -1,"The boom lifts smoothly as the train approaches")
	gate.update_train(77,true,.7)
	check(gate.opening==1 and gate.hinge.rotation.x< -1.4,"The boom is fully raised before the locomotive reaches the wooden arch")
	await place(Vector3(73,.85,NorthlineRailway.TRACK_Z),Vector3.RIGHT*22)
	await frames(65)
	check(game.truck.position.x<79.5,"The truck stays on the mat even when a train-exit boom is raised")
	gate.update_train(103,true,1.3)
	check(gate.opening==0,"The boom lowers again once the complete locomotive has passed")
	game.railway.set_physics_process(true)
	var sign: BreakableProp=game.railway.signs[2]
	await place(sign.home.origin+Vector3(0,.85,5),Vector3(0,0,-10))
	await frames(50)
	check(sign.loose and sign.global_position.distance_to(sign.home.origin)>.5 and absf(sign.global_basis.y.dot(Vector3.UP))<.95,"An actual truck collision knocks a railway sign over with its warning light attached")
	await place(Vector3(18,.85,-42))
	await frames(720)
	check(not sign.loose and sign.freeze and sign.global_transform.is_equal_approx(sign.home) and sign.meshes[0].transparency==0,"A knocked railway sign fades out and respawns upright after ten seconds")
	var sound: TownAudio=game.sounds
	sound.set_process(false)
	var before: int=sound.counts.get("bush",0)
	for i in 5:
		sound.prop_impact("bush",game.truck.position+Vector3(i*.3,0,0),8)
		sound.time+=.15
	check(int(sound.counts.get("bush",0))==before+1,"Driving through five bushes produces one quiet rustle instead of five overlapping sounds")
	sound.time+=.5
	sound.prop_impact("bush",game.truck.position,8)
	check(int(sound.counts.get("bush",0))==before+2,"A subsequent hedge encounter can still play a fresh rustle")
	sound.set_process(true)
	for p in [Vector3(73,.85,45),Vector3(-73,.85,45),Vector3(57,.85,73),Vector3(57,.85,-73)]:
		var direction:=Vector3(signf(p.x),0,0) if absf(p.x)==73 else Vector3(0,0,signf(p.z))
		await place(p,direction*22)
		await frames(65)
		check(absf(game.truck.position.x)<79.5 and absf(game.truck.position.z)<79.5,"The wooden boundary contains a fast truck on side "+str(direction))
	await place(Vector3(73,.85,50),Vector3(22,game.truck.full_jump_speed,0))
	await frames(70)
	check(game.truck.position.x<79.5,"A fully charged jump cannot carry the truck over the toy-block wall")
	# The locomotive must still cross the player-only wall into its tunnel route.
	await place(Vector3(0,.85,12))
	game.railway.started=true
	game.railway.boarded=true
	game.railway.engine.position.x=76
	game.railway.engine.linear_velocity=Vector3.RIGHT*3.6
	await frames(210)
	check(game.railway.engine.position.x>87,"The train can pass the wooden arch without hitting the play-mat boundary")
	check(game.railway.gates[1].opening>.95,"The exit boom stays raised while the rear of the real moving train passes")
	await frames(450)
	check(game.railway.engine.position.x>110 and game.railway.gates[1].opening<.01 and game.railway.direction>0,"The exit closes after the train clears the mat, still travelling forwards")
	game.queue_free()
	await process_frame
	await process_frame
	print("PLAYROOM CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
