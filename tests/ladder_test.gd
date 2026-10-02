extends SceneTree
var game: Node3D
var failures:=0
var activations:=0
var generic_activations:=0
var generic_available:=false
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func action(name: String) -> void:
	var event:=InputEventAction.new()
	event.action=name
	event.pressed=true
	game._unhandled_input(event)
func place(p: Vector3) -> void:
	game.truck.position=p
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.heading=0
	game.truck.rotation.y=0
	game.truck.reset_physics_interpolation()
	await frames(5)
func close_dialogue() -> void:
	if game.dialogue_active: game.interact()
	if game.dialogue_active: game.interact()
func shot(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(path)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=1
	game.rescued=true # Maya's briefing is already heard in this scenario.
	game._update_mission()
	game.truck.use_automation=true
	game.cat_ladder_event.activated.connect(func(_engine: FireEngine): activations+=1)
	await place(Vector3(17,1,-3))
	await frames(45)
	check(not game.rescue_running and activations==0,"Approaching with a stowed ladder cannot rescue the cat")
	await place(Vector3(17,1,9))
	action("interact")
	await frames(380)
	check(game.truck.ladder_deployed and game.truck.ladder_amount>.99,"Ladder remains extended while driving toward a job")
	for i in 180:
		if game.rescue_running: break
		var forward: Vector3=-game.camera.global_basis.z
		forward.y=0
		game.truck.automated_drive=Vector2(Vector3.FORWARD.dot(game.camera.global_basis.x),-Vector3.FORWARD.dot(forward.normalized()))
		await physics_frame
	game.truck.automated_drive=Vector2.ZERO
	check(game.rescue_running and activations==1,"Driving an already-extended tip to Pippin triggers rescue without pressing E again")
	check(game.truck.ladder_tip.get_parent()==game.truck.ladder and game.truck.ladder_tip.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Tip collider keeps a fixed size outside the telescoping mesh")
	var tip: Vector3=game.truck.ladder_tip.global_position
	var stopped: Vector3=game.truck.position
	await frames(20)
	check(game.town.cat.position.distance_to(game.cat_home)>.1,"Pippin jumps from the branch toward the detected ladder tip")
	shot("res://tests/cat-boarding.png")
	action("pause")
	var cat_paused: Vector3=game.town.cat.global_position
	await frames(30)
	check(game.town.cat.global_position==cat_paused and game.truck.position==stopped,"Pause holds cat and ladder steady during boarding")
	action("pause")
	await frames(45)
	check(game.truck.freeze and game.truck.position.distance_to(stopped)<.01,"Truck remains steady after resuming the rescue")
	var cat_position: Vector3=game.town.cat.global_position
	check(cat_position.distance_to(tip)>.4 and cat_position.distance_to(game.truck.ladder.global_position)>.4,"Cat travels along the ladder between its tip and base")
	shot("res://tests/cat-climbing.png")
	action("interact")
	check(game.truck.ladder_busy and game.truck.ladder_deployed,"Retraction waits safely while the cat is on the ladder")
	await frames(200)
	check(game.cat_rescued and game.town.cat.get_parent()==game.town.people[0] and game.town.cat_cuddling,"Pippin hops down, bounds into Maya’s arms, and gets petted")
	check(not game.truck.ladder_deployed and not game.truck.freeze,"Ladder stows and truck is released after the rescue")
	check(game.hud.speaker_key=="MAYA" and game.barbecue_call_delay>0,"Maya thanks the player and schedules a later barbecue call")
	close_dialogue()
	check(game.stage==5 and activations==1,"Rescue enters a quiet exploration interval exactly once")
	# Return to the pre-rescue state to exercise recovery during the animation.
	game.cat_rescued=false
	game.stage=1
	game._cancel_cat_rescue()
	await place(Vector3(17,1,-3))
	action("interact")
	await frames(65)
	check(game.rescue_running,"Tip detection can start a fresh rescue")
	action("recover")
	await frames(180)
	check(not game.rescue_running and not game.cat_ladder_event.consumed and game.town.cat.global_position.is_equal_approx(game.cat_home) and game.stage==1,"Recovery cancels cleanly and rearms the rescue event")
	# A conversation must not block an otherwise ready ladder interaction.
	await place(Vector3(17,1,-3))
	game.talk("MAYA  /  MAPLE GREEN","Bring the tip close and Pippin will hop on.",1)
	action("interact")
	await frames(70)
	check(game.rescue_running,"An extended ladder can rescue while the neighbour is talking")
	check(not game.dialogue_active,"Boarding clears the speech bubble without requiring a button press")
	action("recover")
	await frames(10)
	# A different receiver uses the same tip interface, with no cat-specific input.
	game.stage=4
	action("interact")
	await frames(60)
	var receiver:=LadderEvent.new()
	receiver.position=game.truck.ladder_tip.global_position
	receiver.availability=func(): return generic_available
	receiver.activated.connect(func(_engine: FireEngine): generic_activations+=1)
	game.add_child(receiver)
	await frames(12)
	check(game.truck.ladder_tip.get_overlapping_areas().has(receiver) and generic_activations==0,"Tip detects an overlapping event while respecting availability")
	var wall:=StaticBody3D.new()
	var wall_shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(4,4,.4)
	wall_shape.shape=box
	wall.add_child(wall_shape)
	game.add_child(wall)
	wall.global_position=game.truck.ladder.global_position.lerp(receiver.global_position,.5)
	wall.look_at(receiver.global_position)
	await frames(3) # Let the physics server register the new obstacle first.
	generic_available=true
	await frames(12)
	check(generic_activations==0,"Solid obstacles block a rescue even when the tip overlaps its event")
	wall.queue_free()
	await frames(15)
	check(generic_activations==1,"Existing overlap activates when another ladder event becomes available")
	await frames(30)
	check(generic_activations==1,"Consumed ladder events cannot fire repeatedly")
	game.queue_free()
	await process_frame
	await process_frame
	print("LADDER CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
