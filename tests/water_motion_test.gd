extends SceneTree
var game: Node3D
var failures:=0
var closest:=1000.0
var test_target:=Vector3.ZERO
var cosmetic_calls:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func clear_drops() -> void:
	for d in game.truck.droplets: d.mesh.visible=false
	game.truck.droplets.clear()
func receive(point: Vector3, _amount: float) -> bool:
	closest=minf(closest,point.distance_to(test_target))
	return point.distance_to(test_target)<.25
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game._update_mission()
	var truck: FireEngine=game.truck
	truck.use_automation=true
	truck.position=Vector3(-36,1,25)
	truck.heading=0
	truck.reset_physics_interpolation()
	await frames(5)
	for i in 180:
		var f: Vector3=-game.camera.global_basis.z
		f.y=0
		truck.automated_drive=Vector2(Vector3.FORWARD.dot(game.camera.global_basis.x),-Vector3.FORWARD.dot(f.normalized()))
		truck.automated_aim=truck.cannon.global_position+Vector3.FORWARD*100+Vector3.DOWN*3
		truck.automated_spray=i>80
		await physics_frame
	var lead:=0.0
	for d in truck.droplets:
		if d.amount>0: lead=maxf(lead,(d.mesh.position-truck.cannon.global_position).dot(Vector3.FORWARD))
	print("Driving speed: ",truck.linear_velocity.length(),"; water ahead of moving nozzle: ",lead)
	check(truck.linear_velocity.length()>10 and lead>7,"Forward spray stays ahead of the truck at driving speed")
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://tests/water-momentum-preview.png")
	truck.automated_spray=false
	truck.automated_drive=Vector2.ZERO
	truck.set_physics_process(false)
	truck.freeze=true
	clear_drops()
	truck.position=Vector3(-36,1,20)
	truck.spray_direction=Vector3.FORWARD
	truck.linear_velocity=Vector3(8,3,-16)
	for i in 12: truck._emit_drop()
	var inherits:=true
	var colors: Dictionary={}
	var strays:=0
	var total_amount:=0.0
	for d in truck.droplets:
		if d.stray: strays+=1
		else:
			inherits=inherits and d.velocity.z < -36 and d.velocity.x>6 and d.velocity.y>1
		colors[d.mesh.material_override.albedo_color]=true
		total_amount+=d.amount
	check(inherits,"Drops inherit forward, lateral and vertical chassis momentum")
	check(strays>0 and float(strays)/truck.droplets.size()<.1,"A sparse secondary layer adds stray droplets without a broad second stream")
	check(colors.size()>=3,"Stream droplets use several subtle water colours")
	check(absf(total_amount-12*.018)<.0001,"Cosmetic droplets add no extra mission water")
	clear_drops()
	truck.hit_receiver=func(_point: Vector3, _amount: float): cosmetic_calls+=1; return false
	truck._spawn_drop(Vector3.FORWARD,Vector3.FORWARD*12,.5,0,true)
	truck._update_drops(.1)
	check(cosmetic_calls==0,"Stray droplets cannot falsely trigger fire-hit feedback")
	clear_drops()
	truck.linear_velocity=Vector3.ZERO
	var shot:=truck.solve_shot(Vector3(-36,3,20),Vector3(-36,0,5))
	check(not shot.is_empty() and shot.time<.8,"Stationary stream reaches fifteen metres in under 0.8 seconds")
	truck._spawn_drop(Vector3.FORWARD,Vector3(0,5,-22),1,.018,false)
	var initial_y: float=truck.droplets[0].velocity.y
	truck._update_drops(.2)
	check(not truck.droplets.is_empty() and initial_y-truck.droplets[0].velocity.y>5,"Water falls with a faster, snappier acceleration")
	clear_drops()
	truck.linear_velocity=Vector3(8,2,-12)
	test_target=Vector3(-36,1.7,10)
	shot=truck.solve_shot(truck.cannon.global_position,test_target,truck.linear_velocity)
	check(not shot.is_empty(),"Moving aim assist finds a momentum-compensated shot")
	if not shot.is_empty():
		truck.hit_receiver=receive
		truck._spawn_drop(shot.direction,shot.velocity,1.15,.018,false)
		for i in 120: truck._update_drops(1.0/120)
		check(closest<.25,"Actual assisted droplets still land on a stationary target while moving")
	game.queue_free()
	await process_frame
	await process_frame
	print("WATER MOTION CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
