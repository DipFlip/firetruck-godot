extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func settle(seconds: float=2.0) -> void:
	for i in int(seconds*60):
		game._process(1.0/60)
		game.hud._position_dialogue(1.0/60)
func place(at: Vector3) -> void:
	game.truck.global_position=at
	game.truck.reset_physics_interpolation()
	await physics_frame
	await process_frame
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.set_process(false)
	game.set_physics_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	for i in 5: game.proximity_latches[i]=true
	for point in game.camera_framing.points: point.enabled=false
	var blends: Array[float]=[]
	var lenses: Array[float]=[]
	for distance in [31.0,26.0,21.0,16.0,11.0,8.1]:
		await place(TownLayout.MAYA+Vector3(0,.85,distance))
		settle()
		blends.append(game.conversation_blend)
		lenses.append(game.camera.size)
	check(not game.dialogue_active and blends[0]==0 and blends[1]>.05 and blends[2]>blends[1] and blends[3]>blends[2] and blends[4]>blends[3] and blends[5]>.99,"Camera attention increases continuously during approach before any conversation starts")
	check(lenses[1]<lenses[0] and lenses[2]<lenses[1] and lenses[3]<lenses[2],"Approaching a talker progressively tightens the lens instead of switching at the greeting radius: "+str(lenses))
	var before: float=game.camera.size
	game.talk("MAYA","Hello there!",1)
	settle(.2)
	check(absf(game.camera.size-before)<.2,"Starting speech at close range does not trigger a second zoom")
	game.end_dialogue()
	settle()
	check(game.conversation_blend>.99 and game.camera.size<20,"Closing a balloon keeps the nearby view until the truck actually drives away")
	await place(TownLayout.MAYA+Vector3(0,.85,31))
	settle(3)
	check(game.conversation_blend<.001 and absf(game.camera.size-25.8)<.01,"Leaving the neighbourhood restores the regular driving view smoothly")
	for point in game.camera_framing.points: point.enabled=true
	game.pool_camera_interest.engage(60)
	for shape in [Vector2i(1280,800),Vector2i(390,564),Vector2i(844,390)]:
		root.size=shape
		game.hud.touch_mode=shape.x<1100
		game.hud.touch_portrait=shape.x<shape.y
		await process_frame
		await process_frame
		for offset in [Vector3(-22,.85,4),Vector3(0,.85,14),Vector3(14,.85,4)]:
			await place(TownLayout.POOL+offset)
			settle(4)
			var safe:=Rect2(Vector2(16,76),game.hud.size-Vector2(32,98))
			var visible:=safe.encloses(game.hud.truck_screen_rect())
			for corner in game.pool_camera_interest.world_bounds(): visible=visible and safe.has_point(game.camera.unproject_position(corner))
			check(visible,"The truck and complete pool fit while filling on "+str(shape)+" from "+str(offset))
		await place(TownLayout.OLIVER+Vector3(0,.85,8))
		game.talk("OLIVER","The kids are coming over! Could you fill the pool? Spray into the tiles and watch the water rise.",1)
		settle(4)
		var panel: SpeechFrame=game.hud.dialogue_panel
		var card:=Rect2(panel.position,panel.size)
		check(not card.intersects(game.hud.truck_screen_rect()) and not card.intersects(game.camera_framing.screen_rect(game.camera,game.truck.global_position)),"The conversation balloon leaves both truck and mission scenery clear on "+str(shape))
		game.end_dialogue()
	var extra:=CameraPointOfInterest.new()
	extra.position=TownLayout.POOL+Vector3(14,4,0)
	extra.half_extents=Vector3(5,3,4)
	extra.full_radius=30
	extra.release_radius=45
	game.town.add_child(extra)
	await place(TownLayout.POOL+Vector3(0,.85,14))
	settle(4)
	var complete:=true
	var viewport:=Rect2(Vector2.ZERO,game.hud.size).grow(-12)
	for corner in extra.world_bounds(): complete=complete and viewport.has_point(game.camera.unproject_position(corner))
	check(game.camera_framing.points.has(extra) and complete,"An independently added interest registers and frames its bounds without changes to the camera controller")
	game.travel.start(true)
	game.travel.finish()
	check(game.camera_framing.points.all(func(point): return point.weight==0 and point.engagement_left==0),"A map handover clears stale point weights and interaction holds")
	game.travel.race.jobs[0].done=true
	check(not game.travel.race.jobs[0].camera_interest.active_when.call() and game.travel.race.jobs[1].camera_interest.active_when.call(),"Motorway interests follow their own mission state independently")
	game.travel.race.jobs[0].done=false
	await place(ToyRaceTrack.ORIGIN+Vector3(58,.85,0))
	settle(4)
	var race_point: CameraPointOfInterest=game.travel.race.jobs[0].camera_interest
	var race_visible:=true
	for corner in race_point.world_bounds(): race_visible=race_visible and Rect2(Vector2.ZERO,game.hud.size).grow(-12).has_point(game.camera.unproject_position(corner))
	check(race_point.weight>.99 and race_visible and game.camera_framing.active.all(func(point): return game.travel.race.is_ancestor_of(point)),"The same framing system fits Motorway jobs and releases hidden Maple Bay interests")
	var bubble:=SpeechFrame.new()
	bubble.size=Vector2(380,150)
	for tip in [Vector2(190,190),Vector2(-40,75),Vector2(420,75),Vector2(190,-40)]:
		bubble.tail_tip=tip
		var polygon:=bubble.outline()
		check(polygon.size()>70 and not Geometry2D.triangulate_polygon(polygon).is_empty(),"The unified rounded bubble silhouette is valid with a tail on "+str(tip))
	bubble.free()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
