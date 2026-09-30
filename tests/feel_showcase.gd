# Actual engine recording. The final fire scene is an intentional location cut.
extends SceneTree
func _initialize() -> void: call_deferred("run")
func seconds(n: float) -> void: await create_timer(n).timeout
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game._update_mission()
	game.truck.use_automation=true
	game.truck.automated_aim=Vector3(7,0,2)
	game.truck.automated_spray=true
	Input.action_press("brake")
	await seconds(3)
	game.truck.automated_spray=false
	Input.action_release("brake")
	game.truck.automated_drive=Vector2(.48,-.88)
	game.truck.automated_spray=true
	var until: float=game.elapsed+2.0
	while game.elapsed<until:
		game.truck.automated_aim=game.truck.cannon.global_position+Vector3.FORWARD*100+Vector3.DOWN*3
		await process_frame
	game.truck.automated_spray=false
	Input.action_press("jump")
	await seconds(.55)
	Input.action_release("jump")
	await seconds(.7)
	game.truck.automated_drive=Vector2.ZERO
	Input.action_press("brake")
	await seconds(.8)
	game.truck.extend_ladder()
	await seconds(2.0)
	game.truck.global_position=TownLayout.FIRE+Vector3(1,1,8)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	game.camera_focus=game.truck.position
	game.stage=3
	game._update_mission()
	game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.7
	game.truck.automated_spray=true
	await seconds(5.8)
	game.truck.automated_spray=false
	Input.action_release("brake")
	print("Motion review complete: ",Engine.get_frames_drawn()," frames")
	game.queue_free()
	await process_frame
	await process_frame
	quit()
