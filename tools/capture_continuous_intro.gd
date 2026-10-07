extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute("res://output/playwright")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.intro.start()
	game.set_process(false)
	game.travel.set_process(false)
	for time in [0.1,2.6,4.8,7.6,9.6,12.4,17.0,20.5,22.5]:
		game.intro.update(time-game.intro.clock)
		await shot("paced-town-"+str(time).replace(".","-"))
	game.intro.finish()
	game.travel.assembly_camera(7.8,false)
	await shot("continuous-town-built")
	game.travel.start(true)
	for time in [1.2,2.2,6.8,9.6,14.4,19.0,22.5]:
		game.travel._update_transition(time-game.travel.clock)
		await shot("paced-race-"+str(time).replace(".","-"))
	game.travel.finish()
	game.camera.far=900
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(100,124,136)
	game.camera.look_at(ToyRaceTrack.ORIGIN)
	game.camera.size=165
	await shot("race-overview")
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(10,23,-36)
	game.camera.look_at(ToyRaceTrack.ORIGIN+Vector3(10,0,-65))
	game.camera.size=32
	await shot("race-arrival")
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(26,23,30)
	game.camera.look_at(ToyRaceTrack.ORIGIN+Vector3(0,3,4))
	game.camera.size=47
	await shot("race-bridge-close")
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(68,18,63)
	game.camera.look_at(ToyRaceTrack.ORIGIN+Vector3(51,1,40))
	game.camera.size=32
	await shot("race-camp-close")
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
