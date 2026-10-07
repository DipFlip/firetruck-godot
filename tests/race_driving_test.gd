extends SceneTree

var game: Node3D
var target:=RaceCourse.STEPS+1
var lap_seen:=false
var passed_bridge:=false
var highest:=0.0
var flat_vertical_speed:=0.0
var flat_height_step:=0.0
var previous_y:=.85
var previous_surface_height:=0.0
var surface_error:=0.0
var slope_velocity_error:=0.0
var bridge_contact:=true
var underpass_clear:=false
var flat_peak_at:=Vector3.ZERO
var failures:=0
var record_backup: PackedByteArray
var had_record:=false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func guide(_desired: Vector3, _dt: float) -> Vector3:
	var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
	var path:=RaceCourse.points()
	var point: Vector3=path[target]
	if Vector2(local.x-point.x,local.z-point.z).length()<4:
		target=(target+3)%(path.size()-1)
		point=path[target]
	return Vector3(point.x-local.x,0,point.z-local.z).normalized()
func run() -> void:
	had_record=FileAccess.file_exists(ToyRaceTrack.SAVE_PATH)
	if had_record: record_backup=FileAccess.get_file_as_bytes(ToyRaceTrack.SAVE_PATH)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.intro.finish()
	game.travel.start(true)
	game.travel.finish()
	game.travel.set_process(false)
	game.truck.use_automation=true
	game.truck.top_speed=15
	game.truck.drive_guide=guide
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(-4,.85,-54)
	game.truck.heading=-PI/2
	game.truck.rotation.y=-PI/2
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	game.travel.race.previous=Vector2(-4,-54)
	for i in 5200:
		await physics_frame
		await process_frame
		var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
		highest=maxf(highest,local.y)
		if i>30:
			var surface:=RaceCourse.surface_at(local)
			surface_error=maxf(surface_error,absf(local.y-surface.height-.8))
			var gradient: Vector2=surface.gradient
			if surface.height>.2: bridge_contact=bridge_contact and game.truck.suspension_grounded
			var expected_speed:=gradient.dot(Vector2(game.truck.linear_velocity.x,game.truck.linear_velocity.z))
			slope_velocity_error=maxf(slope_velocity_error,absf(game.truck.linear_velocity.y-expected_speed))
			if surface.height<.06 and gradient.length()<.001:
				if absf(previous_surface_height-surface.height)<.001:
					flat_height_step=maxf(flat_height_step,absf(local.y-previous_y))
				if absf(game.truck.linear_velocity.y)>flat_vertical_speed:
					flat_vertical_speed=absf(game.truck.linear_velocity.y)
					flat_peak_at=local
			if local.distance_to(RaceCourse.points()[8*RaceCourse.STEPS]+Vector3.UP*.85)<3:
				underpass_clear=local.y<1.1
		previous_y=local.y
		previous_surface_height=RaceCourse.surface_at(local).height
		if game.travel.race.running: lap_seen=true
		if game.travel.race.checkpoint==0: passed_bridge=true
		if game.travel.race.last_time>0: break
	check(lap_seen,"Real steering and rigid-body motion cross the start arch")
	check(highest>7 and passed_bridge,"The truck drives up the ramp and crosses the elevated gate")
	check(game.travel.race.last_time>0,"Following the complete winding course earns a timed lap without teleporting")
	check(flat_height_step<.005,"Actual chassis height on flat asphalt changes by less than five millimetres per frame")
	check(surface_error<.08 and slope_velocity_error<.5,"Both curved bridge approaches follow the continuous surface without contact spikes")
	check(bridge_contact,"Suspension remains grounded while driving up and down the bridge")
	check(underpass_clear,"The lower crossing stays on the ground beneath the bridge")
	print("SURFACE: flat chassis step=",flat_height_step," solver vertical speed=",flat_vertical_speed," height error=",surface_error," slope velocity error=",slope_velocity_error," flat peak at=",flat_peak_at)
	game.truck.drive_guide=Callable()
	game.truck.automated_drive=Vector2.ZERO
	game.truck.global_position=ToyRaceTrack.ORIGIN+RaceCourse.gate_position(3)+Vector3.UP*.855
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.jump_blocked_until_release=false
	for i in 15: await physics_frame
	Input.action_press("jump")
	for i in 45: await physics_frame
	Input.action_release("jump")
	for i in 18: await physics_frame
	check(game.truck.global_position.y>9,"Charged jumps still leave the new bridge surface")
	for i in 150: await physics_frame
	check(absf(game.truck.global_position.y-7.855)<.08,"The truck lands back on the bridge instead of falling through it")
	print("DRIVING: height=",highest," last=",game.travel.race.last_time," target=",target," truck=",game.truck.global_position-ToyRaceTrack.ORIGIN)
	if had_record:
		var restore:=FileAccess.open(ToyRaceTrack.SAVE_PATH,FileAccess.WRITE)
		restore.store_buffer(record_backup)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(ToyRaceTrack.SAVE_PATH))
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
