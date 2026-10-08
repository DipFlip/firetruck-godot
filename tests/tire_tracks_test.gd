extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in n:
		for j in 5: game.proximity_latches[j]=true
		await physics_frame
		await process_frame
func clear_tracks() -> void:
	var effects: TruckEffects=game.truck.effects
	for t in effects.tracks: t.mesh.visible=false
	effects.tracks.clear()
	effects._reset_contacts()
	effects.heading_initialized=false
	effects.tire_sound_strength=0
	effects.tire_sound_hold=0
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.life.set_physics_process(false)
	game.truck.use_automation=true
	for car in game.life.cars: car.node.position=Vector3(500,0,500)
	game.truck.position=Vector3(-30,.85,-36)
	game.truck.heading=-PI/2
	game.truck.rotation.y=-PI/2
	await frames(5)
	var effects: TruckEffects=game.truck.effects
	game.truck.set_physics_process(false)
	effects.set_physics_process(false)
	# Freeze simulation integration while testing real wheel poses and ray hits.
	game.truck.freeze=true
	await frames(1)
	game.truck.freeze=false
	game.truck.set_physics_process(true)
	game.truck.grounded=true
	game.truck.steering=.4
	for i in 6: game.truck.wheel_steers[i].rotation.y=.4 if game.truck.front_axles[i] else 0
	game.truck.linear_velocity=Vector3(5,0,0)
	for i in 12:
		game.truck.position.x+=.08
		effects._physics_process(1.0/60)
	check(effects.tracks.is_empty() and effects.tire_sound_strength==0,"Slow steering leaves no marks or tire sound")
	clear_tracks()
	# With velocity aligned to the steered front tires, only the rear slides.
	game.truck.linear_velocity=-game.truck.wheel_steers[0].global_basis.z*12
	for i in 20:
		game.truck.position+=game.truck.linear_velocity/60
		effects._physics_process(1.0/60)
	check(not effects.tracks.is_empty() and effects.tracks.all(func(mark): return mark.wheel>=2),"Aligned front tires stay clear while the rear tires slip")
	clear_tracks()
	# Tire axes point along east, but the truck slides sideways to the north.
	game.truck.steering=0
	for wheel in game.truck.wheel_steers: wheel.rotation.y=0
	game.truck.linear_velocity=Vector3(10,0,-8)
	for i in 20:
		game.truck.position+=game.truck.linear_velocity/60
		effects._physics_process(1.0/60)
	var front:=0
	var rear:=0
	for mark in effects.tracks:
		if mark.wheel<2: front+=1
		else: rear+=1
	check(front>0 and rear>0,"Strong sideways slip lays front and rear tire marks")
	check(effects.tire_sound_strength>0,"Tire sound is active only after depositing marks")
	game.sounds._process(.1)
	var starts: int=game.sounds.counts.get("tire_scrub",0)
	for i in 20: game.sounds._process(.016)
	check(starts==1 and game.sounds.counts.get("tire_scrub",0)==starts,"Continuous skidding keeps one softly mixed tire loop, without retriggering")
	var count_before:=effects.tracks.size()
	game.truck.grounded=false
	effects._physics_process(1.0/60)
	check(effects.tracks.size()==count_before and effects.tire_sound_strength==0,"Airborne tires leave no marks or tire sound")
	game.truck.set_physics_process(false)
	clear_tracks()
	# A corner has identical shared boundaries and shade, rather than overlapping
	# alpha rectangles. Test the actual points passed to the rendered shader.
	var start:=Vector3(-20,.252,-36)
	var joint:=start+Vector3(1,0,0)
	var end:=joint+Vector3(.8,0,.6)
	effects._lay_track(0,start,joint,Vector3.UP,.5)
	effects._lay_track(0,joint,end,Vector3.UP,.6)
	var a: Dictionary=effects.tracks[0]
	var b: Dictionary=effects.tracks[1]
	check(a.end_left.is_equal_approx(b.start_left) and a.end_right.is_equal_approx(b.start_right),"Turning track segments share their edges exactly, with no striped overlaps or gaps")
	check(is_equal_approx(a.end_alpha,b.start_alpha),"Track shade is continuous across the shared edge")
	check(a.mesh.mesh==b.mesh.mesh,"Joined tracks still share one pooled GPU mesh")
	if DisplayServer.get_name()!="headless":
		# Display long, joined trails on asphalt for a close visual seam check.
		clear_tracks()
		for lane in 2:
			var point:=Vector3(-24,.252,-36+lane*.8)
			for i in 20:
				var next:=point+Vector3(.55,0,.04*i if i>11 else 0)
				effects._lay_track(lane,point,next,Vector3.UP,.7)
				point=next
		for track in effects.tracks: TownProps.effect_opacity(track.mesh,track.alpha)
		game.truck.freeze=true
		game.truck.position=Vector3(-40,.85,-36)
		game.set_process(false)
		game.travel.set_process(false)
		game.camera.position=Vector3(-17,10,-31)
		game.camera.look_at(Vector3(-17,.25,-34))
		game.camera.size=13
		await frames(3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://output/playwright/tire-tracks-native.png")
	effects.tire_sound_strength=0
	for i in 60: game.sounds._process(.016)
	check(not game.sounds.loop_active.tire_scrub and game.sounds.loop_levels.tire_scrub<.001,"Tire sound fades away when the skid ends")
	check(game.sounds.LEVELS.tire_scrub<=-30,"Tire scrub sits quietly below the engine and impacts")
	game.queue_free()
	await process_frame
	await process_frame
	print("TIRE CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
