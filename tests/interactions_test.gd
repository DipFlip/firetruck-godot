extends SceneTree

var game: Node3D
var failures:=0
var native:=false
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func capture(file: String) -> void:
	if not native: return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://tests/"+file+".png")
func place(at: Vector3) -> void:
	game.end_dialogue()
	game.truck.global_position=at
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.heading=0
	game.truck.rotation.y=0
	game.truck.reset_physics_interpolation()
	await frames(3)
func impact(prop: BreakableProp, speed: float) -> void:
	prop.global_transform=Transform3D(Basis.IDENTITY,Vector3(-12,0,-52))
	prop.home=prop.global_transform
	prop.reset_physics_interpolation()
	await place(Vector3(-12,.85,-49.4))
	game.truck.linear_velocity=Vector3(0,0,-speed)
	await frames(45)

func run() -> void:
	native=DisplayServer.get_name()!="headless"
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.cat_rescued=true
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.freeze=true
	await frames(5)
	var counts: Dictionary={}
	var complete:=true
	for prop in game.interactions.props:
		counts[prop.kind]=int(counts.get(prop.kind,0))+1
		complete=complete and not prop.meshes.is_empty()
	print("Interactive props: ",counts)
	check(complete and counts.tree==51 and counts.lamp==12 and counts.bush==90 and counts.bench==3 and counts.hydrant==7 and counts.fence==4 and counts.planter==4,"Town trees, lamps, shrubs, benches, hydrants, fences and planters have attached art and physics")
	for job in ["fire","dog","pool"]:
		var index: int={"fire":1,"dog":2,"pool":3}[job]
		await place(game.town.people[index].global_position+Vector3(0,1,3.4))
		game.end_dialogue()
		game.proximity_latches[index]=true
		game.truck.freeze=true
		game.camera_focus=game.truck.position
		if job=="fire": game._water_hit(TownLayout.FIRE+Vector3.UP*1.8,20)
		elif job=="dog": game._water_hit(TownLayout.DOG+Vector3.UP*.7,20)
		else: game._water_hit(TownLayout.POOL+Vector3.UP*game.town.pool_water.position.y,20)
		check(not game.dialogue_active and game.rewards.sparkles.size()==28,"Completing "+job+" immediately starts sparkles without interrupting with speech")
		await frames(35)
		await capture("reward-"+job)
		await frames(60)
		check(not game.dialogue_active,"The "+job+" reward has its own moment before the thank-you")
		await frames(25)
		check(game.dialogue_active and game.hud.speaker_key==["MAYA","LEO","JUNE","OLIVER"][index],"The "+job+" neighbour thanks the player after the reward")
		game.end_dialogue()
		game.truck.freeze=false
	check(game.rewards.completed.size()==3 and game.rewards.sound.stream.get_length()>1,"Each water job rewards once with a complete melodic chime")
	game._water_hit(TownLayout.DOG+Vector3.UP*.7,20)
	check(game.rewards.pending.is_empty() and game.rewards.sparkles.is_empty(),"Continuing to spray a completed job never repeats its reward")
	var bush: BreakableProp
	var lamp: BreakableProp
	var tree: BreakableProp
	for prop in game.interactions.props:
		if prop.kind=="bush" and not bush: bush=prop
		if prop.kind=="lamp" and not lamp: lamp=prop
		if prop.kind=="tree" and not prop.protected_cat_tree and not tree: tree=prop
	await impact(tree,12)
	check(not tree.loose and game.truck.position.z>tree.position.z+1,"A medium-speed truck impact cannot knock down the sturdier tree")
	await impact(tree,19)
	check(tree.loose and tree.global_position.distance_to(tree.home.origin)>.5 and tree.global_basis.y.dot(Vector3.UP)<.95,"A fast actual truck collision releases and tips the tree under rigid-body physics")
	check(game.truck.linear_velocity.length()<19,"Breaking a tree costs the truck some momentum")
	var stump: PropGroundEffects=game.interactions.ground_effects.filter(func(effect): return effect.prop==tree)[0]
	await process_frame
	check(stump.visible and stump.stump!=null and stump.global_transform.is_equal_approx(tree.home),"Toppling leaves a cut stump anchored at the original trunk position")
	await place(Vector3(-9,1,-44))
	game.camera_focus=tree.home.origin+Vector3.UP
	await capture("tree-impact")
	var age:=tree.age
	game.paused=true
	await frames(2)
	var stopped:=tree.global_transform
	await frames(30)
	check(tree.age==age and tree.global_transform.is_equal_approx(stopped),"Pause freezes loose props and their respawn clock")
	game.paused=false
	await frames(int(maxf(0,9-tree.age)*60))
	check(tree.loose and tree.meshes[0].transparency>.35 and tree.meshes[0].transparency<.7,"Old fallen prop visibly fades before its ten-second reset")
	await place(tree.home.origin+Vector3.UP*.85)
	game.truck.freeze=true
	await frames(100)
	check(tree.loose and tree.collision_layer==0,"Respawn waits while the truck occupies the original spot")
	game.truck.freeze=false
	await place(Vector3(-9,1,-44))
	await frames(35)
	check(not tree.loose and tree.appearing and tree.global_transform.is_equal_approx(tree.home) and tree.meshes[0].transparency>0,"Prop fades back in upright at its original transform once clear")
	await frames(65)
	check(not tree.appearing and tree.freeze and tree.meshes[0].transparency==0,"Respawn restores solid, reusable scenery")
	await process_frame
	check(not stump.visible,"The stump disappears as the original tree returns")
	# Move completed fixtures away so the next collision is isolated.
	tree.global_position=Vector3(-72,0,-52)
	tree.home=tree.global_transform
	await impact(lamp,3)
	check(not lamp.loose,"Lamp posts resist gentle bumps")
	await impact(lamp,8)
	check(lamp.loose,"Lamp posts topple at a medium impact speed")
	lamp.global_position=Vector3(-72,0,-48)
	await impact(bush,3)
	check(bush.loose,"Bushes give way at low impact speed")
	bush.global_position=Vector3(-72,0,-44)
	var hydrant: BreakableProp=game.interactions.hydrant_props[0]
	await impact(hydrant,12)
	var jet: PropGroundEffects=game.interactions.ground_effects.filter(func(effect): return effect.prop==hydrant)[0]
	await process_frame
	check(hydrant.loose and jet.visible and jet.water!=null and jet.global_position.is_equal_approx(hydrant.home.origin),"A knocked-over hydrant sprays water upward from the broken ground pipe")
	var jet_time:=jet.time
	await frames(20)
	await process_frame
	check(jet.time>jet_time+.1 and jet.global_position.is_equal_approx(hydrant.home.origin),"The jet animates while staying behind the tumbling hydrant")
	await capture("hydrant-geyser")
	game.paused=true
	await process_frame
	jet_time=jet.time
	await frames(20)
	await process_frame
	check(jet.time==jet_time,"Pause holds the broken-hydrant spray still")
	game.paused=false
	await place(hydrant.home.origin+Vector3.UP*.85)
	game.truck.freeze=true
	await frames(660)
	await process_frame
	check(hydrant.loose and jet.visible and jet.time>10,"A broken pipe keeps spraying if traffic delays the hydrant's return")
	game.truck.freeze=false
	await place(Vector3(-9,1,-44))
	await frames(90)
	await process_frame
	check(not hydrant.loose and not jet.visible,"The water jet shuts off when the hydrant respawns")
	await place(TownLayout.MAYA+Vector3(0,1,4.5))
	game.truck.linear_velocity=Vector3(0,0,-12)
	await frames(35)
	check(game.truck.position.z>TownLayout.MAYA.z+1.5,"Quest NPC personal space physically stops the truck before overlap")
	check(game.interactions.npc_guards.size()==4,"All four quest neighbours have small protective boundaries")
	await place(Vector3(-12,1,-47))
	var car: Dictionary=game.life.cars[0]
	car.node.global_position=Vector3(-12,.02,-52)
	car.node.rotation=Vector3.ZERO
	car.node.linear_velocity=Vector3.ZERO
	car.node.freeze=false
	game.truck.linear_velocity=Vector3(0,0,-13)
	await frames(45)
	check(car.node.position.z< -54 and car.node.linear_velocity.z< -1,"Other cars are pushed by actual rigid-body contact")
	await place(Vector3(0,1,-48))
	var walker: Dictionary=game.life.walkers[0]
	walker.node.position=Vector3(0,.16,-56)
	walker.cooldown=0
	walker.hop=1
	game.truck.linear_velocity=Vector3(0,0,-15)
	game.life.set_physics_process(true)
	var highest:=0.0
	var clearance:=INF
	for i in 70:
		await physics_frame
		highest=maxf(highest,walker.node.position.y)
		var local: Vector3=game.truck.to_local(walker.node.global_position)
		var nearest:=Vector2(local.x,local.z-clampf(local.z,-1.25,1.25))
		clearance=minf(clearance,nearest.length())
		if i==12: await capture("pedestrian-dodge")
	check(highest>.65 and absf(walker.node.position.x)>2,"Pedestrians visibly jump sideways before an approaching truck arrives")
	check(clearance>1.5,"Pedestrians remain outside the truck silhouette throughout the encounter")
	game.queue_free()
	await process_frame
	await process_frame
	print("INTERACTION CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
