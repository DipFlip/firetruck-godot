extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func shot(filename: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/"+filename+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.start()
	game.intro.update(.1)
	await shot("room-roll-closed")
	game.intro.update(2.4)
	await shot("room-roll-unfolding")
	game.intro.finish()
	game.railway.set_physics_process(false)
	game.truck.hide()
	game.hud.hide()
	var rail: NorthlineRailway=game.railway
	game.camera.position=rail.engine.position+Vector3(9,8,13)
	game.camera.look_at(rail.engine.position+Vector3(-2,2,1))
	game.camera.size=16
	rail._start_engine()
	rail._physics_process(.5)
	await shot("conductor-roof-open")
	rail._physics_process(.6)
	await shot("conductor-jumping")
	rail._physics_process(1.3)
	await shot("conductor-riding")
	game.travel.start(true)
	game.travel.finish()
	game.hud.hide()
	game.truck.hide()
	game.camera.far=900
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(100,124,136)
	game.camera.look_at(ToyRaceTrack.ORIGIN)
	game.camera.size=185
	await shot("updated-race-overview")
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(-12,16,57)
	game.camera.look_at(ToyRaceTrack.ORIGIN+Vector3(-31,0,36))
	game.camera.size=23
	await shot("race-swimming-ducks")
	game.travel.start(false)
	game.travel._update_transition(1.2)
	await shot("return-mat-put-aside")
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
