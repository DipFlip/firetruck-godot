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
func place(at: Vector3) -> void:
	game.truck.global_position=ToyRaceTrack.ORIGIN+at
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.travel.start(true)
	game.travel.finish()
	game.travel.set_process(false)
	game.truck.use_automation=true
	for prop in game.travel.race.props: prop.collision_layer=0; prop.collision_mask=0
	var path:=RaceCourse.points()
	var ramp:=path[17*RaceCourse.STEPS]
	var side: Vector3=game.travel.race._road_side(path,17*RaceCourse.STEPS)
	place(Vector3(ramp.x,.85,ramp.z)+side*13)
	game.truck.heading=atan2(side.x,side.z)
	game.truck.rotation.y=game.truck.heading
	game.truck.drive_guide=func(_v,_dt): return -side
	var hit_ceiling:=false
	var lowest_clearance:=INF
	for i in 150:
		await frames(1)
		for body in game.truck.get_colliding_bodies():
			if body.name=="BridgeSafetyCollision": hit_ceiling=true
		var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
		lowest_clearance=minf(lowest_clearance,(local-ramp).dot(side))
	check(hit_ceiling and lowest_clearance>8.0,"The physical cab hits the low bridge underside before entering the deck")
	var gate:=RaceCourse.gate_position(3)
	var forward:=RaceCourse.gate_direction(3)
	var tangent:=Vector3(forward.x,0,forward.y)
	var lateral:=Vector3(-forward.y,0,forward.x)
	place(gate+Vector3.UP*.85+lateral*6)
	game.truck.drive_guide=func(_v,_dt): return (tangent+lateral*.5).normalized()
	var peak_error:=0.0
	var peak_correction:=0.0
	for i in 120:
		await frames(1)
		var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
		var surface:=RaceCourse.surface_at(local)
		peak_error=maxf(peak_error,absf(local.y-surface.height-.8))
		var expected: float=surface.gradient.dot(Vector2(game.truck.linear_velocity.x,game.truck.linear_velocity.z))
		peak_correction=maxf(peak_correction,game.truck.linear_velocity.y-expected)
	check(peak_error<.05 and peak_correction<.6,"Driving along a curved bridge rail causes no bounce or upward launch")
	var space:=game.get_world_3d().direct_space_state
	var rail_tops_match:=true
	var air_above_clear:=true
	var beams_solid:=true
	for sign in [-1,1]:
		var rail_at: Vector3=ToyRaceTrack.ORIGIN+gate+lateral*sign*8.15
		var top:=space.intersect_ray(PhysicsRayQueryParameters3D.create(rail_at+Vector3.UP*3,rail_at+Vector3.UP*.5,ToyRaceTrack.BRIDGE_SAFETY_LAYER))
		rail_tops_match=rail_tops_match and not top.is_empty() and absf(top.position.y-gate.y-.82)<.005
		var start:=ToyRaceTrack.ORIGIN+gate
		var above:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3.UP,rail_at+lateral*sign*2+Vector3.UP,ToyRaceTrack.BRIDGE_SAFETY_LAYER))
		air_above_clear=air_above_clear and above.is_empty()
		var beam:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3.UP*.72,rail_at+lateral*sign*2+Vector3.UP*.72,ToyRaceTrack.BRIDGE_SAFETY_LAYER))
		beams_solid=beams_solid and not beam.is_empty()
	check(rail_tops_match and air_above_clear,"Both railing colliders end at the visible timber instead of an invisible wall")
	check(beams_solid,"The visible timber still blocks side contact")
	# Charge at rest, drive toward the edge, then jump through the clear air
	# above it using ordinary controls, away from the tall checkpoint columns.
	var jump_at:=path[19*RaceCourse.STEPS+12]
	var jump_side: Vector3=game.travel.race._road_side(path,19*RaceCourse.STEPS+12)
	place(jump_at+Vector3.UP*.855+jump_side*3)
	game.truck.heading=atan2(-jump_side.x,-jump_side.z)
	game.truck.rotation.y=game.truck.heading
	game.truck.drive_guide=func(_v,_dt): return Vector3.ZERO
	game.truck.jump_blocked_until_release=false
	await frames(10)
	Input.action_press("jump")
	await frames(30)
	game.truck.automated_drive=Vector2.UP
	game.truck.drive_guide=func(_v,_dt): return jump_side
	await frames(15)
	Input.action_release("jump")
	var jump_contact:=false
	var jump_lateral:=0.0
	var jump_height:=0.0
	for i in 60:
		await frames(1)
		var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
		jump_lateral=maxf(jump_lateral,(local-jump_at).dot(jump_side))
		jump_height=maxf(jump_height,local.y-jump_at.y-.855)
		for body in game.truck.get_colliding_bodies():
			if body.name=="BridgeSafetyCollision": jump_contact=true
	check(jump_lateral>10.5 and jump_height>1.5 and not jump_contact,"A normally charged driving jump clears the complete railing without hitting hidden collision")
	print("BRIDGE CONTACT: underside lateral=",lowest_clearance," rail support error=",peak_error," vertical correction=",peak_correction)
	print("RAIL JUMP: lateral=",jump_lateral," height=",jump_height," contact=",jump_contact)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
