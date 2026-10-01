extends SceneTree

var game: Node3D
var failures:=0

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1

func approach(origin: Vector3, speaker: String) -> void:
	game.end_dialogue()
	game.truck.automated_drive=Vector2.ZERO
	var direction:=Vector3(22,0,26).normalized()
	game.truck.position=origin+direction*9+Vector3.UP*.85
	game.truck.heading=atan2(direction.x,direction.z)
	game.truck.rotation.y=game.truck.heading
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	game.camera_focus=origin
	game.talk(speaker,"Hello! Keep a little room so we can see each other.",1)
	await frames(70)
	for i in 150:
		var forward: Vector3=-game.camera.global_basis.z
		forward.y=0
		var desired: Vector3=origin-game.truck.position
		desired.y=0
		desired=desired.normalized()
		game.truck.automated_drive=Vector2(desired.dot(game.camera.global_basis.x),-desired.dot(forward.normalized()))
		await frames(1)
	game.truck.automated_drive=Vector2.ZERO
	await frames(10)

func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=1
	game.rescued=true
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	for i in 4: game.proximity_latches[i]=true
	await frames(3)
	for i in game.town.people.size():
		var person: Node3D=game.town.people[i]
		var speaker: String=["MAYA","LEO","JUNE","OLIVER"][i]
		# Oliver's camera-side approach crosses the pool basin. Isolate his
		# physics boundary on open ground rather than testing the pool's walls.
		if i==3:
			person.global_position=Vector3(-12,0,-52)
			game.interactions.npc_guards[i].global_position=person.global_position
		await approach(person.global_position,speaker)
		var toward_camera:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
		var separation: float=(game.truck.position-person.global_position).dot(toward_camera)
		check(separation>4,"Camera-side approach stops clear of "+speaker+" ("+str(snappedf(separation,.01))+" m)")
		var head: Vector2=game.camera.unproject_position(person.global_position+Vector3.UP*2.2)
		check(not game.hud.truck_screen_rect().has_point(head),speaker+" stays visible above the truck during conversation")
		check(game._nearest_npc()==i,"Space can still reach "+speaker+" outside the larger boundary")
		if DisplayServer.get_name()!="headless" and i==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/firedriver-npc-clearance.png")
	var cat_origin:=Vector3(game.cat_home.x,0,game.cat_home.z)
	await approach(cat_origin,"MAYA")
	var toward_camera:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
	check((game.truck.position-cat_origin).dot(toward_camera)>4,"The cat tree also reserves room on the camera side")
	check(not game.hud.truck_screen_rect().has_point(game.camera.unproject_position(game.town.cat.global_position+Vector3.UP*.6)),"The truck cannot hide the cat on the branch")
	var direction: Vector3=game.interactions.npc_guards[0].global_basis.z
	check(direction.dot(toward_camera)>.999,"Protective zones turn with the conversation camera angle")
	game.queue_free()
	await process_frame
	await process_frame
	print("VISIBILITY GUARD CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
