extends SceneTree
# Dense visual sweep: render intermediate frames, not just the shot endpoints.
var game: Node3D
var folder:="res://output/playwright/carpet-tour/"
func _initialize() -> void: call_deferred("run")
func capture(world: String, time: float) -> void:
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_jpg(folder+"%s-%05.2f.jpg" % [world,time],.88)
func run() -> void:
	root.size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(folder)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.start()
	for i in 96:
		var time:=i*.25
		game.intro.update(time-game.intro.clock)
		await capture("maple",time)
	game.intro.finish()
	game.travel.start(true)
	for i in 104:
		var time:=i*.25
		game.travel._update_transition(time-game.travel.clock)
		await capture("race",time)
	game.travel.finish()
	game.travel.start(false)
	for i in 28:
		var time:=i*.1
		game.travel._update_transition(time-game.travel.clock)
		await capture("return",time)
	game.travel.finish()
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
