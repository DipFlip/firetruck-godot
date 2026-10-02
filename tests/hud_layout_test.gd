extends SceneTree
var failures:=0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, description: String) -> void:
	if not ok:
		failures+=1
		print("FAIL: ",description)
func check_motion(hud: FireHUD) -> void:
	for fps in [30,60,120]:
		var dt: float=1.0/float(fps)
		hud.bubble_position_ready=false
		hud._move_dialogue(Vector2(40,80),0,0)
		var start:=hud.dialogue_panel.position
		var target:=Vector2(440,80)
		hud._move_dialogue(target,1,dt)
		check(hud.dialogue_panel.position.distance_to(start)<5,"Relocation begins without a snap at %d Hz" % fps)
		for i in int(.7*fps)-1:
			hud._move_dialogue(target,1,dt)
			if i==int(.35*fps)-2:
				var distance:=hud.dialogue_panel.position.distance_to(start)
				check(distance>160 and distance<220,"Relocation is about halfway after .35 seconds")
		check(hud.dialogue_panel.position.distance_to(target)<.1,"Relocation finishes in .7 seconds at %d Hz" % fps)
		var follow:=target+Vector2(30,20)
		hud._move_dialogue(follow,1,dt)
		check(hud.dialogue_panel.position.distance_to(target)<3,"Ordinary tracking also eases instead of jumping")
		for i in int(1.5*fps): hud._move_dialogue(follow,1,dt)
		check(hud.dialogue_panel.position.distance_to(follow)<.1,"Tracking catches up without a permanent offset")
		var before:=hud.dialogue_panel.position
		hud._move_dialogue(Vector2(100,200),2,dt)
		hud._move_dialogue(Vector2(300,300),3,dt)
		check(hud.dialogue_panel.position.distance_to(before)<10,"Retargeting an active move preserves position continuity")
	hud.bubble_position_ready=false

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	check_motion(game.hud)
	game.call_timer=0
	game.set_process(false)
	game.set_physics_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	var screens: Array[Vector2i]=[Vector2i(390,542),Vector2i(320,390),Vector2i(844,390),Vector2i(1024,768),Vector2i(1440,900),Vector2i(900,1400),Vector2i(2560,1080)]
	for screen in screens:
		root.size=screen
		game.hud.touch_mode=screen.x<1100
		game.hud.touch_portrait=screen.x<screen.y
		await frames(3)
		game.talk("MAYA  /  MAPLE GREEN","Oh, thank goodness! Pippin climbed up there and forgot how to be a cat. Extend your ladder with E and drive its tip close to Pippin. He'll hop on and climb down. Gently, please!",1)
		var hud: FireHUD=game.hud
		check(" ".join(hud.dialogue_pages)==hud.dialogue_text,"Complete message preserves every word: "+str(screen))
		check(hud.font.get_multiline_string_size(hud.full_text,HORIZONTAL_ALIGNMENT_LEFT,hud.dialogue_label.size.x,hud.dialogue_font_size).y>=hud.font.get_height(hud.dialogue_font_size)*2.9,"Dialogue uses at least three available text rows")
		for page in hud.dialogue_pages.size():
			hud.dialogue_label.visible_characters=hud.full_text.length()
			var finished:=hud.advance_text()
			check(finished==(page==hud.dialogue_pages.size()-1),"Only final page finishes conversation")
		game.talk("MAYA  /  MAPLE GREEN",hud.dialogue_text,1)
		game.camera.size=18.8
		game.conversation_blend=1
		for step in 12:
			var angle:=step*TAU/12
			game.truck.position=TownLayout.MAYA+Vector3(cos(angle)*6,1,sin(angle)*6)
			game.truck.reset_physics_interpolation()
			var focus: Vector3=game.truck.position.lerp(TownLayout.MAYA,.3)
			game.camera.position=focus+game.TALK_CAMERA_OFFSET
			game.camera.look_at(focus)
			await frames(3)
			game.camera.size=game._talk_camera_size()
			game.camera.v_offset=game._conversation_pan_target()
			await frames(100)
			game.hud._position_dialogue()
			var panel: SpeechFrame=game.hud.dialogue_panel
			var rect:=Rect2(panel.position,panel.size)
			var truck: Rect2=game.hud.truck_screen_rect()
			var context:="%s / approach %d" % [screen,step]
			check(not rect.intersects(hud.conversation_subject_rect()),"The speech balloon leaves the NPC and tree pet visible: "+context)
			check(not rect.intersects(truck),"Truck clear: "+context+" overlap "+str(rect.intersection(truck)))
			if game.hud.size.y<650:
				var gauge_scale:=minf(1,(game.hud.size.x-148)/344) if game.hud.touch_mode else 1.0
				check(truck.position.y>=45+25*gauge_scale+8,"Truck below top gauge: "+context)
			check(game.hud.get_viewport_rect().encloses(rect),"Card within screen: "+context)
			var head: Vector2=game.camera.unproject_position(game.dialogue_actor.position+Vector3.UP*2.85)
			check((panel.position+panel.tail_tip).distance_to(head)<1,"Tail follows speaker: "+context)
			check(game.hud.dialogue_label.size.x>180,"Readable text column: "+context)
		print("Checked HUD ",screen," logical ",game.hud.size," card ",game.hud.dialogue_panel.size)
	game.queue_free()
	await process_frame
	await process_frame
	print("HUD LAYOUT CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
