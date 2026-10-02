extends SceneTree

# Run with a real renderer and --disable-vsync, rather than --headless.
# Example: Godot --path . --rendering-method gl_compatibility --disable-vsync --script tools/benchmark.gd
var game: Node3D
var results: Array=[]

func _initialize() -> void: call_deferred("run")

func percentile(values: Array[float], fraction: float) -> float:
	values.sort()
	return values[mini(values.size()-1,int((values.size()-1)*fraction))]

func drive_straight() -> void:
	var forward: Vector3=-game.camera.global_basis.z
	forward.y=0
	forward=forward.normalized()
	var right: Vector3=game.camera.global_basis.x
	right.y=0
	game.truck.automated_drive=Vector2(right.normalized().dot(Vector3.RIGHT),-forward.dot(Vector3.RIGHT))

func sample(label: String, point: Vector3, spray: bool=false, driving: bool=false) -> void:
	game.end_dialogue()
	game.stage=4
	game.call_timer=0
	game.truck.freeze=not driving
	game.truck.automated_drive=Vector2.ZERO
	game.truck.heading=-PI/2 if driving else 0
	game.truck.position=point+Vector3.UP*.8
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	game.truck.automated_spray=spray
	game.truck.automated_aim=point+Vector3(0,0,-12)
	game.camera_focus=game.truck.position
	var warm_until:=Time.get_ticks_msec()+1500
	while Time.get_ticks_msec()<warm_until:
		for i in 5: game.proximity_latches[i]=true
		game.fire_progress=0
		if driving: drive_straight()
		await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			var folder:=arg.trim_prefix("--screenshots=")
			DirAccess.make_dir_recursive_absolute(folder)
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(folder+"/"+label+".png")
	var times: Array[float]=[]
	var physics_times: Array[float]=[]
	var calls: Array[float]=[]
	var primitives: Array[float]=[]
	var until:=Time.get_ticks_msec()+3000
	var previous:=Time.get_ticks_usec()
	while Time.get_ticks_msec()<until:
		for i in 5: game.proximity_latches[i]=true
		game.fire_progress=0
		if driving: drive_straight()
		await process_frame
		var now:=Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous=now
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var result:={"scene":label,"frames":times.size(),"truck_position":[game.truck.position.x,game.truck.position.z],"frame_ms_p50":percentile(times,.5),"frame_ms_p95":percentile(times,.95),"physics_ms":percentile(physics_times,.5),"draw_calls":percentile(calls,.5),"primitives":percentile(primitives,.5)}
	results.append(result)
	print("BENCHMARK ",JSON.stringify(result))

func run() -> void:
	root.size=Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.truck.use_automation=true
	game.truck.freeze=true
	game.barbecue_call_delay=-1
	game.rescued=true
	game.barbecue_briefed=true
	game.railway.briefed=true
	for i in 5: game.proximity_latches[i]=true
	await sample("station",Vector3(0,0,12))
	await sample("cat",TownLayout.MAYA+Vector3(0,0,6))
	await sample("barbecue",TownLayout.FIRE+Vector3(-7,0,5),true)
	await sample("pool",TownLayout.POOL+Vector3(-8,0,3),true)
	await sample("train",Vector3(-22,0,-63))
	await sample("driving",Vector3(-60,0,-36),false,true)
	var output:="/tmp/firedriver-benchmark.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.size.x,root.size.y],"results":results},"\t"))
	for player in [game.audio,game.music,game.water_audio]:
		if player: player.stop(); player.stream=null
	game.playback=null
	await create_timer(.3).timeout
	game.queue_free()
	await process_frame
	await process_frame
	quit()
