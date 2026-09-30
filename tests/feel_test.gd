extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func action(name: String) -> void:
	var event:=InputEventAction.new()
	event.action=name
	event.pressed=true
	game._unhandled_input(event)
func drive_trial(accel: float, speed: float, spray: bool) -> float:
	var t: FireEngine=game.truck
	t.acceleration=accel
	t.top_speed=speed
	t.position=Vector3(-40,1,-36)
	t.linear_velocity=Vector3.ZERO
	t.heading=-PI/2
	t.automated_drive=Vector2.ZERO
	t.automated_spray=false
	t.water=100
	await frames(5)
	for i in 180:
		var forward: Vector3=-game.camera.global_basis.z
		forward.y=0
		forward=forward.normalized()
		t.automated_drive=Vector2(Vector3.RIGHT.dot(game.camera.global_basis.x),-Vector3.RIGHT.dot(forward))
		t.automated_aim=t.cannon.global_position-Vector3.RIGHT*14-Vector3.UP*5*pow(14.0/24,2)
		t.automated_spray=spray
		await physics_frame
	var result:=Vector3(t.linear_velocity.x,0,t.linear_velocity.z).length()
	t.automated_drive=Vector2.ZERO
	t.automated_spray=false
	return result
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	var parked: Array[Vector3]=[]
	for c in game.life.cars:
		parked.append(c.node.position)
		c.node.position=Vector3(500,0,500)
	await frames(5)
	var old:=await drive_trial(21,13.5,false)
	var new:=await drive_trial(26.25,16.875,false)
	var boost:=await drive_trial(26.25,16.875,true)
	print("Measured speed old / new / hose boost: ",old," / ",new," / ",boost)
	check(new/old>1.22 and new/old<1.29,"Actual road speed increases approximately 25%")
	check(boost>new*1.35 and boost<new*1.9,"Rearward hose provides noticeable, bounded acceleration")
	check(game.truck.effects.tracks.is_empty(),"Straight driving leaves no tire tracks")
	game.truck.position=Vector3(-20,1,-36)
	game.truck.linear_velocity=Vector3(14,0,0)
	game.truck.heading=-PI/2
	game.truck.automated_drive=Vector2(0,-1)
	await frames(25)
	check(game.truck.effects.tracks.size()>4 and game.truck.effects.dust.size()>0,"Hard turning leaves fading skid trails and dust")
	game.truck.automated_drive=Vector2.ZERO
	game.truck.reset_truck()
	await frames(10)
	game.truck.position=TownLayout.MAYA+Vector3(0,1,4)
	game.truck.linear_velocity=Vector3.ZERO
	game.talk("MAYA  /  MAPLE GREEN","Just checking the ladder controls.",4)
	action("interact")
	await frames(45)
	check(game.dialogue_active and game.truck.ladder_amount>.95,"E extends ladder even during conversation without advancing it")
	action("continue")
	if game.dialogue_active: action("continue")
	await frames(40)
	check(not game.dialogue_active,"Enter advances dialogue")
	await frames(280)
	check(game.truck.ladder_amount>.95,"Ladder stays deployed while approaching a rescue")
	action("interact")
	await frames(40)
	check(game.truck.ladder_amount==0,"E stows the deployed ladder")
	game.truck.position=TownLayout.JUNE+Vector3(1,1,3)
	game.truck.linear_velocity=Vector3.ZERO
	await frames(5)
	check(game.dialogue_active,"Entering neighbour radius starts conversation")
	action("continue")
	if game.dialogue_active: action("continue")
	await frames(60)
	check(not game.dialogue_active,"Remaining nearby does not repeatedly reopen dialogue")
	game.truck.reset_truck()
	await frames(10)
	game.truck.position=TownLayout.JUNE+Vector3(1,1,3)
	await frames(5)
	check(game.dialogue_active,"Returning after leaving allows another greeting")
	action("continue")
	if game.dialogue_active: action("continue")
	game.truck.reset_truck()
	await frames(90)
	Input.action_press("jump")
	await frames(40)
	Input.action_release("jump")
	await frames(3)
	check(game.camera_trauma>.2,"Jump adds light camera shake")
	await frames(150)
	check(game.camera_trauma==0,"Camera shake settles after landing")
	game.truck.position=Vector3(0,1,-20)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.automated_aim=Vector3(0,0,-30)
	game.truck.automated_spray=true
	Input.action_press("brake")
	await frames(70)
	check(game.truck.splashes.size()>0 and game.truck.rings.size()>0,"Ground impact creates bouncing sprinkles and landing ripples")
	var min_x:=10000.0
	var max_x:=-10000.0
	for d in game.truck.droplets:
		if not d.stray and d.mesh.position.z < -26:
			min_x=minf(min_x,d.mesh.position.x)
			max_x=maxf(max_x,d.mesh.position.x)
	check(max_x-min_x>.35 and max_x-min_x<1.5,"Primary stream stays compact independently of stray splashes")
	game.truck.automated_spray=false
	Input.action_release("brake")
	for i in game.life.cars.size(): game.life.cars[i].node.position=parked[i]
	game.life.set_physics_process(true)
	game.truck.reset_truck()
	var car_start: Vector3=game.life.cars[1].node.position
	var walker_start: Vector3=game.life.walkers[0].node.position
	var bird_start: Vector3=game.life.birds[0].node.position
	await frames(120)
	check(game.life.cars[1].node.position.distance_to(car_start)>2,"Neighbour cars drive their routes")
	check(game.life.walkers[0].node.position.distance_to(walker_start)>1,"Pedestrians walk along pavements")
	check(game.life.birds[0].node.position.distance_to(bird_start)>2,"Birds fly and animate their wings")
	var c: Dictionary=game.life.cars[1]
	var toward: Vector3=(c.path[c.next]-c.node.position).normalized()
	game.truck.position=c.node.position+toward*5+Vector3.UP*.8
	game.truck.linear_velocity=Vector3.ZERO
	Input.action_press("brake")
	await frames(60)
	check(c.speed<.1,"Traffic yields when the fire engine blocks its lane")
	Input.action_release("brake")
	action("pause")
	var car_position: Vector3=c.node.position
	var bird_position: Vector3=game.life.birds[0].node.position
	await frames(20)
	check(c.node.position==car_position and game.life.birds[0].node.position==bird_position,"Pause freezes town life")
	action("pause")
	check(TownLayout.MAYA.distance_to(TownLayout.LEO)>30 and TownLayout.DOG.distance_to(TownLayout.FIRE)>80 and TownLayout.POOL.z>50,"Mission events occupy separate neighbourhoods")
	game.queue_free()
	await process_frame
	await process_frame
	print("FEEL CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
