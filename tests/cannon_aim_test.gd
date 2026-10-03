extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func mouse_at(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	root.push_input(event)
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.freeze=true
	game.set_process(false)
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	var truck: FireEngine=game.truck
	truck.aim_assist=Callable()
	await frames(3)
	var center: Vector2=game.camera.unproject_position(truck.get_global_transform_interpolated().origin)
	var close:=truck.mouse_aim_direction(center+Vector2(24,-36))
	var far:=truck.mouse_aim_direction(center+Vector2(240,-360))
	check(close.dot(far)>.99999 and absf(close.y)<.00001,"Moving the pointer farther along the same screen direction cannot change aim or elevation")
	check(close.dot(truck.world_aim_direction(Vector2(2,-3).normalized()))>.99999,"Mouse and joystick use the same camera-relative direction mapping")
	# Actual input and fire simulation: cursor radius cannot shorten the stream.
	Input.action_press("spray")
	mouse_at(center+Vector2(32,0))
	await frames(12)
	var near_aim: Vector3=truck.aim_point-truck.cannon.global_position
	var near_direction:=truck.spray_direction
	mouse_at(center+Vector2(320,0))
	await frames(12)
	var far_aim: Vector3=truck.aim_point-truck.cannon.global_position
	check(near_aim.distance_to(far_aim)<.001 and near_direction.dot(truck.spray_direction)>.999,"Near and far mouse positions produce the same fixed-range live spray")
	check(truck.droplets.size()>0 and truck.spray_direction.dot(-truck.cannon.global_basis.z)>.99999,"Emitted water follows the animated barrel")
	Input.action_release("spray")
	await frames(2)
	# A direction change takes the requested time, including a paused first step.
	truck.set_physics_process(false)
	truck.cannon.quaternion=Quaternion.IDENTITY
	truck.cannon_turn_target=Quaternion.IDENTITY
	truck.cannon_turn_elapsed=truck.CANNON_TURN_SECONDS
	var original:=truck.cannon.quaternion
	truck._turn_cannon(Vector3.RIGHT,0)
	check(truck.cannon.quaternion.is_equal_approx(original),"Selecting a new aim cannot teleport the cannon on the first frame")
	truck._turn_cannon(Vector3.RIGHT,.075)
	var half:=(-truck.cannon.global_basis.z).dot(Vector3.RIGHT)
	check(half>.6 and half<.8,"A ninety-degree direction change is halfway around after 75 milliseconds")
	truck._turn_cannon(Vector3.RIGHT,.075)
	check((-truck.cannon.global_basis.z).dot(Vector3.RIGHT)>.9999,"The cannon completes its direction change at 150 milliseconds")
	truck.spray_requested=false
	truck._update_aim()
	var resting:=truck.cannon.quaternion
	var world_before: Vector3=-truck.cannon.global_basis.z
	truck.rotation.y+=PI/2
	truck._update_aim()
	var world_after: Vector3=-truck.cannon.global_basis.z
	check(truck.cannon.quaternion.is_equal_approx(resting) and absf(world_before.dot(world_after))<.01,"An idle cannon keeps its local pose and rotates with the truck")
	mouse_at(center+Vector2(-300,200))
	truck._update_aim()
	check(truck.cannon.quaternion.is_equal_approx(resting),"Moving an idle mouse does not rotate the gun away from the truck")
	truck.reset_truck()
	check(truck.cannon.quaternion.is_equal_approx(Quaternion.IDENTITY),"Recovery resets the turret and its animation state")
	game.queue_free()
	await process_frame
	await process_frame
	print("CANNON AIM CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
