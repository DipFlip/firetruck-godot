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
	await frames(50)
	check(game.intro.active and game.truck.freeze and game.call_timer==1.5 and game.intro.shot==0,"Intro freezes driving and dispatch while showing Biscuit")
	var splashing:=false
	for drop in game.dog_puddle.drops: splashing=splashing or drop.age<.6
	check(splashing,"The dog splashes real visible droplets in its puddle")
	await frames(90)
	check(game.intro.shot==1,"The second cinematic shot introduces the northern railway")
	await frames(225)
	check(not game.intro.active and not game.truck.freeze and game.truck.enabled,"The six-second intro restores the driving camera and controls")
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
	game.end_dialogue()
	game.truck.position=rail.engine.position+Vector3(-7,.73,0)
	game.truck.heading=-PI/2
	game.truck.rotation.y=-PI/2
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	game.camera_focus=game.truck.position
	for i in 240:
		var ahead: Vector3=-game.camera.global_basis.z
		ahead.y=0
		game.truck.automated_drive=Vector2(Vector3.RIGHT.dot(game.camera.global_basis.x),-Vector3.RIGHT.dot(ahead.normalized()))
		await frames(1)
	check(rail.pushed_once and not rail.started,"Driving into the train alone is too weak to start its engine")
	game.end_dialogue()
	await frames(3)
	check(rail.hint_sent and game.hud.full_text.contains("backwards"),"After the first push Rowan explains the backwards water recoil")
	game.truck.automated_spray=true
	game.truck.automated_aim=game.truck.position+Vector3(-13,-.8,0)
	for i in 300:
		if rail.started: break
		var ahead: Vector3=-game.camera.global_basis.z
		ahead.y=0
		game.truck.automated_drive=Vector2(Vector3.RIGHT.dot(game.camera.global_basis.x),-Vector3.RIGHT.dot(ahead.normalized()))
		game.truck.automated_aim=game.truck.position+Vector3(-13,-.8,0)
		await frames(1)
	print("Train push measured: x=",rail.engine.position.x," speed=",rail.engine.linear_velocity.x," assist=",rail.assist_time," truck=",game.truck.position)
	check(rail.started and game.truck.water<100,"Actual contact plus backwards hose recoil push-starts the heavy train")
	game.truck.automated_spray=false
	game.truck.automated_drive=Vector2.ZERO
	game.truck.position=Vector3(0,.85,12)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	await frames(180)
	check(rail.boarded and not rail.driver.visible and rail.driver_guard.collision_layer==0,"The driver climbs aboard and releases the outside personal-space zone")
	var moving: float=rail.engine.position.x
	await frames(150)
	check(rail.engine.position.x>moving+4 and rail.smoke.any(func(cloud): return cloud.age<2.8),"The running train moves under engine power and puffs smoke")
	await frames(2400)
	check(rail.direction<0 and rail.engine.position.x<NorthlineRailway.RIGHT_END,"The train waits at the terminus and then returns along its track")
	game.queue_free()
	await process_frame
	await process_frame
	print("TOWN ADDITIONS CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
