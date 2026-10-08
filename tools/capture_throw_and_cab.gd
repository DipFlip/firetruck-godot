extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func shot(label: String) -> void:
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/throw-"+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.start()
	for time in [.1,.4,.9,1.5,2.1,3.6]:
		game.intro.update(time-game.intro.clock)
		await shot("opening-"+str(time).replace(".","-"))
	game.intro.finish()
	game.call_timer=10
	for time in [.15,.24]:
		game.hud.time=time
		game.hud.queue_redraw()
		await shot("phone-"+str(time).replace(".","-"))
	game.travel.start(true)
	for time in [.8,1.5,1.85,1.99,2.01,2.3,3.4,4.5,21.5,22.5,23.5,24.5,25.9]:
		game.travel._update_transition(time-game.travel.clock)
		await shot("exchange-"+str(time).replace(".","-"))
	game.travel.finish()
	await shot("handover-game")
	game.travel.start(false)
	for time in [.6,1.1,1.19,1.21,1.6,2.1,2.4,2.79]:
		game.travel._update_transition(time-game.travel.clock)
		await shot("return-"+str(time).replace(".","-"))
	game.travel.finish()
	game.hud.hide()
	game.railway.set_physics_process(false)
	game.railway._start_engine()
	for time in [.6,1.1,2.4]:
		game.railway._physics_process(time-game.railway.boarding_time)
		var focus: Vector3=game.railway.engine.global_position+Vector3(-2.5,2.1,0)
		game.camera.position=focus+Vector3(3,3,8)
		game.camera.look_at(focus)
		game.camera.size=6.5
		await shot("cab-"+str(time).replace(".","-"))
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
