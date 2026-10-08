extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func pose(at: Vector3) -> void:
	game.truck.global_position=ToyRaceTrack.ORIGIN+at
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.intro.finish()
	game.travel.set_process(false)
	var rail: NorthlineRailway=game.railway
	game.truck.position=rail.driver.global_position+Vector3(8,0,6)
	rail._physics_process(1.0)
	var direction: Vector3=(game.truck.global_position-rail.driver.global_position).normalized()
	check((-rail.driver.global_basis.z).dot(direction)>.99,"Rowan turns toward an approaching player")
	game.truck.position=rail.driver.global_position+Vector3(-10,0,5)
	game.dialogue_actor=rail.driver
	rail._physics_process(1.0)
	direction=(game.truck.global_position-rail.driver.global_position).normalized()
	check((-rail.driver.global_basis.z).dot(direction)>.99,"Rowan keeps facing the truck while speaking")
	game.dialogue_actor=null
	game.travel.start(true)
	game.travel.finish()
	check(game.hud.toast_label.text.is_empty(),"Travel arrives without a welcome text popup")
	var race: ToyRaceTrack=game.travel.race
	await frames(3)
	check(RaceCourse.POND_RADIUS.x>=13 and RaceCourse.POND_RADIUS.y>=10,"The central pond is substantially larger")
	var centre:=RaceCourse.POND_CENTRE
	var floor:=RaceCourse.pond_surface(centre)
	check(floor.height< -2.3 and floor.gradient.length()<.001,"The pond has a recessed, level bottom")
	var smooth:=true
	for i in 201:
		var q:=i/200.0
		var p:=centre+Vector2(0,RaceCourse.POND_RADIUS.y*q)
		var surface:=RaceCourse.pond_surface(p)
		smooth=smooth and surface.gradient.length()<.55
		if i==200: smooth=smooth and absf(surface.height-.03)<.0001 and surface.gradient.length()<.0001
	check(smooth,"The basin has gentle continuous slopes with a flat rim")
	var space:=game.get_world_3d().direct_space_state
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(ToyRaceTrack.ORIGIN+Vector3(centre.x,2,centre.y),ToyRaceTrack.ORIGIN+Vector3(centre.x,-4,centre.y),1))
	check(not hit.is_empty() and hit.position.y< -2.3,"No flat ground collider fills the pond opening")
	check(race.props.filter(func(p): return p.kind=="tent").all(func(p): return p.home.origin.x<ToyRaceTrack.ORIGIN.x-55 and p.home.origin.z<5),"All tents form a camping area in the northwest")
	# Drive normally down the east beach and across the submerged floor.
	game.truck.use_automation=true
	game.truck.drive_guide=func(_v,_dt): return Vector3.LEFT
	pose(Vector3(centre.x+RaceCourse.POND_RADIUS.x+2,.83,centre.y))
	var lowest:=0.0
	var exited:=false
	for i in 300:
		await frames(1)
		var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
		lowest=minf(lowest,local.y)
		if local.x<centre.x-RaceCourse.POND_RADIUS.x-1:
			exited=local.y>.7
			break
	check(lowest< -1.4 and exited,"Normal steering drives into the pond and climbs smoothly out")
	# The underside blocks grass approaches before the cab intersects the deck.
	var path:=RaceCourse.points()
	var middle:=path[20*RaceCourse.STEPS]
	var side:=Vector3(-(path[20*RaceCourse.STEPS+1]-path[20*RaceCourse.STEPS-1]).z,0,(path[20*RaceCourse.STEPS+1]-path[20*RaceCourse.STEPS-1]).x).normalized()
	var underside:=space.intersect_ray(PhysicsRayQueryParameters3D.create(ToyRaceTrack.ORIGIN+middle+Vector3.DOWN*4,ToyRaceTrack.ORIGIN+middle,ToyRaceTrack.BRIDGE_SAFETY_LAYER))
	check(not underside.is_empty() and underside.collider.name=="BridgeSafetyCollision","The elevated road has a solid underside")
	var gate:=RaceCourse.gate_position(3)
	var tangent:=RaceCourse.gate_direction(3)
	var rail_side:=Vector3(-tangent.y,0,tangent.x)
	game.truck.drive_guide=func(_v,_dt): return rail_side
	pose(gate+Vector3.UP*.855)
	await frames(180)
	var truck: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
	var lateral: float=(truck-gate).dot(rail_side)
	check(lateral<7.5 and truck.y>6.8,"Bridge rail contact prevents the truck from falling off the deck")
	print("POND/BRIDGE: lowest truck y=",lowest," bridge lateral=",lateral," final y=",truck.y)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
