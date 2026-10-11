extends SceneTree
# Compatibility exercises the actual instanced water visuals as well as physics.
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.cat_rescued=true
	game.call_timer=0
	for car in game.life.cars: car.node.freeze=true
	var race: ToyRaceTrack=game.travel.race
	var hydrants: Array[BreakableProp]=game.interactions.hydrant_props.duplicate()
	hydrants.append(race.hydrant)
	check(hydrants.size()==8 and hydrants.all(func(p): return p is FireHydrant and p.scene_file_path=="res://scenes/fire_hydrant.tscn"),"Both maps instantiate one shared hydrant scene")
	check(hydrants.all(func(p): return p.impact_speed==8.0 and is_equal_approx(p.mass,.85) and p.respawn_seconds==5.0 and p.fade_in_seconds==.5),"Every hydrant shares its collision tuning and a five-second return with a faster fade-in")
	var trees: Array[BreakableProp]=[]
	trees.append_array(game.interactions.props.filter(func(p): return p.kind=="tree"))
	trees.append_array(race.props.filter(func(p): return p.kind=="tree"))
	check(trees.size()>game.interactions.props.filter(func(p): return p.kind=="tree").size() and trees.all(func(p): return p.impact_speed==BreakableProp.SETTINGS.tree.impact and is_equal_approx(p.mass,BreakableProp.SETTINGS.tree.mass) and p.respawn_seconds==10.0 and p.ground_effect!=null),"Every tree on both maps uses the shared threshold, mass, return timing and stump component")
	for is_race in [false,true]:
		if is_race:
			game.travel.start(true)
			game.travel.finish()
			race.set_process(false)
			race.set_physics_process(false)
		var hydrant: BreakableProp=race.hydrant if is_race else hydrants[0]
		var effect: PropGroundEffects=hydrant.ground_effect
		game.truck.use_automation=true
		game.truck.global_position=hydrant.home.origin+Vector3(0,.85,4)
		game.truck.linear_velocity=Vector3.ZERO
		game.truck.angular_velocity=Vector3.ZERO
		game.truck.rotation=Vector3.ZERO
		game.truck.heading=0
		game.truck.reset_physics_interpolation()
		await frames(3)
		check(not hydrant.knock(Vector3(7.9,0,0)),"Gentle bumps leave the "+("Motorway" if is_race else "Maple")+" hydrant anchored")
		game.truck.linear_velocity=Vector3(0,0,-12)
		await frames(30)
		check(hydrant.loose and effect.visible and effect.water!=null and effect.droplets.size()==96,"A real truck impact releases the "+("Motorway" if is_race else "Maple")+" hydrant and activates its water jet")
		var before:=effect.water.multimesh.get_instance_transform(0)
		await frames(10)
		check(not effect.water.multimesh.get_instance_transform(0).is_equal_approx(before) and effect.global_transform.is_equal_approx(hydrant.home),"The visible jet animates at the broken pipe while its hydrant tumbles away")
		game.paused=true
		var paused_age:=hydrant.age
		var paused_time:=effect.time
		await frames(5)
		check(hydrant.age==paused_age and effect.time==paused_time,"Pause freezes the shared hydrant and its water effect")
		game.paused=false
		game.truck.global_position=hydrant.home.origin+Vector3(0,.85,12)
		game.truck.linear_velocity=Vector3.ZERO
		game.truck.freeze=true
		# Exercise the real timer at its deadline, rather than waiting ten seconds.
		hydrant.age=4.85
		await frames(3)
		check(hydrant.loose and effect.visible,"The hydrant remains broken just before the shortened return deadline")
		await frames(12)
		check(not hydrant.loose and hydrant.appearing and not effect.visible and hydrant.global_transform.is_equal_approx(hydrant.home),"At five seconds the hydrant returns upright and stops spraying")
		await frames(32)
		check(not hydrant.appearing and hydrant.meshes.all(func(mesh): return mesh.transparency==0),"The shared hydrant becomes fully visible within half a second")
		game.truck.freeze=false
	# Tree size controls its art and footprint; its gameplay values and crown
	# formula come from the same factory on every mat.
	var motorway_tree: BreakableProp=race.props.filter(func(p): return p.kind=="tree")[0]
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(0,.85,-73)
	check(not motorway_tree.knock(Vector3.RIGHT*14.9) and motorway_tree.knock(Vector3.RIGHT*15.1),"Motorway trees resist and release at the shared tree threshold")
	await frames(2)
	check(motorway_tree.ground_effect.visible and motorway_tree.ground_effect.stump!=null,"The same cut stump appears under a toppled Motorway tree")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
