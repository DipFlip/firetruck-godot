extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func place(p: Vector3) -> void:
	game.end_dialogue()
	game.truck.position=p
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	await frames(4)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=1
	game.truck.use_automation=true
	await place(Vector3(17,1,-3))
	game.truck.extend_ladder()
	await frames(300)
	check(game.cat_rescued and game.barbecue_call_delay>0,"An actual ladder rescue schedules the barbecue call")
	await frames(1400)
	check(game.barbecue_call_sent and game.dialogue_active and game.hud.speaker_key=="DISPATCH","Waiting beside Maya without pressing any dialogue buttons delivers the phone call")
	await frames(1500)
	check(game.dialogue_active and game.hud.speaker_key=="DISPATCH","An unread barbecue call remains visible instead of disappearing")
	game.end_dialogue()
	game.barbecue_discovered=false
	game.barbecue_notice_time=0
	game.barbecue_call_sent=false
	game.barbecue_call_delay=20
	game.stage=5
	await place(TownLayout.FIRE+Vector3(-11,1,0))
	await frames(180)
	check(not game.barbecue_discovered and game.barbecue_call_delay>0,"Passing the nearby road does not silently cancel the barbecue call")
	await place(Vector3(-60,1,60))
	game.truck.freeze=true
	# Restart traffic from complete rest, after its contact solver has settled.
	for car in game.life.cars:
		car.node.linear_velocity=Vector3.ZERO
		car.node.angular_velocity=Vector3.ZERO
		car.coast=0
	var starts: Array[Vector3]=[]
	for car in game.life.cars: starts.append(car.node.position)
	await frames(240)
	for i in game.life.cars.size():
		var car: Dictionary=game.life.cars[i]
		check(car.speed>2.5 and car.node.position.distance_to(starts[i])>5,"Car %d restarts from a full stop against ground friction" % i)
	var yielded: Dictionary=game.life.cars[1]
	var ahead: Vector3=(yielded.path[yielded.next]-yielded.node.position).normalized()
	await place(yielded.node.position+ahead*5+Vector3.UP)
	await frames(240)
	check(yielded.speed<.12,"Traffic still waits for the truck blocking its lane")
	await place(Vector3(-60,1,60))
	await frames(240)
	check(yielded.speed>2.5,"Yielded traffic resumes when the truck leaves")
	var cage:=Node3D.new()
	game.add_child(cage)
	for x in [-2.0,2.0]: TownProps.collider(cage,Vector3(50+x,1.5,52),Vector3(.25,3,5))
	for z in [-2.5,2.5]: TownProps.collider(cage,Vector3(50,1.5,52+z),Vector3(4.25,3,.25))
	var stranded: Dictionary=game.life.cars[0]
	stranded.node.position=Vector3(50,.03,52)
	stranded.node.linear_velocity=Vector3.ZERO
	stranded.node.angular_velocity=Vector3.ZERO
	stranded.last_position=stranded.node.position
	stranded.stalled=0
	stranded.coast=0
	await frames(1080)
	# The relocated ramps change arrival timing; a recovered car may be turning.
	# Use the same moving-speed floor as the repeated-corner circulation check.
	check(stranded.node.position.distance_to(Vector3(50,0,52))>15 and stranded.speed>2,"A car stranded off its route fades back to a clear lane and drives again")
	cage.queue_free()
	# Keep every route visible during the visual tire-clearance check.
	# Traffic still simulates off-screen, but wheel raycasts only run in view.
	game.set_process(false)
	game.camera.position=Vector3(0,140,160)
	game.camera.look_at(Vector3.ZERO)
	game.camera.size=200
	var moving:=true
	var min_tire_clearance:=INF
	for i in 6:
		await frames(600)
		for car in game.life.cars:
			moving=moving and car.speed>2
			for wheel in car.wheels:
				var query:=PhysicsRayQueryParameters3D.create(wheel.global_position+Vector3.UP*.4,wheel.global_position+Vector3.DOWN,9,[car.node.get_rid(),game.truck.get_rid()])
				var road:=game.get_world_3d().direct_space_state.intersect_ray(query)
				if road: min_tire_clearance=minf(min_tire_clearance,wheel.global_position.y-.34-road.position.y)
	check(moving,"All three cars keep circulating through repeated corners for a minute")
	check(min_tire_clearance>=-.005 and min_tire_clearance<.08,"Town car tires clear the roads and ramps without floating above them")
	game.set_process(true)
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.freeze=true
	game.barbecue_call_delay=-1
	game.barbecue_ring_timer=-1
	game.stage=4
	for i in 4: game.proximity_latches[i]=true
	var cases: Array[Dictionary]=[
		{"from":Vector3(0,1,-10),"aim":Vector3(5.8,-1.3,2.9)},
		{"from":Vector3(10,1,0),"aim":Vector3(-4.8,-1.3,3.5)},
		{"from":Vector3(0,1,10),"aim":Vector3(-5.2,-1.3,-2.9)},
		{"from":Vector3(-10,1,0),"aim":Vector3(4.9,-1.3,-3.1)}]
	for fill in [0.0,.85]:
		for i in cases.size():
			game.pool_done=false
			game.pool_progress=fill
			game.pool_basin.set_fill(fill)
			game.truck.automated_spray=false
			await place(TownLayout.POOL+cases[i].from)
			game.truck.water=100
			game.truck.automated_aim=TownLayout.POOL+cases[i].aim
			game.truck.automated_spray=true
			await frames(10)
			var assisted: bool=game.truck.assisted
			await frames(120)
			print("Pool fill=",fill," side=",i," assisted=",assisted," delivered=",game.pool_progress-fill)
			check(assisted and game.pool_progress>fill+.06,"Generous aim delivers real water from side %d with pool at %.0f%%" % [i,fill*100])
	game.truck.automated_spray=false
	game.fire_progress=0
	game._water_hit(TownLayout.FIRE+Vector3.UP*1.8,20)
	var thanks: String=game.rewards.pending.back().words
	check(not thanks.to_lower().contains("pool") and not thanks.to_lower().contains("dog") and thanks.contains("Thank"),"Leo thanks the player without advertising other jobs")
	game.queue_free()
	await process_frame
	await process_frame
	print("TRAFFIC / AIM CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
