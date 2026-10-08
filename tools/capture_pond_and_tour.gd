extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func shot(label: String) -> void:
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/pond-tour-"+label+".png")
func focus(at: Vector3, lens: float, offset:=Vector3(16,14,20)) -> void:
	game.camera.position=at+offset
	game.camera.look_at(at)
	game.camera.size=lens
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.call_timer=0
	game.intro.start()
	for time in [1.0,2.2,4.2,5.6,7.0,9.0]:
		game.intro.update(time-game.intro.clock)
		await shot("maple-"+str(time))
	game.intro.finish()
	game.travel.start(true)
	for time in [.25,.6,1.3,5.2,6.1,7.0,13.5,19.5]:
		game.travel._update_transition(time-game.travel.clock)
		await shot("race-"+str(time))
	game.travel.finish()
	game.hud.hide()
	game.camera.far=900
	var centre:=ToyRaceTrack.ORIGIN+Vector3(-29,-.1,40)
	focus(centre,37,Vector3(20,17,27))
	await shot("pond")
	game.truck.global_position=centre+Vector3(0,-1.47,0)
	await shot("pond-truck")
	focus(ToyRaceTrack.ORIGIN+Vector3(-63,0,-12),32)
	await shot("campsite")
	focus(ToyRaceTrack.ORIGIN+Vector3(0,3,4),37,Vector3(20,15,23))
	await shot("bridge")
	game.hud.show()
	game.travel.start(false)
	for time in [.7,1.65,2.4,3.2,3.6,4.1]:
		game.travel._update_transition(time-game.travel.clock)
		await shot("return-"+str(time))
	game.travel.finish()
	game.railway.set_physics_process(false)
	game.railway._start_engine()
	for time in [.75,1.05,1.45,2.4]:
		game.railway._physics_process(time-game.railway.boarding_time)
		focus(game.railway.engine.global_position+Vector3(-2.5,3,0),11,Vector3(3,3,8))
		await shot("cab-"+str(time))
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
