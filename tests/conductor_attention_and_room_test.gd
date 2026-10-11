extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/firedriver-"+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.truck.set_physics_process(false)
	game.railway.set_physics_process(false)
	game.call_timer=0
	game.stage=4
	var room: Node3D=game.playroom.room_props
	check(room.get_node("WoodenPullTrain1").position.x< -100 and room.get_node("WoodenPullTrain3").position.z< -20,"The pull train sits along the old basket area on the west side")
	check(room.get_node("OpenWastepaperBasket").position.x< -100 and room.get_node("OpenWastepaperBasket").position.z>30,"The basket moves to the former sneakers' position")
	check(room.get_node("Sneaker1").position.z>100 and room.get_node("Sneaker2").position.x>30,"The sneakers move into the old southern train area")
	check(game.camera.near<=.02 and game.gameplay_camera_offset().length()>=96,"The driving lens stays beyond foreground toys with a short near distance")
	var driver: Node3D=game.railway.driver
	var sizes: Array[float]=[]
	for distance in [29.0,20.0,12.0,6.0]:
		game.truck.global_position=driver.global_position+Vector3(0,.855,distance)
		game.truck.reset_physics_interpolation()
		await physics_frame
		for i in 180: game._process(1.0/60)
		sizes.append(game.camera.size)
	game._proximity_talk()
	game.dialogue_control.attention._process(.1)
	check(not game.dialogue_active and not game.dialogue_control.interrupting and not game.truck.freeze and not game.railway.briefed,"Approaching the conductor keeps driving available and waits for interaction")
	check(game.dialogue_control.attention.visible and game.dialogue_control.attention.actor==driver and game.dialogue_control.attention.message=="Help me, please!","The conductor uses the shared help bubble and animated Space/controller button")
	check(sizes[1]<sizes[0] and sizes[2]<sizes[1] and sizes[3]<=sizes[2]+.01 and game.conversation_blend>.9,"The conductor gets the same gradual approach zoom as the other mission NPCs")
	await capture("conductor-help")
	var event:=InputEventAction.new()
	event.action="jump"
	event.pressed=true
	game._unhandled_input(event)
	check(game.dialogue_active and game.dialogue_actor==driver and game.dialogue_control.interrupting and game.truck.freeze,"Space explicitly starts the conductor's first blocking mission briefing")
	check(game.npc_attention_text(4).is_empty(),"Talking to the conductor retires his automatic help announcement")
	await capture("conductor-briefing")
	game.end_dialogue()
	check(game._talk_to_npc(4,true) and not game.dialogue_control.interrupting,"The conductor remains available for a non-blocking repeat conversation")
	game.end_dialogue()
	game.truck.global_position=Vector3(34,.855,76)
	game.truck.reset_physics_interpolation()
	await physics_frame
	await process_frame
	game.camera_focus=game.truck.global_position
	for i in 180: game._process(1.0/60)
	await capture("southern-room")
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
