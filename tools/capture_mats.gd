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
	game.intro.update(1.2)
	await shot("mat-intro-unroll")
	game.intro.update(3.0)
	await shot("mat-intro-grow")
	game.intro.update(2.2)
	await shot("mat-intro-east-buildings")
	game.intro.update(4.0)
	await shot("mat-intro-border-drop")
	game.intro.finish()
	game.travel.start(true)
	game.travel._update_transition(1.2)
	await shot("mat-town-roll")
	game.travel._update_transition(2.3)
	await shot("mat-race-unroll")
	game.travel._update_transition(2.5)
	await shot("mat-race-assemble")
	game.travel._update_transition(2.1)
	await shot("mat-race-camp-assemble")
	game.travel._update_transition(2.2)
	await shot("mat-race-bridge-assemble")
	game.travel._update_transition(2.2)
	await shot("mat-race-border-drop")
	game.travel.finish()
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
