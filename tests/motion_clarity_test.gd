# Run at 120 rendered frames / second against the normal 60 Hz physics loop.
extends SceneTree
var game: Node3D
var failures:=0
var samples: Array[Vector3]=[]
var raw_samples: Array[Vector3]=[]
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		for j in 5: game.proximity_latches[j]=true
		await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.truck.position=Vector3(-30,1,-36)
	game.truck.heading=-PI/2
	game.truck.reset_physics_interpolation()
	await frames(5)
	game.truck.automated_drive=Vector2(.875,-.484)
	await frames(65)
	for i in 48:
		for j in 5: game.proximity_latches[j]=true
		await process_frame
		samples.append(game.truck.get_global_transform_interpolated().origin)
		raw_samples.append(game.truck.global_position)
	var moving_between_ticks:=0
	var repeated_physics:=0
	for i in range(1,samples.size()):
		if raw_samples[i].distance_to(raw_samples[i-1])<.0001:
			repeated_physics+=1
			if samples[i].distance_to(samples[i-1])>.01: moving_between_ticks+=1
	print("Frames sharing a physics tick: ",repeated_physics,"; smoothly interpolated: ",moving_between_ticks)
	check(repeated_physics>10 and moving_between_ticks>10,"Truck renders intermediate poses between physics ticks")
	check(absf(game.camera.size-25.8)<.01,"Driving retains fixed camera zoom")
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://tests/clarity-driving.png")
	check(not root.use_taa,"Renderer uses no temporal image blending")
	game.truck.automated_drive=Vector2.ZERO
	game.truck.position=Vector3(-20,1,-36)
	game.truck.linear_velocity=Vector3(14,0,0)
	game.truck.heading=-PI/2
	game.truck.automated_drive=Vector2(0,-1)
	game.truck.reset_physics_interpolation()
	await frames(20)
	check(not game.truck.effects.tracks.is_empty(),"Hard turn creates skid marks")
	game.truck.automated_drive=Vector2.ZERO
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.freeze=true
	await frames(15)
	var marks: Array=game.truck.effects.tracks.duplicate()
	await frames(220)
	check(not game.truck.effects.tracks.is_empty(),"Skid marks remain visible before their five-second expiry")
	var fading:=false
	for mark in game.truck.effects.tracks:
		var opacity: float=mark.mesh.get_instance_shader_parameter("opacity")
		if opacity>0 and opacity<mark.alpha: fading=true
	check(fading,"Skid marks fade smoothly during their final 1.5 seconds")
	await frames(105)
	var hidden:=true
	for mark in marks: hidden=hidden and not mark.mesh.visible
	check(game.truck.effects.tracks.is_empty() and hidden,"Skid marks are fully gone after five seconds")
	game.truck.freeze=false
	game.truck.reset_truck()
	await process_frame
	check(game.truck.get_global_transform_interpolated().origin.distance_to(game.truck.position)<.1,"Recovery resets interpolation without a streak across town")
	game.queue_free()
	await process_frame
	await process_frame
	print("MOTION CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
