extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func settle() -> void:
	for i in 240: game._process(1.0/60)
func pixel(point: Vector3) -> Vector2i:
	return Vector2i((Vector2(point.x,point.z)+Vector2.ONE*80)/160*1024)
func capture(name: String) -> Image:
	for i in 6: await process_frame
	RenderingServer.force_draw()
	var image:=root.get_texture().get_image()
	image.save_png("/tmp/firedriver-"+name+".png")
	return image
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.stage=1
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.sounds.set_process(false)
	game.truck.set_physics_process(false)
	game.truck.freeze=true
	game.truck.global_position=TownLayout.MAYA+Vector3(0,.855,8)
	game.truck.reset_physics_interpolation()
	await frames(3)
	settle()
	var cat_point: CameraPointOfInterest=game.town.cat.get_node("PippinCameraInterest")
	check(cat_point.weight==0 and game.conversation_blend>.99,"Maya attracts gradual zoom without activating the tree's scenery framing")
	check(game.camera_focus.distance_to(game.truck.global_position)<.02 and absf(game.camera.v_offset)<.001,"The camera remains centred on the truck beside Maya")
	game._talk_to_npc(0,true)
	settle()
	check(cat_point.weight==0 and game.camera_focus.distance_to(game.truck.global_position)<.02,"Maya's briefing retains the driving focus")
	game.end_dialogue()
	settle()
	check(cat_point.weight>.8,"Pippin becomes a scenery interest after Maya's briefing")
	# Exercise the real truck hull, not just a ray beneath the elevated branch.
	for car in game.life.cars: car.node.freeze=true
	game.truck.use_automation=true
	game.truck.global_position=Vector3(25,.855,-7.1)
	game.truck.rotation=Vector3(0,PI/2,0)
	game.truck.heading=PI/2
	game.truck.linear_velocity=Vector3.LEFT*6
	game.truck.reset_physics_interpolation()
	game.truck.freeze=false
	game.truck.enabled=true
	game.truck.set_physics_process(true)
	var passed:=false
	for i in 160:
		var forward: Vector3=-game.camera.global_basis.z
		forward.y=0
		game.truck.automated_drive=Vector2(Vector3.LEFT.dot(game.camera.global_basis.x),-Vector3.LEFT.dot(forward.normalized()))
		await frames(1)
		if game.truck.position.x<16.9:
			passed=true
			break
	check(passed and absf(game.truck.position.z+7.1)<1 and game.truck.position.y<1.2,"The truck drives beneath Pippin and the raised branch without an invisible wall")
	game.truck.automated_drive=Vector2.ZERO
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	var ray:=PhysicsRayQueryParameters3D.create(TownLayout.CAT_PERCH+Vector3.DOWN*3.5,TownLayout.CAT_PERCH+Vector3.UP,1)
	ray.exclude=[game.truck.get_rid()]
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.position.y>3.5,"The actual branch remains solid above the truck's clearance")
	check(game.town.people.all(func(actor): return actor.get_meta("omit_mat_print",false)) and game.dog_puddle.get_meta("omit_mat_print",false) and game.travel.race.people.all(func(actor): return actor.get_meta("omit_mat_print",false)),"People and the dog puddle are excluded from both carpet bakes")
	for is_race in [false,true]:
		if is_race:
			game.travel.start(true)
			game.travel._swap_world()
		else: game.intro.start()
		var prefix: String="race" if is_race else "maple"
		var full:=(load("res://assets/scenery/"+prefix+"_mat.png") as Texture2D).get_image()
		var clean:=(load("res://assets/scenery/"+prefix+"_mat_clean.png") as Texture2D).get_image()
		var timing:=(load("res://assets/scenery/"+prefix+"_mat_arrival.png") as Texture2D).get_image()
		var trees: Array=game.travel.assembly.filter(func(item): return not item.gpu and item.instance<0 and item.node is BreakableProp and item.node.kind=="tree")
		var correct: bool=trees.size()>10
		var differences:=0
		for tree in trees:
			var at: Vector3=tree.transform.origin-game.travel.assembly_origin
			var pos:=pixel(at)
			var schedule:=timing.get_pixelv(pos)
			correct=correct and schedule.b>.99 and absf(schedule.r-(tree.delay+tree.span*.48))<.01 and schedule.g>schedule.r
			if full.get_pixelv(pos)!=clean.get_pixelv(pos): differences+=1
		check(correct and differences>trees.size()/2,"The "+prefix+" print replaces each tree using its own landing interval")
		if is_race:
			var at:=pixel(Vector3(25,0,-54))
			var replacement:=timing.get_pixelv(at)
			check(replacement.b>.99 and replacement.g<.9 and clean.get_pixelv(at).g>clean.get_pixelv(at).r,"The raised race ribbon has a scheduled replacement with grass underneath")
		game.travel.grow_assembly(.42)
		check(is_equal_approx(game.travel.mat.finish.get_shader_parameter("arrival_progress"),.42) and is_equal_approx(game.travel.mat.print_fade.get_shader_parameter("arrival_progress"),.42),"Both carpet material paths follow the arrival clock")
		if DisplayServer.get_name()!="headless":
			root.size=Vector2i(1024,1024)
			game.hud.hide()
			game.miniature.hide()
			game.travel._hide_toys()
			game.camera.position=game.travel.assembly_origin+Vector3(0,200,0)
			game.camera.look_at(game.travel.assembly_origin,Vector3(0,0,-1))
			game.camera.size=160
			game.camera.far=450
			game.travel.mat.show_mat(is_race,0,game.travel.assembly_origin)
			game.travel.mat.set_arrival_progress(0)
			var before:=await capture(prefix+"-printed")
			game.travel.mat.set_arrival_progress(1)
			var after:=await capture(prefix+"-replaced")
			var changed:=0
			for tree in trees:
				var p:=pixel(tree.transform.origin-game.travel.assembly_origin)
				if before.get_pixelv(p)!=after.get_pixelv(p): changed+=1
			check(changed>trees.size()/2,"The actual Compatibility shader removes the printed trees on "+prefix)
			game.travel._show_toys()
			game.travel.assembly_camera(7 if is_race else 5.5,is_race)
			game.travel.grow_assembly(PlayMatTravel.arrival_progress(7 if is_race else 5.5,is_race))
			var arrival:=await capture(prefix+"-arrival-replacements")
			if is_race:
				var sample:=Vector2i(game.camera.unproject_position(ToyRaceTrack.ORIGIN+Vector3(25,.055,-54)))
				var road:=arrival.get_pixelv(sample)
				check(road.b>road.g*.8,"The 3D road stays visible above the replaced carpet print")
		game.travel.finish_assembly()
		if not is_race: game.intro.finish()
	game.queue_free()
	await process_frame
	await process_frame
	print("CARPET AND CLEARANCE: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
