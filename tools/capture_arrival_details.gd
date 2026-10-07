extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func shot(title: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/"+title+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.start()
	game.intro.update(3.7)
	await shot("arrival-station-rising-print")

	game.travel.grow_assembly(1)
	game.travel.mat.hide()
	await shot("arrival-palette-shader")
	game.travel.finish_assembly()
	await shot("arrival-palette-standard")
	game.intro.finish()
	game.camera.position=Vector3(49,0,-25)+Vector3(19,15,22)
	game.camera.look_at(Vector3(49,1,-25))
	game.camera.size=29
	await shot("barbecue-cottage-clearance")
	game.truck.global_position=Vector3(0,.82,0)
	game.truck.heading=0
	game.truck.rotation.y=0
	for i in 3:
		game.camera.position=game.truck.position+[Vector3(7,5,9),Vector3(-7,4,8),Vector3(0,3,10)][i]
		game.camera.look_at(game.truck.position+Vector3.UP*.8)
		game.camera.size=7
		await shot("truck-restored-walls-%d" % i)
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
