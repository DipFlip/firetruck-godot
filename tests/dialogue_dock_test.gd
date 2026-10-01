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
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.truck.freeze=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	var actor: Node3D=game.town.people[0]
	game.truck.position=actor.position+Vector3(0,1,4)
	game.truck.reset_physics_interpolation()
	await frames(20)
	game.talk("MAYA","Oh, thank goodness you're here! Pippin has decided he's a bird. Could you help him down from that tree?",1)
	await frames(120)
	var hud: FireHUD=game.hud
	var panel: SpeechFrame=hud.dialogue_panel
	var dock:=hud.dialogue_dock_position()
	check(panel.position.distance_to(dock)<.1 and panel.position.y>hud.size.y*.6,"A nearby conversation docks at the bottom of the screen")
	var tail:=panel.position+panel.tail_tip
	var stable:=true
	for side in [-1,1,-1,1]:
		game.truck.position=actor.position+Vector3(side*3,1,4)
		game.truck.reset_physics_interpolation()
		await frames(40)
		stable=stable and panel.position.distance_to(dock)<.1 and not Rect2(panel.position,panel.size).intersects(hud.truck_screen_rect())
	check(stable and (panel.position+panel.tail_tip).distance_to(tail)>15,"Camera and nearby vehicle movement update the notch without moving the docked card")
	game.truck.position=actor.position+Vector3(-12,1,-14)
	game.truck.reset_physics_interpolation()
	await frames(1)
	check(panel.position.distance_to(dock)<5,"Driving away begins a gradual transition instead of a teleport")
	var previous:=panel.position
	var max_step:=0.0
	for i in 100:
		await frames(1)
		max_step=maxf(max_step,panel.position.distance_to(previous))
		previous=panel.position
	check(game.dialogue_active and hud.bubble_detach_blend>.75 and panel.position.distance_to(dock)>20 and max_step<15,"Driving farther away smoothly brings the bubble toward the NPC")
	check(not Rect2(panel.position,panel.size).intersects(hud.truck_screen_rect()),"The detached bubble stays clear of the truck")
	var head: Vector2=game.camera.unproject_position(actor.global_position+Vector3.UP*2.85)
	check((panel.position+panel.tail_tip).distance_to(head)<1 and not Rect2(panel.position,panel.size).has_point(head),"The notch remains aimed at the on-screen speaker throughout detachment")
	game.paused=true
	var paused_position:=panel.position
	var paused_blend:=hud.bubble_detach_blend
	await frames(20)
	check(panel.position==paused_position and hud.bubble_detach_blend==paused_blend,"Pause freezes the bubble transition")
	game.paused=false
	game.truck.position=actor.position+Vector3(0,1,4)
	game.truck.reset_physics_interpolation()
	await frames(150)
	check(game.dialogue_active and panel.position.distance_to(hud.dialogue_dock_position())<1,"Returning to the NPC gently restores the fixed dock")
	game.end_dialogue()
	game.talk("DISPATCH","There's a barbecue fire near Leo's cottage.",1)
	await frames(30)
	check(panel.phone_mode and (panel.position+panel.tail_tip).distance_to(hud._phone_center()-Vector2(0,27))<1,"Dispatch keeps its fixed phone anchor and operator avatar")
	game.queue_free()
	await process_frame
	await process_frame
	print("DIALOGUE DOCK CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
