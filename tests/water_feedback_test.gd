extends SceneTree
var game: Node3D
var failures:=0
var empty_cues:=0
var water_hits:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func pause() -> void:
	var event:=InputEventAction.new()
	event.action="pause"
	event.pressed=true
	game._unhandled_input(event)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.truck.position=Vector3(-18,1,-52)
	game.truck.reset_physics_interpolation()
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	game.truck.empty_spray.connect(func(): empty_cues+=1)
	game.truck.water_hit.connect(func(_point,_amount): water_hits+=1)
	await frames(45)
	game.truck.water=40
	game.truck.automated_aim=Vector3(-18,0,-65)
	game.truck.automated_spray=true
	await frames(20)
	var small:=INF
	var large:=0.0
	for i in 30:
		await frames(1)
		small=minf(small,game.hud.water_gauge_scale)
		large=maxf(large,game.hud.water_gauge_scale)
	check(game.truck.water<40 and large-small>.005 and large<1.04,"Using water gently pulses the gauge while consuming the actual tank")
	game.truck.automated_spray=false
	await frames(90)
	game.truck.water=0
	water_hits=0
	game.truck.automated_spray=true
	await frames(8)
	check(empty_cues==1 and game.hud.water_gauge_scale>1.04 and game.hud.water_gauge_offset.length()>.1,"An empty spray attempt pulses and shakes the gauge")
	var cosmetic: bool=not game.truck.droplets.is_empty()
	for drop in game.truck.droplets: cosmetic=cosmetic and drop.amount==0 and drop.stray
	check(cosmetic and not game.truck.spraying and game.truck.water==0 and water_hits==0,"An empty nozzle sputters harmless drops without water hits or negative water")
	pause()
	var empty_time: float=game.hud.water_empty_time
	await frames(20)
	check(game.hud.water_empty_time==empty_time,"Pause freezes gauge feedback")
	pause()
	await frames(65)
	check(empty_cues>=2 and empty_cues<=3,"Holding an empty hose repeats feedback at a restrained rate")
	game.truck.automated_spray=false
	await frames(90)
	check(absf(game.hud.water_gauge_scale-1)<.001 and game.hud.water_gauge_offset.length()<.001,"The gauge returns to its resting pose after the attempt")
	var hydrant: BreakableProp=game.interactions.hydrant_props[0]
	var original:=hydrant.meshes[0].transform
	game.truck.position=Vector3(-3,.85,12)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.heading=0
	game.truck.reset_physics_interpolation()
	game.truck.freeze=true
	game.truck.water=20
	await frames(12)
	var hose: RefillHose=game.refill_hose
	check(hose.active and hose.visible and hose.hydrant==hydrant and game.truck.water>20,"Automatic hydrant refilling displays the connecting hose")
	check(hose.points[0].distance_to(hydrant.global_position)<1 and game.truck.to_local(hose.points[16]).z>2,"The hose connects the hydrant outlet to the back of the truck")
	var continuous:=true
	for i in hose.segments.size():
		var segment: MeshInstance3D=hose.segments[i]
		continuous=continuous and (segment.transform*Vector3(0,-.5,0)).distance_to(hose.points[i])<.001 and (segment.transform*Vector3(0,.5,0)).distance_to(hose.points[i+1])<.001
	check(continuous,"The hose forms a continuous tube without gaps along its bends")
	check(not hydrant.meshes[0].transform.is_equal_approx(original),"The connected hydrant pulses its artwork while keeping its collider fixed")
	var rear:=hose.points[16]
	game.truck.heading=PI/2
	await frames(8)
	check(hose.points[16].distance_to(rear)>1,"The rear connection follows truck rotation")
	pause()
	var flow_time:=hose.time
	var pulse_pose:=hydrant.meshes[0].transform
	await frames(20)
	check(hose.time==flow_time and hydrant.meshes[0].transform.is_equal_approx(pulse_pose),"Pause freezes water travelling through the refill hose and the hydrant pulse")
	pause()
	game.truck.freeze=true
	await frames(240)
	check(game.truck.water==100 and not hose.active and not hose.visible and hydrant.meshes[0].transform.is_equal_approx(original),"A full tank disconnects the hose and restores the hydrant's normal shape")
	check(not game.hud.prompt_label.text.to_lower().contains("tank") and not game.hud.prompt_label.text.to_lower().contains("refilling"),"Tank status uses the gauge without full, empty or refill popups")
	game.truck.water=20
	await frames(5)
	hydrant.knock(Vector3(10,0,0))
	await frames(2)
	var stopped_water: float=game.truck.water
	await frames(12)
	check(hydrant.loose and not hose.active and game.truck.water==stopped_water,"Knocking over a connected hydrant detaches the hose and stops refilling")
	game.queue_free()
	await process_frame
	await process_frame
	print("WATER FEEDBACK CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
