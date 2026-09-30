extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.touch_drive=Vector2(.4,-.9)
	var start: Vector3=game.truck.position
	await frames(100)
	check(game.truck.position.distance_to(start)>7,"Touch joystick drives the real rigid-body truck")
	game.truck.touch_drive=Vector2.ZERO
	game.truck.touch_aim=Vector2(-1,0)
	var water: float=game.truck.water
	await frames(40)
	check(game.truck.spraying and game.truck.water<water and game.truck.spray_direction.length()>.9,"Hose stick independently aims and sprays")
	game.truck.touch_aim=Vector2.ZERO
	await frames(2)
	check(not game.truck.spraying,"Releasing hose stick stops spraying")
	game.talk("DISPATCH  /  INCOMING CALL","Touch to continue the call.",4)
	Input.action_press("jump")
	game.web_controls._send("jump")
	check(game.dialogue_active and game.hud.char_count==game.hud.full_text.length(),"Touch jump/talk reveals speech first")
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	game.web_controls._send("jump")
	await frames(20)
	check(not game.dialogue_active and game.truck.charge==0,"Touch talk advances without charging a jump")
	Input.action_release("jump")
	await frames(3)
	game.web_controls._send("interact")
	await frames(40)
	check(game.truck.ladder_deployed,"Touch ladder action deploys ladder")
	game.web_controls._send("interact")
	await frames(40)
	check(not game.truck.ladder_deployed,"Touch ladder action retracts ladder")
	game.truck.reset_truck()
	await frames(40)
	Input.action_press("jump")
	game.web_controls._send("jump")
	await frames(45)
	Input.action_release("jump")
	await frames(10)
	check(game.truck.position.y>1.5,"Holding and releasing touch jump launches the truck")
	game.web_controls._send("pause")
	check(game.paused,"Touch pause opens pause state")
	game.web_controls._send("pause")
	check(not game.paused,"Touch pause can resume the game")
	game.queue_free()
	await process_frame
	await process_frame
	print("TOUCH CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(failures)
