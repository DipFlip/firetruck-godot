extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/view-assembly-"+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.start()
	for time in [4.8,5.4,6.1,10.6,11.2,12.0]:
		game.intro.update(time-game.intro.clock)
		await capture("maple-"+str(time).replace(".","-"))
	game.intro.finish()
	game.travel.start(true)
	for elapsed in [4.0,4.7,8.8,10.5,11.3,12.0,17.4,18.1]:
		game.travel._update_transition(elapsed+2-game.travel.clock)
		await capture("motorway-"+str(elapsed).replace(".","-"))
	game.travel.finish()
	game.travel.race.set_process(false)
	game.travel.race.running=true
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(-40,.85,26)
	for i in 20: game.travel.race._update_broadcast_camera(.05)
	game.travel.assembly_camera(18.1,true)
	await capture("broadcast-camera")
	game.queue_free()
	await process_frame
	await process_frame
	quit()
