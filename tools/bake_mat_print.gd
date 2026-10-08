extends SceneTree
# Bake the town's actual flattened toys into the carpet print, once offline.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1024,1024)
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.intro.start()
	game.set_process(false)
	game.travel.set_process(false)
	game.travel.set_world_visible(true)
	game.travel.flatten_for_print()
	game.travel.mat.hide()
	game.playroom.hide()
	game.truck.hide()
	game.hud.hide()
	game.miniature.hide()
	game.marker.hide()
	game.job_label.hide()
	for node in game.get_children():
		if node is RoomDust: node.hide()
	game.camera.position=Vector3(0,200,0)
	game.camera.look_at(Vector3.ZERO,Vector3(0,0,-1))
	game.camera.size=160
	game.camera.far=450
	for i in 4: await process_frame
	RenderingServer.force_draw()
	var error:=root.get_texture().get_image().save_png("res://assets/scenery/maple_mat.png")
	print("MAT PRINT: ",error)
	game.intro.finish()
	game.travel.set_world_visible(false)
	game.travel.in_race=true
	game.travel.race.show()
	game.travel.race.mat.position.y=-.01
	game.travel.begin_assembly(true)
	game.travel.flatten_for_print()
	game.travel.race.get_node("RacePlayroomFloor").hide()
	game.camera.size=160
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(0,200,0)
	game.camera.look_at(ToyRaceTrack.ORIGIN,Vector3(0,0,-1))
	for i in 4: await process_frame
	RenderingServer.force_draw()
	error=root.get_texture().get_image().save_png("res://assets/scenery/race_mat.png")
	print("RACE MAT PRINT: ",error)
	game.travel.finish_assembly()
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit(error)
