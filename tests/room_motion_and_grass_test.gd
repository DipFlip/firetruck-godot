extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func capture(label: String) -> void:
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/firedriver-"+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.call_timer=0
	game.intro.start()
	check(game.life.birds.all(func(bird): return not bird.node.visible),"Airborne birds wait off-screen before the final pan")
	game.intro.update(20/PlayMatTravel.INTRO_PACE)
	var bird: Node3D=game.life.birds[0].node
	var before:=bird.position
	game.intro.update(.2)
	check(bird.visible and bird.position.distance_to(before)>.01,"Birds are already flying several seconds before control")
	before=bird.position
	game.intro.finish()
	check(bird.position.distance_to(before)<.001,"Bird flight pose remains continuous through handoff")
	var travel: PlayMatTravel=game.travel
	var fly_start:=PlayMatTravel.fly_in_start(false)
	var span:=3.8/1.5
	var smooth:=true
	for boundary in [fly_start,fly_start+span]:
		var points: Array[Vector3]=[]
		var lenses: Array[float]=[]
		for time in [boundary-.002,boundary-.001,boundary,boundary+.001,boundary+.002]:
			travel.assembly_camera(time,false)
			points.append(game.camera.position)
			lenses.append(game.camera.size)
		var a:=(points[2]-points[1])/.001
		var b:=(points[3]-points[2])/.001
		smooth=smooth and a.distance_to(b)<.5 and absf((lenses[2]-lenses[1])/.001-(lenses[3]-lenses[2])/.001)<.5
	check(smooth,"Opening zoom has continuous camera and lens velocity at both blend boundaries")
	travel.mat_camera(Vector3.ZERO,1)
	await capture("smaller-room")
	travel.start(true)
	travel._swap_world()
	travel.finish()
	travel.race.set_process(false)
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(8,.85,-32)
	game.truck.heading=0
	game.truck.rotation.y=0
	game.truck.use_automation=true
	game.truck.freeze=true
	await physics_frame
	await process_frame
	game.truck.freeze=false
	game.truck.grounded=true
	game.truck.linear_velocity=Vector3(0,0,-7)
	game.truck.steering=0
	var effects: TruckEffects=game.truck.effects
	effects.set_physics_process(false)
	effects.tracks.clear()
	effects._reset_contacts()
	effects.heading_initialized=false
	for i in 50:
		game.truck.position.z-=.11
		effects._physics_process(1.0/60)
	print("Grass track segments: ",effects.tracks.size(),"; contacts: ",effects.wheel_on_grass)
	check(effects.tracks.size()>8 and effects.tracks.all(func(mark): return mark.wheel>=2 and mark.start_left.y>=.054 and mark.end_left.y>=.054),"Normal driving lays two rear tracks above Motorway's visible grass")
	check(effects.tire_sound_strength==0,"Compressed grass tracks do not trigger skid squeal")
	game.camera.position=game.truck.global_position+Vector3(12,17,20)
	game.camera.look_at(game.truck.global_position+Vector3(0,0,3))
	game.camera.size=22
	await capture("grass-tracks")
	game.queue_free()
	await process_frame
	var preview: Node3D=load("res://scenes/model_blend_preview.tscn").instantiate()
	root.add_child(preview)
	for level in ToyBlending.OPTIONS:
		preview.slider.value=ToyBlending.OPTIONS.find(level)
		check(preview.softened.all(func(art): return art.visible==(level>0)),"Model slider selects %d%%"%level)
		if level in [0,50,100]: await capture("model-blend-%d"%level)
	preview.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
