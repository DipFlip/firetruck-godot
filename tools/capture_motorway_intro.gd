extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/motorway-"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.start()
	for time in [.4,1.4,2.6,3.8,4.8]:
		game.intro.update(time-game.intro.clock)
		await shot("held-mat-"+str(time).replace(".","-"))
	game.intro.finish()
	game.travel.start(true)
	for time in [.7,1.4,6.8,9.2,9.8,10.3,10.8,11.3,12.6,13.0,13.4,13.7,14.2,14.3,15.8,17.0,18.0,19.5,20.4,21.0,22.3,23.5,24.4,25.7]:
		game.travel._update_transition(time-game.travel.clock)
		await shot("race-"+str(time).replace(".","-"))
	game.travel.finish()
	game.travel.start(false)
	game.travel._update_transition(.55)
	await shot("flat-rollup")
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
