extends SceneTree
# Run with Compatibility so the real baked scenery vertex lanes are available.
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func arrival_end(item: Dictionary, race: bool) -> float:
	var start:=PlayMatTravel.RACE_ARRIVAL_START if race else PlayMatTravel.ARRIVAL_START
	return start+(item.delay+item.span)*(PlayMatTravel.ARRIVAL_END-start)
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.call_timer=0
	game.intro.start()
	var travel: PlayMatTravel=game.travel
	var dog:=travel.assembly.filter(func(item): return item.node==game.town.dog)
	check(dog.size()==1 and dog[0].drop and not dog[0].sprout and arrival_end(dog[0],false)<6.1,"Biscuit arrives as a complete falling toy during the cottage close-up")
	var southwest:=travel.assembly.filter(func(item): return item.node is BreakableProp and item.node.kind=="tree" and item.transform.origin.x< -40 and item.transform.origin.z>28)
	check(southwest.size()>=5 and southwest.all(func(item): return arrival_end(item,false)<=12.15 and item.delay>.35),"Every southwest tree lands during the camera's turn through its grove")
	var shared_schedule:=true
	var scheduled_vertices:=0
	for item in travel.assembly:
		if not item.gpu: continue
		var arrays: Array=item.node.mesh.surface_get_arrays(0)
		var pivots: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
		var timings: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var kinds: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in range(0,pivots.size(),31):
			var kind:=roundi(kinds[i].a*4)
			var at:=Vector3(pivots[i].x,0,pivots[i].y)
			shared_schedule=shared_schedule and absf(timings[i].x-(0.0 if kind==1 else PlayMatTravel.arrival_delay(at,kind)))<.002
			shared_schedule=shared_schedule and absf(timings[i].y-PlayMatTravel.arrival_span(at,kind))<.002
			scheduled_vertices+=1
	check(scheduled_vertices>100 and shared_schedule,"Batched shader geometry uses the same baked camera schedule as whole toys and their sound cues")
	var preserve_lods:=true
	for item in travel.assembly:
		if not item.gpu: continue
		var original: Array=item.original_mesh.get("_surfaces")[0].get("lods",[])
		var animated: Array=item.node.mesh.get("_surfaces")[0].get("lods",[])
		preserve_lods=preserve_lods and original.size()==animated.size()
		for i in original.size(): preserve_lods=preserve_lods and original[i]==animated[i]
	check(preserve_lods,"Arrival batches preserve every exported level-of-detail threshold and index buffer")
	game.intro.update((6.1)/PlayMatTravel.INTRO_PACE)
	check(game.town.dog.visible and game.town.dog.position.distance_to(TownLayout.DOG)<.001,"The dog has visibly landed before the cottage camera leaves")
	game.intro.finish()
	travel.start(true)
	travel._swap_world()
	var race: ToyRaceTrack=travel.race
	var roads:=travel.assembly.filter(func(item): return not item.gpu and item.node.has_meta("toy_pivot") and item.node.has_meta("assembly_group"))
	var gates:=travel.assembly.filter(func(item): return not item.gpu and item.node in race.gates)
	var road_end:=0.0
	for item in roads: road_end=maxf(road_end,arrival_end(item,true))
	# Some static gate parts share the paddock GPU batch, so also check its
	# authored pivot schedule rather than relying solely on complete CPU toys.
	var arches_supported:=roads.size()>=4
	for gate in race.gates:
		var at: Vector3=gate.position
		var impact:=PlayMatTravel.RACE_ARRIVAL_START+(PlayMatTravel.arrival_delay(at,3,true)+PlayMatTravel.arrival_span(at,3,true)*.68)*(PlayMatTravel.ARRIVAL_END-PlayMatTravel.RACE_ARRIVAL_START)
		arches_supported=arches_supported and road_end<impact
	check(arches_supported,"The complete road and bridge rise before any checkpoint arch lands")
	var board:=travel.assembly.filter(func(item): return item.node.name=="RecordBoard")
	check(board.size()==1 and arrival_end(board[0],true)<=5.2,"The complete personal-best display lands during the early start-gate view")
	var shack:=Vector3(65,0,24)
	var shack_end:=PlayMatTravel.RACE_ARRIVAL_START+(PlayMatTravel.arrival_delay(shack,2,true)+PlayMatTravel.arrival_span(shack,2,true))*(PlayMatTravel.ARRIVAL_END-PlayMatTravel.RACE_ARRIVAL_START)
	check(shack_end<=11.65,"The northern Snack Shack grows while the food court is framed")
	var stand: Node3D=race.get_node("ToyBuildings/WestAudiencePlatform")
	check(stand.position==ToyRaceTrack.WEST_STAND and (-stand.basis.z).dot(Vector3.BACK)>.99 and RaceCourse.distance_to_track(Vector2(stand.position.x,stand.position.z))>11,"The west audience sits north of the bend, faces south and leaves the road clear")
	check(ToyRaceTrack.BROADCAST_POINT.x>ToyRaceTrack.WEST_STAND.x+8 and RaceCourse.distance_to_track(Vector2(ToyRaceTrack.BROADCAST_POINT.x,ToyRaceTrack.BROADCAST_POINT.z))<15,"The broadcast camera is east of the relocated crowd and close to the racing ribbon")
	travel.finish()
	race.set_process(false)
	race.running=false
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(-29,.85,23)
	var rest:=race.broadcast_head.transform
	race._update_broadcast_camera(1)
	check(race.broadcast_head.transform.is_equal_approx(rest),"The broadcast camera does not follow free driving")
	race.running=true
	for i in 20: race._update_broadcast_camera(.05)
	var toward: Vector3=game.truck.global_position-race.broadcast_head.global_position
	check((-race.broadcast_head.global_basis.z).normalized().dot(toward.normalized())>.98 and absf(race.camera_operator.rotation.y-race.broadcast_pan)<.001,"The visible pan head and operator turn toward a passing active racer")
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(-55,.85,29)
	for i in 20: race._update_broadcast_camera(.05)
	toward=game.truck.global_position-race.broadcast_head.global_position
	check((-race.broadcast_head.global_basis.z).normalized().dot(toward.normalized())>.98,"The camera follows a racer across the bend rather than holding its first angle")
	race.running=false
	rest=race.broadcast_head.transform
	game.truck.global_position+=Vector3(12,0,4)
	race._update_broadcast_camera(1)
	check(race.broadcast_head.transform.is_equal_approx(rest),"Tracking stops immediately when the lap ends")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
