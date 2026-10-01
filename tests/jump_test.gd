extends SceneTree
var game: Node3D
var failures:=0
var min_tire_clearance:=INF
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://tests/jump-"+label+".png")
func tire_clearance() -> void:
	for wheel in game.truck.wheel_steers:
		var probe:=PhysicsRayQueryParameters3D.create(wheel.global_position,wheel.global_position+Vector3.DOWN*5,1,[game.truck.get_rid()])
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(probe)
		if hit: min_tire_clearance=minf(min_tire_clearance,wheel.global_position.y-.50-hit.position.y)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.truck.position=Vector3(0,1,12)
	await frames(90)
	var t: FireEngine=game.truck
	var preview:=Camera3D.new()
	preview.projection=Camera3D.PROJECTION_ORTHOGONAL
	preview.size=9.5
	game.add_child(preview)
	preview.position=t.position+Vector3(12,5,7)
	preview.look_at(t.position+Vector3.UP*.8)
	preview.current=true
	game.hud.hide()
	await frames(3)
	await process_frame
	# Measure the cab roof mount; the ladder now hinges lower on the rear deck.
	var resting_y:=t.cannon.global_position.y
	var wheel_y:=t.wheel_steers[0].global_position.y
	shot("rest")
	Input.action_press("jump")
	await frames(60)
	tire_clearance()
	check(resting_y-t.cannon.global_position.y>.27,"Charging compresses the upper body by about 30 cm")
	check(absf(t.visual.position.y)<.015 and is_equal_approx(t.body_point(Vector3(1,.28,-1.3)).y,.28),"Lower body and wheel arches retain their unsquashed silhouette")
	check(absf(t.wheel_steers[0].global_position.y-wheel_y)<.025,"Charge compression keeps tires planted at their original height")
	check(t.cannon.position.distance_to(t.visual.transform*t.body_point(t.CANNON_MOUNT))<.001 and t.ladder.position.distance_to(t.visual.transform*t.body_point(t.LADDER_MOUNT))<.001,"Roof cannon and ladder mount follow the compressed upper body")
	shot("charged")
	Input.action_release("jump")
	var max_height:=0.0
	var max_up_pitch:=0.0
	var min_down_pitch:=0.0
	var min_landing_offset:=0.0
	var rebound:=0.0
	var took_off:=false
	var cleared_ground:=false
	var landed:=false
	var rise_shot:=false
	var fall_shot:=false
	var land_shot:=false
	for i in 180:
		await physics_frame
		await process_frame # Inspect the completed visual pose, after physics callbacks.
		tire_clearance()
		max_height=maxf(max_height,t.position.y)
		if t.linear_velocity.y>2:
			took_off=true
			max_up_pitch=maxf(max_up_pitch,t.visual.rotation.x)
			if not rise_shot and t.visual.rotation.x>.09:
				shot("rising")
				rise_shot=true
		if took_off and t.linear_velocity.y < -2 and not t.suspension_grounded:
			min_down_pitch=minf(min_down_pitch,t.visual.rotation.x)
			if not fall_shot and t.visual.rotation.x < -.065:
				shot("falling")
				fall_shot=true
		if t.ground_distance>1.25: cleared_ground=true
		if cleared_ground and t.suspension_grounded: landed=true
		if landed:
			min_landing_offset=minf(min_landing_offset,t.suspension_offset)
			rebound=maxf(rebound,t.suspension_offset)
			if not land_shot and t.suspension_offset < -.10:
				shot("landing")
				land_shot=true
	print("Jump measured: rise pitch=",rad_to_deg(max_up_pitch)," descent pitch=",rad_to_deg(min_down_pitch)," landing compression=",min_landing_offset," tire clearance=",min_tire_clearance," rebound=",rebound)
	check(max_height>2.2 and landed,"Charged jump still follows a full physical flight and landing")
	check(max_up_pitch>deg_to_rad(5),"Front of the truck rises visibly during ascent")
	check(min_down_pitch < -deg_to_rad(3),"Front tips down as the truck descends")
	check(min_landing_offset < -.10,"Landing compresses the body over the planted wheels")
	check(min_tire_clearance>=-.015,"All six tires stay above the ground through charge, flight and touchdown")
	check(absf(t.suspension_offset)<.005 and absf(t.jump_pitch)<.005,"Suspension and pitch settle back to rest after landing")
	# Recovery mid-charge clears the old pose and cannot release a stored hop.
	Input.action_press("jump")
	await frames(40)
	t.reset_truck()
	Input.action_release("jump")
	await frames(10)
	check(t.charge==0 and t.linear_velocity.y<1 and absf(t.jump_pitch)<.01,"Recovery clears charge and jump animation without an accidental hop")
	game.queue_free()
	await process_frame
	await process_frame
	print("JUMP CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
