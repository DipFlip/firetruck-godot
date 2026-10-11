extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func shot(label: String, focus: Vector3, lens: float=18) -> void:
	game.camera.global_position=focus+Vector3(16,18,23).normalized()*160
	game.camera.look_at(focus)
	game.camera.size=lens
	await frames(8)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/shared-fire-"+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.set_process(false)
	game.travel.set_process(false)
	game.truck.freeze=true
	game.hud.hide()
	game.miniature.hide()
	game.travel.start(true)
	game.travel.finish()
	game.travel.race.set_process(false)
	game.travel.race.set_physics_process(false)
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(60,.85,7)
	await shot("motorway-grill",ToyRaceTrack.ORIGIN+Vector3(62,2,16),14)
	game.travel.race.grill_fire.apply_water(.5)
	await frames(18)
	await shot("motorway-steam",ToyRaceTrack.ORIGIN+Vector3(62,2,16),14)
	await shot("food-court-flags",ToyRaceTrack.ORIGIN+Vector3(65,6.6,33),12)
	await shot("cones",ToyRaceTrack.ORIGIN+Vector3(65,1,11),5)
	await shot("turn-cones",ToyRaceTrack.ORIGIN+Vector3(-43,0,21),31)
	game.queue_free()
	await frames(2)
	quit()
