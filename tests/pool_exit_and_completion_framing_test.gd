extends SceneTree

var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func settle() -> void:
	for i in 300:
		game._process(1.0/60)
		game.hud._position_dialogue(1.0/60)
func floor_at(x: float) -> float:
	var at: Vector3=TownLayout.POOL+Vector3(x,0,0)
	var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*3,at+Vector3.DOWN*3,1,[game.truck.get_rid()])
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else -100.0
func visible_actor(actor: Node3D) -> bool:
	var safe:=Rect2(Vector2(12,76),game.hud.size-Vector2(24,98))
	var bounds: Rect2=game.npc_screen_rect(actor)
	return safe.encloses(bounds) and (not game.hud.dialogue_panel.visible or not game.hud.dialogue_panel.get_global_rect().intersects(bounds))
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.dialogue_label.visible_characters=-1
	await frames(20)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/firedriver-"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.stage=4
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.rewards.set_process(false)
	game.truck.use_automation=true
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	await frames(3)
	check(TownLayout.POOL.z==63 and TownLayout.OLIVER.z==62 and game.town.people[3].position==TownLayout.OLIVER,"The pool and Oliver move five metres south together")
	check(game.town.pool_water.position.x==TownLayout.POOL.x and game.town.pool_water.position.z==TownLayout.POOL.z,"The baked water reference follows the relocated basin")
	var heights: Array[float]=[]
	for x in [-5.0,-4.0,-2.0,-.5,0.0]: heights.append(floor_at(x))
	check(absf(heights[0])<.02 and heights[1]>heights[2] and heights[2]>heights[3] and heights[3]>heights[4] and heights[4]< -1.2,"Real collision slopes continuously from the west lawn into the deep pool: "+str(heights))
	game.truck.global_position=TownLayout.POOL+Vector3(1,PoolBasin.FLOOR_Y+.85,0)
	game.truck.heading=PI/2
	game.truck.rotation.y=PI/2
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	var escaped:=false
	for i in 360:
		var forward: Vector3=-game.camera.global_basis.z
		forward.y=0
		game.truck.automated_drive=Vector2(Vector3.LEFT.dot(game.camera.global_basis.x),-Vector3.LEFT.dot(forward.normalized()))
		await frames(1)
		if game.truck.position.x<TownLayout.POOL.x-6 and game.truck.position.y>.5:
			escaped=true
			break
	check(escaped,"The truck drives out over the west slope without jumping")
	game.truck.automated_drive=Vector2.ZERO
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	game.camera.position=TownLayout.POOL+Vector3(20,25,28)
	game.camera.look_at(TownLayout.POOL+Vector3(0,0,-6))
	game.camera.size=32
	await capture("pool-west-exit")
	for is_race in [false,true]:
		if is_race:
			game.travel.start(true)
			game.travel.finish()
		var actors: Array[Node3D]=game.travel.race.people if is_race else game.town.people.duplicate()
		if not is_race: actors.append(game.railway.driver)
		for shape in [Vector2i(1280,800),Vector2i(390,564),Vector2i(320,390)]:
			root.size=shape
			await frames(3)
			for index in actors.size():
				var actor: Node3D=actors[index]
				# A hose-range truck on the opposite side of the task previously
				# left the thanking neighbour outside the scenery-only frame.
				game.truck.global_position=actor.global_position+Vector3(18,.85,8)
				game.truck.reset_physics_interpolation()
				await frames(1)
				var speaker: String=ToyRaceTrack.NAMES[index] if is_race else ["MAYA","LEO","JUNE","OLIVER","ROWAN"][index]
				game.rewards.celebrate("framing_%s_%s_%s" % [is_race,shape,index],actor.global_position,speaker,"Thank you for helping us!",false)
				settle()
				check(game.rewards.camera_interest.weight>.99 and visible_actor(actor),"Celebration includes "+speaker+" on "+str(shape))
				game.rewards._process(2)
				settle()
				check(game.dialogue_actor==actor and game.rewards.camera_interest.weight>.99 and visible_actor(actor),"Thank-you keeps "+speaker+" visible and clear of speech on "+str(shape))
				if not is_race and index==3 and shape.x==1280: await capture("pool-thank-you-framing")
				game.end_dialogue()
				settle()
				check(game.rewards.camera_interest.weight<.001,"Acknowledgement releases "+speaker+" completion focus")
	var first: Node3D=game.travel.race.people[1]
	var second: Node3D=game.travel.race.people[2]
	game.rewards.celebrate("queued_first",first.global_position,"SAMI","First thanks!",false)
	game.rewards.celebrate("queued_second",second.global_position,"NORA","Second thanks!",false)
	game.rewards._process(2)
	check(game.rewards.framing_actor()==first,"A queued completion cannot steal the current thanking NPC's focus")
	game.end_dialogue()
	game.rewards._process(0)
	check(game.rewards.framing_actor()==second,"The next queued celebration receives focus after acknowledgement")
	game.rewards._process(2)
	game.end_dialogue()
	game.queue_free()
	await frames(2)
	print("POOL EXIT AND COMPLETION FRAMING: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
