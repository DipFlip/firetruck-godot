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
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
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
		game.talk("MAYA  /  MAPLE GREEN","Oh, thank goodness you're here! Pippin has decided he's a bird. Could you help him down from that tree?",1)
		var hud: FireHUD=game.hud
		check(" ".join(hud.dialogue_pages)==hud.dialogue_text,"Pagination preserves every word: "+str(screen))
		if screen.x<=390: check(hud.dialogue_pages.size()>1,"Small screens paginate instead of shrinking type")
		for page in hud.dialogue_pages.size():
			hud.dialogue_label.visible_characters=hud.full_text.length()
			var finished:=hud.advance_text()
			check(finished==(page==hud.dialogue_pages.size()-1),"Only final page finishes conversation")
		game.talk("MAYA  /  MAPLE GREEN",hud.dialogue_text,1)
		game.camera.size=18.8
		for step in 12:
			var angle:=step*TAU/12
			game.truck.position=TownLayout.MAYA+Vector3(cos(angle)*6,1,sin(angle)*6)
			game.truck.reset_physics_interpolation()
			var focus: Vector3=game.truck.position.lerp(TownLayout.MAYA,.3)
			game.camera.position=focus+game.TALK_CAMERA_OFFSET
			game.camera.look_at(focus)
			await frames(3)
			game.hud._position_dialogue()
			var panel: SpeechFrame=game.hud.dialogue_panel
			var rect:=Rect2(panel.position,panel.size)
			var truck: Rect2=game.hud.truck_screen_rect()
			var context:="%s / approach %d" % [screen,step]
			check(not rect.intersects(truck),"Truck clear: "+context+" overlap "+str(rect.intersection(truck)))
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
