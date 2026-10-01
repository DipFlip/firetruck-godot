extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func place() -> void:
	Input.action_release("brake")
	game.truck.reset_truck()
	game.truck.position=Vector3(-36,1,-14)
	game.truck.automated_drive=Vector2.ZERO
	game.truck.automated_spray=false
	game.truck.water=100
	game.truck.reset_physics_interpolation()
	await frames(45)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	await place()
	var truck: FireEngine=game.truck
	var start:=truck.position
	truck.linear_velocity=Vector3(0,0,-12)
	Input.action_press("brake")
	var early:=0.0
	for i in 90:
		var forward: Vector3=-game.camera.global_basis.z
		forward.y=0
		truck.automated_drive=Vector2(Vector3.FORWARD.dot(game.camera.global_basis.x),-Vector3.FORWARD.dot(forward.normalized()))
		await physics_frame
		if i==5: early=Vector3(truck.linear_velocity.x,0,truck.linear_velocity.z).length()
	var slide:=start.distance_to(truck.position)
	print("Brake speed after 0.1s: ",early,"; slide: ",slide,"; final speed: ",truck.linear_velocity.length())
	check(early>8,"Shift eases into braking rather than abruptly killing driving momentum")
	check(slide>2 and slide<8 and truck.linear_velocity.length()<.1,"A moving truck slides briefly and stops even while drive input is held")
	for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
		await place()
		Input.action_press("brake")
		truck.automated_aim=truck.cannon.global_position+direction*14
		truck.automated_spray=true
		start=truck.position
		await frames(120)
		var drift:=Vector2(truck.position.x-start.x,truck.position.z-start.z).length()
		print("Braced spray drift ",direction,": ",drift)
		check(drift<.08 and truck.water<95,"Stationary Shift holds against spray recoil in direction "+str(direction))
	start=truck.position
	Input.action_release("brake")
	await frames(60)
	check(Vector2(truck.position.x-start.x,truck.position.z-start.z).length()>1,"Releasing Shift restores normal water propulsion")
	await place()
	truck.linear_velocity=Vector3(0,0,-12)
	truck.automated_aim=truck.cannon.global_position+Vector3.BACK*14
	truck.automated_spray=true
	Input.action_press("brake")
	await frames(180)
	check(truck.brake_holding and truck.linear_velocity.length()<.1,"Braking while spraying also settles into a steady brace")
	truck.automated_spray=false
	truck.position=Vector3(-36,5,-14)
	truck.linear_velocity=Vector3(0,0,-8)
	truck.reset_physics_interpolation()
	Input.action_press("brake")
	await frames(8)
	check(not truck.brake_holding and -truck.linear_velocity.z>5 and truck.linear_velocity.y<0,"Airborne braking stays light and does not pin the truck or suspend gravity")
	truck.reset_truck()
	check(not truck.brake_holding and truck.brake_engagement==0,"Reset clears the braking state")
	Input.action_release("brake")
	game.queue_free()
	await process_frame
	await process_frame
	print("BRAKING CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
