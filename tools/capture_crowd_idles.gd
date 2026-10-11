extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func capture(label: String, focus: Vector3, offset: Vector3, size: float) -> void:
	game.camera.position=focus+offset
	game.camera.look_at(focus)
	game.camera.size=size
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/idle-"+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.finish()
	game.hud.hide()
	game.camera.far=900
	await capture("shoes",Vector3(-125,5,40),Vector3(30,40,45),60)
	game.travel.start(true)
	game.travel.finish()
	var race: ToyRaceTrack=game.travel.race
	race.set_process(false)
	race.running=false
	for time in [1.5,8.8,14.0]:
		race.animation_clock=time
		for i in 60: race._update_audience(.016667)
		await capture("crowd-"+str(time).replace(".","-"),ToyRaceTrack.ORIGIN+ToyRaceTrack.WEST_STAND+Vector3(0,2,-1),Vector3(7,7,18),18)
	game.queue_free()
	await process_frame
	await process_frame
	quit()
