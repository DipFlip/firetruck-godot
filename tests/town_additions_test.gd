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
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=1.5
	game.truck.use_automation=true
	for car in game.life.cars: check(car.node.position.distance_to(game.truck.position)>11,"Cars start well clear of the player")
	for walker in game.life.walkers: check(walker.node.position.distance_to(game.truck.position)>11,"Walkers start well clear of the player")
	game.intro.start()
	await frames(150)
	check(game.intro.active and game.truck.freeze and game.call_timer==1.5 and game.intro.shot==0 and game.camera.size>140,"Intro freezes driving and dispatch while the loose printed mat unfolds")
	var splashing:=false
	for drop in game.dog_puddle.drops: splashing=splashing or drop.age<.6
	check(game.intro.title.reveal>0 and game.intro.title.total_length>0 and game.intro.overlay.get_child_count()==2,"The intro writes only the town name over the moving views")
	await frames(300)
	for drop in game.dog_puddle.drops: splashing=splashing or drop.age<.6
	check(game.intro.shot>=1 and game.camera.size<60,"Close cinematic views show the scenery being assembled")
	game.intro.finish()
	game.truck.position=TownLayout.DOG+Vector3(3,1,3)
	game.dog_puddle.clock=0
	await frames(45)
	for drop in game.dog_puddle.drops: splashing=splashing or drop.age<.6
	check(splashing,"The dog splashes real visible droplets after assembly resumes")
	await frames(540)
	check(not game.intro.active and not game.truck.freeze and game.truck.enabled,"The paced intro restores the driving camera and controls")
	game.intro.start()
	await frames(5)
	var event:=InputEventAction.new()
	event.action="jump"
	event.pressed=true
	game._unhandled_input(event)
	check(not game.intro.active and game.truck.charge==0,"Space skips the intro without charging a jump")
	game.call_timer=0
	game.stage=4
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	var puddle: DogPuddle=game.dog_puddle
	check(puddle.position.distance_to(TownLayout.DOG)<.01 and puddle.clean==0,"The intro puddle persists at the later dog mission")
	game._water_hit(TownLayout.DOG+Vector3(1,.10,0),.5)
	await frames(2)
	check(puddle.clean>0 and puddle.clean<1 and puddle.surfaces[0].visible,"Spraying gradually shrinks the muddy puddle")
	game._water_hit(TownLayout.DOG+Vector3(1,.10,0),2)
	await frames(2)
	check(puddle.clean==1 and not puddle.surfaces[0].visible,"Enough water removes the puddle")
	# Push the locomotive using actual rigid-body contacts, then add backwards
	# water recoil. No mission activation, velocity or progress is injected.
	var rail: NorthlineRailway=game.railway
	game.rescued=true
	game.stage=1
	rail.briefed=true
	game.truck.position=rail.driver.position+Vector3(0,1,5)
	await frames(3)
	game.end_dialogue()
	await frames(3)
	check(game.hud.prompt_label.text.is_empty(),"The train cannot trigger the cat’s ladder hint")
	game.stage=4
	game.end_dialogue()
	game.truck.position=rail.engine.position+Vector3(-7,.73,1.1)
	game.truck.heading=-PI/2+.35
	game.truck.rotation.y=game.truck.heading
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	game.camera_focus=game.truck.position
	for i in 240:
		var ahead: Vector3=-game.camera.global_basis.z
		ahead.y=0
		var direction:=Vector3(1,0,.45).normalized()
		game.truck.automated_drive=Vector2(direction.dot(game.camera.global_basis.x),-direction.dot(ahead.normalized()))
		await frames(1)
	check(rail.pushed_once and not rail.started,"Driving into the train alone is too weak to start its engine")
	check(rail.push_locked,"Actual rear contact gently locks the truck into the push")
	check(absf(game.truck.position.z-rail.engine.position.z)<.12 and absf(angle_difference(game.truck.heading,-PI/2))<.08,"An off-centre, crooked approach settles onto the train centreline despite diagonal steering")
	game.truck.apply_central_impulse(Vector3(0,0,game.truck.mass*5))
	for i in 45:
		var ahead: Vector3=-game.camera.global_basis.z
		ahead.y=0
		var direction:=Vector3(1,0,.9).normalized()
		game.truck.automated_drive=Vector2(direction.dot(game.camera.global_basis.x),-direction.dot(ahead.normalized()))
		await frames(1)
	check(rail.push_locked and absf(game.truck.position.z-rail.engine.position.z)<.12,"The push hold absorbs sideways impact without letting the truck slide off")
	game.truck.automated_drive=Vector2.ZERO
	await frames(30)
	check(rail.push_locked and game.truck.axis_lock_linear_z and absf(game.truck.position.z-rail.engine.position.z)<.12,"Releasing the controls keeps the truck aligned instead of losing the hold")
	var guided:=rail.guide_push(Vector3(.01,0,1).normalized(),1.0/60)
	check(rail.push_locked and guided.is_equal_approx(Vector3.RIGHT),"Steering almost ninety degrees away still keeps pushing straight into the train")
	guided=rail.guide_push(Vector3.BACK,1.0/60)
	check(not rail.push_locked and guided==Vector3.BACK,"A deliberate ninety-degree turn releases the push lock")
	var released_z: float=game.truck.position.z
	for i in 45:
		var ahead: Vector3=-game.camera.global_basis.z
		ahead.y=0
		game.truck.automated_drive=Vector2(Vector3.BACK.dot(game.camera.global_basis.x),-Vector3.BACK.dot(ahead.normalized()))
		await frames(1)
	check(not rail.push_locked and game.truck.position.z>released_z+1,"Ninety-degree steering releases the physical hold so the truck can drive away")
	game.truck.position=rail.engine.position+Vector3(-7,.73,-1.1)
	game.truck.heading=-PI/2
	game.truck.rotation.y=-PI/2
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	game.end_dialogue()
	await frames(3)
	check(rail.hint_sent and game.hud.full_text.contains("backwards"),"After the first push Rowan explains the backwards water recoil")
	game.truck.automated_spray=true
	game.truck.automated_aim=game.truck.position+Vector3(-13,-.8,0)
	for i in 180:
		if rail.started: break
		var ahead: Vector3=-game.camera.global_basis.z
		ahead.y=0
		game.truck.automated_drive=Vector2(Vector3.RIGHT.dot(game.camera.global_basis.x),-Vector3.RIGHT.dot(ahead.normalized()))
		game.truck.automated_aim=game.truck.position+Vector3(-13,-.8,2)
		await frames(1)
	print("Train push measured: x=",rail.engine.position.x," speed=",rail.engine.linear_velocity.x," assist=",rail.assist_time," truck=",game.truck.position)
	check(rail.started and game.truck.water<100,"An off-centre push plus angled backwards hose recoil starts the train within three seconds")
	check(not rail.push_locked and not game.truck.axis_lock_linear_z and is_nan(game.truck.train_push_z),"Engine startup releases the hold and restores normal sideways movement")
	game.truck.automated_spray=false
	game.truck.automated_drive=Vector2.ZERO
	game.truck.position=Vector3(0,.85,12)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	await frames(180)
	check(rail.boarded and rail.driver.visible and rail.driver.get_parent()==rail.engine and absf(rail.roof_hinge.rotation.z)<.001 and rail.driver_guard.collision_layer==0,"The visible conductor jumps through the hinged roof, rides in the cab, and releases the outside personal-space zone")
	var moving: float=rail.engine.position.x
	await frames(150)
	check(rail.engine.position.x>moving+4 and rail.smoke.any(func(cloud): return cloud.age<2.8),"The running train moves under engine power and puffs smoke")
	await frames(5600)
	check(rail.direction<0 and rail.engine.global_basis.x.x<-.9 and rail.engine.position.x<NorthlineRailway.RIGHT_END,"The train leaves town and returns with its front rotated toward travel")
	game.queue_free()
	await process_frame
	await process_frame
	print("TOWN ADDITIONS CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
