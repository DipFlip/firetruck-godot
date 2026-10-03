extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(game: Node3D, path: String, focus: Vector3, offset: Vector3, size: float) -> void:
	game.camera.position=focus+offset
	game.camera.look_at(focus)
	game.camera.size=size
	game.camera.v_offset=0
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size=Vector2i(1280,800)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.freeze=true
	game.truck.use_automation=true
	for i in 3: await process_frame
	game.set_process(false)
	game.hud.hide()
	game.camera.far=450
	DirAccess.make_dir_recursive_absolute("res://output/playroom")
	await capture(game,"res://output/playroom/overview.png",Vector3(0,1,0),Vector3(100,124,136),150)
	await capture(game,"res://output/playroom/felt.png",TownLayout.MAYA+Vector3(2,0,-1),Vector3(16,23,29),20)
	await capture(game,"res://output/playroom/wood-floor.png",Vector3(76,0,50),Vector3(16,23,29),32)
	await capture(game,"res://output/playroom/railway.png",Vector3(-36,0,-62),Vector3(16,23,29),22)
	await capture(game,"res://output/playroom/blocks.png",Vector3(81,1.5,20),Vector3(-10,9,14),9)
	await capture(game,"res://output/playroom/portal-east.png",Vector3(81,1,-63),Vector3(-18,19,24),23)
	await capture(game,"res://output/playroom/portal.png",Vector3(-81,1,-63),Vector3(-18,19,24),23)
	game.queue_free()
	await process_frame
	await process_frame
	quit()
