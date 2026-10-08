# Actual post-pan PCM, using the native mixer rather than trusting node settings.
extends SceneTree
var game: Node3D
var capture: AudioEffectCapture
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func seconds(duration: float) -> void:
	var until:=Time.get_ticks_msec()+roundi(duration*1000)
	while Time.get_ticks_msec()<until: await process_frame
func energy(at: Vector3) -> Vector2:
	for p in game.sounds.players: p.stop()
	await seconds(.08)
	capture.clear_buffer()
	game.sounds.play("block_land",at,1,0)
	await seconds(.36)
	var frames:=capture.get_buffer(capture.get_frames_available())
	var sum:=Vector2.ZERO
	for frame in frames: sum+=Vector2(frame.x*frame.x,frame.y*frame.y)
	return sum/maxi(1,frames.size())
func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("SKIP: Spatial PCM checks require the native audio mixer")
		quit(0)
		return
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.sounds.set_process(false)
	game.life.set_physics_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	game.call_timer=0
	AudioServer.set_bus_volume_db(0,-80)
	var bus:=AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus,"SpatialProbe")
	capture=AudioEffectCapture.new()
	capture.buffer_length=.6
	AudioServer.add_bus_effect(bus,capture)
	for player in game.sounds.players: player.bus="SpatialProbe"
	game.sounds._update_listener()
	var centre: Vector3=game.sounds.listener.global_position
	var right: Vector3=game.camera.global_basis.x
	var left_pcm:=await energy(centre-right*12)
	var right_pcm:=await energy(centre+right*12)
	var far_pcm:=await energy(centre+right*60)
	print("SPATIAL PCM: left=",left_pcm," right=",right_pcm," distant=",far_pcm)
	check(left_pcm.length()>1e-9 and right_pcm.length()>1e-9,"Positioned wooden cues produce actual stereo PCM")
	check(left_pcm.x>left_pcm.y*2 and right_pcm.y>right_pcm.x*2,"Left and right toys pan to their corresponding speakers")
	check(far_pcm.x+far_pcm.y<(right_pcm.x+right_pcm.y)*.15,"A distant toy is substantially quieter in the real mix")
	game.queue_free()
	await process_frame
	await process_frame
	AudioServer.remove_bus(bus)
	print("SPATIAL AUDIO: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
