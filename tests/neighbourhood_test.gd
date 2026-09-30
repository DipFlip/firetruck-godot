extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func action(name: String) -> void:
	var event:=InputEventAction.new()
	event.action=name
	event.pressed=true
	game._unhandled_input(event)
func place(p: Vector3) -> void:
	game.truck.global_position=p
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.automated_drive=Vector2.ZERO
	game.truck.reset_physics_interpolation()
	await frames(10)
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://tests/"+name+".png")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	await place(TownLayout.JUNE+Vector3(0,1,4))
	check(game.dialogue_active and game.truck.enabled and not game.truck.freeze,"Proximity conversation preserves vehicle control")
	await frames(25)
	var head: Vector2=game.camera.unproject_position(game.dialogue_actor.global_position+Vector3.UP*2.85)
	check((game.hud.dialogue_panel.position+game.hud.dialogue_panel.tail_tip).distance_to(head)<2,"Speech bubble tail stays anchored above the actual speaker")
	check(game.hud.portrait.rotation==0 and game.hud.portrait.scale==Vector2.ONE and game.hud.portrait.material.get_shader_parameter("bob")!=Vector2.ZERO,"Portrait artwork bobs inside a stationary circular frame")
	check(not game.hud.hud_group.visible and game.hud.water_label.text.is_empty(),"Top-left text and numeric water readout are removed")
	game.truck.water=52
	await frames(40)
	check(absf(game.hud.shown_water-.52)<.02,"Horizontal water gauge tracks remaining water")
	shot("neighbour-dialogue")
	Input.action_press("jump")
	action("jump")
	check(game.hud.char_count==game.hud.full_text.length(),"Space reveals the conversation while retaining driving control")
	await frames(15)
	check(game.truck.charge==0,"Conversation Space cannot wind up a jump")
	Input.action_release("jump")
	game.truck.automated_aim=TownLayout.DOG+Vector3.UP*.7
	game.truck.automated_spray=true
	await frames(60)
	check(game.dialogue_active and game.truck.spraying and game.dog_progress>0,"Hose and water interactions keep working during conversation")
	game.truck.automated_spray=false
	await place(TownLayout.JUNE+Vector3(0,1,4))
	var start: Vector3=game.truck.position
	game.truck.heading=PI
	game.truck.rotation.y=PI
	for i in 180:
		var forward: Vector3=-game.camera.global_basis.z
		forward.y=0
		game.truck.automated_drive=Vector2(Vector3.BACK.dot(game.camera.global_basis.x),-Vector3.BACK.dot(forward.normalized()))
		await frames(1)
		if not game.dialogue_active: break
	check(not game.dialogue_active and game.truck.position.distance_to(start)>1 and game.truck.position.distance_to(TownLayout.JUNE)>9,"Driving away stops speech without taking control or blocking the job")
	game.truck.automated_drive=Vector2.ZERO
	await place(TownLayout.JUNE+Vector3(0,1,4))
	check(game.dialogue_active,"Returning to a neighbour allows another conversation")
	action("continue")
	action("continue")
	check(not game.dialogue_active,"Space or Enter can still finish a conversation normally")
	await place(Vector3(0,1,3.1))
	game.truck.heading=0
	game.truck.rotation.y=0
	game.truck.effects.tracks.clear()
	var min_clearance:=INF
	for i in 36:
		game.truck.linear_velocity=Vector3(8,0,0)
		await frames(1)
		for axle in game.truck.wheel_steers:
			var query:=PhysicsRayQueryParameters3D.create(axle.global_position,axle.global_position+Vector3.DOWN*2,9,[game.truck.get_rid()])
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
			if hit: min_clearance=minf(min_clearance,axle.global_position.y-.50-hit.position.y)
	var paving_marks:=0
	for mark in game.truck.effects.tracks:
		if absf(mark.mesh.position.z-4.8)<1.2 and mark.mesh.position.y>.17: paving_marks+=1
	check(paving_marks>=4,"Skid marks render on top of raised white intersection paving")
	check(min_clearance>=-.01,"All six tires clear the visible paving during a moving skid")
	shot("intersection-tracks")
	game.end_dialogue()
	check(game.ramps.ramps.size()==4,"Four rigid neighbourhood ramps are available")
	var upward_speeds: Array[float]=[]
	for ramp_index in game.ramps.ramps.size():
		var ramp: StaticBody3D=game.ramps.ramps[ramp_index]
		await place(ramp.global_transform*Vector3(0,1,12))
		game.truck.heading=ramp.rotation.y
		game.truck.rotation.y=ramp.rotation.y
		var max_up:=0.0
		var flew:=false
		var direction: Vector3=-ramp.global_basis.z
		for i in 240:
			var forward: Vector3=-game.camera.global_basis.z
			forward.y=0
			game.truck.automated_drive=Vector2(direction.dot(game.camera.global_basis.x),-direction.dot(forward.normalized()))
			await frames(1)
			max_up=maxf(max_up,game.truck.linear_velocity.y)
			var local: Vector3=ramp.to_local(game.truck.global_position)
			if local.z < -5 and game.truck.position.y>1.6 and not game.truck.grounded:
				flew=true
				if ramp_index==0: shot("ramp-flight")
				break
		upward_speeds.append(max_up)
		check(max_up>1.5 and flew and game.truck.charge==0,"Ramp %d launches the truck through collision physics alone" % (ramp_index+1))
	print("Ramp upward speeds: ",upward_speeds,"; moving tire clearance: ",min_clearance,"; paving marks: ",paving_marks)
	game.queue_free()
	await process_frame
	await process_frame
	print("NEIGHBOURHOOD CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
