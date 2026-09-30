# Scripted in-engine tour: driving is physics-driven; the fire scene is a deliberate cut.
extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func seconds(s: float) -> void: await create_timer(s).timeout
func close_dialogue() -> void:
	if game.dialogue_active:
		game.interact()
		if game.dialogue_active: game.interact()
func navigate(target: Vector3) -> void:
	var ticks:=0
	while ticks<240:
		var delta: Vector3=target-game.truck.global_position
		delta.y=0
		if delta.length()<2.2: break
		var f: Vector3=-game.camera.global_basis.z
		f.y=0
		f=f.normalized()
		var dir:=delta.normalized()
		game.truck.automated_drive=Vector2(dir.dot(game.camera.global_basis.x),-dir.dot(f))
		if delta.length()<5: Input.action_press("brake")
		else: Input.action_release("brake")
		ticks+=1
		await process_frame
	game.truck.automated_drive=Vector2.ZERO
	Input.action_press("brake")
	await seconds(.4)
	Input.action_release("brake")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.truck.use_automation=true
	game.talk("DISPATCH  /  A NEW DAY","Morning, rookie! Maya's cat thinks he's a bird. Shall we go lend a hand?",1)
	await seconds(4.7)
	close_dialogue()
	await navigate(Vector3(0,0,0))
	await navigate(Vector3(10,0,-4))
	game.talk("MAYA  /  MAPLE GREEN","Oh, thank goodness! Pippin climbed up there and forgot how to be a cat. Can you help?",1)
	await seconds(5.0)
	close_dialogue()
	game.truck.extend_ladder()
	await navigate(Vector3(17,0,-3))
	await seconds(3.4)
	close_dialogue()
	# Cut to the second job to keep the art/feel review compact.
	game.truck.global_position=TownLayout.FIRE+Vector3(1,1,8)
	game.truck.linear_velocity=Vector3.ZERO
	game.camera_focus=game.truck.position
	game.stage=3
	game._update_mission()
	game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.7
	game.truck.automated_spray=true
	Input.action_press("brake")
	await seconds(6.2)
	game.truck.automated_spray=false
	await seconds(2.4)
	Input.action_release("brake")
	print("Rendered tour complete. Frames: ",Engine.get_frames_drawn())
	if game.audio: game.audio.stop()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
