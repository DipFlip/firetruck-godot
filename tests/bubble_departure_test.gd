extends SceneTree

var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func actor_at_screen(actor: Node3D, point: Vector2) -> void:
	var camera: Camera3D=game.camera
	var origin:=camera.project_ray_origin(point)
	var ray:=camera.project_ray_normal(point)
	actor.global_position=origin+ray*((2.85-origin.y)/ray.y)-Vector3.UP*2.85
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/firedriver-bubble-"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.stage=4
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.truck.freeze=true
	game.truck.use_automation=true
	game.town.set_process(false)
	var hud: FireHUD=game.hud
	hud.set_process(false)
	hud.prompt_panel.hide()
	hud.toast_panel.hide()
	hud.footer.hide()
	var panel: SpeechFrame=hud.dialogue_panel
	var actor: Node3D=game.town.people[0]
	var home: Vector3=actor.global_position
	game.camera.position=Vector3(-12,0,-52)+game.gameplay_camera_offset()
	game.camera.look_at(Vector3(-12,1,-52))
	game.camera.size=25.8
	await frames(3)
	for screen in [Vector2i(1280,800),Vector2i(390,564)]:
		root.size=screen
		hud._layout_viewport()
		await frames(3)
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			var center:=hud.get_viewport_rect().size*.5
			actor_at_screen(actor,center)
			game.truck.position=actor.position+Vector3(0,.85,6)
			game.end_dialogue()
			game.talk("MAYA","Thanks again! Come back and visit us anytime.",4,false)
			hud.advance_text()
			if hud.talk_tween: hud.talk_tween.kill()
			panel.modulate.a=1
			for i in 60: hud._position_dialogue(1.0/60)
			var previous:=panel.get_global_rect().get_center()
			var previous_scale:=panel.scale.x
			var max_step:=0.0
			var max_scale_step:=0.0
			var saw_half:=false
			var saw_small:=false
			var captured:=false
			var valid_outlines:=true
			for i in 200:
				actor_at_screen(actor,center+direction*i*8)
				hud._position_dialogue(1.0/60)
				valid_outlines=valid_outlines and not Geometry2D.triangulate_polygon(panel.outline()).is_empty()
				var rect:=panel.get_global_rect()
				max_step=maxf(max_step,previous.distance_to(rect.get_center()))
				max_scale_step=maxf(max_scale_step,absf(panel.scale.x-previous_scale))
				previous=rect.get_center()
				previous_scale=panel.scale.x
				var fraction:=rect.intersection(hud.get_viewport_rect()).get_area()/rect.get_area()
				if fraction>.3 and fraction<.7:
					saw_half=true
					if screen.x==1280 and direction==Vector2.RIGHT and panel.scale.x<.7 and not captured:
						await capture("half-out")
						captured=true
				if panel.scale.x<.7: saw_small=true
				var projected: Vector2=game.camera.unproject_position(actor.global_position+Vector3.UP*2.85)
				check_tail(panel,projected)
				if hud.dialogue_has_left_view(): break
			check(saw_half and saw_small,"The bubble shrinks and passes through a half-visible frame at "+str(direction)+" on "+str(screen))
			check(max_step<24 and max_scale_step<.06,"Position and scale stay continuous through the edge ("+str(snappedf(max_step,.1))+" px)")
			check(valid_outlines,"The rounded balloon and its tail remain drawable throughout departure")
			check(hud.dialogue_has_left_view(),"Cleanup waits for the complete rendered bubble and its tail to leave the view")
	# Help announcements ease out when the truck leaves their interaction range.
	game.end_dialogue()
	game.stage=1
	game.cat_rescued=false
	game.dialogue_control.spoken_actors.erase(actor)
	actor_at_screen(actor,hud.get_viewport_rect().size*.5)
	game.truck.position=actor.global_position+Vector3(0,.855,6)
	var attention: NPCAttention=game.dialogue_control.attention
	attention.set_process(false)
	attention._process(.1)
	check(attention.visible,"A nearby unspoken quest giver has a help announcement")
	game.truck.position=actor.global_position+Vector3(0,.855,13)
	attention._process(.016)
	check(attention.visible and attention.modulate.a>.9 and attention.scale.x<1,"Leaving help range starts a smooth scale-down instead of hiding immediately")
	for i in 35: attention._process(1.0/60)
	check(not attention.visible,"The help announcement finishes its eased departure")
	# Blocking dialogue and phone calls stay readable in their established layout.
	actor_at_screen(actor,Vector2(-30,200))
	game.end_dialogue()
	game.talk("MAYA","Please help Pippin down from the tree.",1,true)
	for i in 60: hud._position_dialogue(1.0/60)
	check(panel.scale.is_equal_approx(Vector2.ONE),"Interrupting mission conversations keep full-size text")
	game.end_dialogue()
	hud.touch_mode=true
	hud.touch_portrait=true
	game.talk("DISPATCH","A quiet call from Captain Robin.",1,false)
	hud._position_dialogue(1.0/60)
	check(panel.scale==Vector2.ONE and hud.get_viewport_rect().encloses(panel.get_global_rect()),"Phone conversations retain their screen anchor and full size")
	game.end_dialogue()
	# Drive away through the real camera update and automatic dismissal path.
	root.size=Vector2i(1280,800)
	hud._layout_viewport()
	await frames(3)
	actor.global_position=home
	game.truck.position=home+Vector3(0,.855,6)
	game.truck.reset_physics_interpolation()
	game.camera_focus=game.truck.position
	game.set_process(true)
	hud.set_process(true)
	game.stage=4
	game.cat_rescued=true
	game.truck.freeze=true
	game.truck.automated_drive=Vector2.ZERO
	game.proximity_latches[0]=true
	game.talk("MAYA","Thanks again! Have a lovely drive around town.",4,false)
	await frames(90)
	hud.touch_mode=false
	hud.touch_portrait=false
	var drive_direction: Vector3=-game.camera.global_basis.x
	drive_direction.y=0
	drive_direction=drive_direction.normalized()
	var partial_seen:=false
	var snapped_away:=false
	var old_rect:=panel.get_global_rect()
	for i in 420:
		# Advance the truck through scenery to isolate the camera/dismissal path.
		game.truck.global_position+=drive_direction*.2
		game.truck.linear_velocity=drive_direction*12
		game.truck.reset_physics_interpolation()
		await frames(1)
		var rect:=panel.get_global_rect()
		var fraction:=rect.intersection(hud.get_viewport_rect()).get_area()/rect.get_area()
		if fraction>.2 and fraction<.8 and game.dialogue_active: partial_seen=true
		if not game.dialogue_active:
			snapped_away=hud.get_viewport_rect().intersects(old_rect)
			break
		old_rect=rect
	print("Drive departure: partial=",partial_seen," snapped=",snapped_away," active=",game.dialogue_active," position=",game.truck.position," actor=",actor.global_position," rect=",panel.get_global_rect())
	check(partial_seen and not snapped_away and not game.dialogue_active,"The gameplay camera keeps a partially clipped bubble visible and dismisses it only after it moves fully off-screen")
	game.queue_free()
	await process_frame
	await process_frame
	print("BUBBLE DEPARTURE CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
func check_tail(panel: SpeechFrame, projected: Vector2) -> void:
	if (panel.get_global_transform()*panel.tail_tip).distance_to(projected)>1:
		check(false,"The scaled tail remains attached to the world-space speaker")
