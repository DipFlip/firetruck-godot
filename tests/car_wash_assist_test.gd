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
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.life.set_physics_process(false)
	game.truck.use_automation=true
	game.truck.position=Vector3(-58,.85,-45)
	game.truck.freeze=true
	game.truck.reset_physics_interpolation()
	var car: Dictionary=game.life.cars[0]
	for other in game.life.cars: other.node.position=Vector3(400,0,400)
	car.node.position=Vector3(-58,.12,-55)
	car.node.rotation.y=0
	car.node.freeze=true
	await frames(3)
	var origin: Vector3=game.truck.cannon.global_position
	var loose: Vector3=car.node.position+Vector3(2.7,.1,0)
	var target: Variant=game._assisted_water_target(origin,loose)
	check(target is Vector3 and target.distance_to(car.node.position+Vector3.UP*.95)<.1,"Loose aim snaps to a nearby car without treating its own collider as an obstacle")
	car.node.freeze=false
	car.node.linear_velocity=Vector3(2,0,0)
	target=game._assisted_water_target(origin,loose)
	check(target is Vector3 and target.x>car.node.position.x+.3,"Aim assist leads a moving car")
	car.node.freeze=true
	car.node.linear_velocity=Vector3.ZERO
	game.truck.automated_aim=loose
	game.truck.automated_spray=true
	for i in 105:
		await frames(1)
		game.life._physics_process(1.0/60)
		for other in game.life.cars: other.node.freeze=true
	check(car.honk_count==1 and not game.rewards.sparkles.is_empty(),"A real off-centre hose stream washes the car and produces a honk and sparkles")
	game.truck.automated_spray=false
	car.wash_time=0
	car.wash_cooldown=0
	car.honk_count=0
	game.life.water_hit(car.node.position+Vector3.UP, .55)
	for i in 30: game.life._physics_process(1.0/60)
	check(car.honk_count==0,"Half a second's worth of water does not finish a wash")
	game.life.water_hit(car.node.position+Vector3.UP,.45)
	game.life._physics_process(1.0/60)
	check(car.honk_count==1,"Brief gaps preserve water already delivered, completing after one second's worth")
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(12,12,.7)
	shape.shape=box
	wall.add_child(shape)
	game.add_child(wall)
	car.node.position=Vector3(-58,.12,-55)
	car.node.linear_velocity=Vector3.ZERO
	car.node.reset_physics_interpolation()
	loose=car.node.position+Vector3(2.7,.1,0)
	wall.position=Vector3(-58,5,-50)
	await frames(3)
	check(game._assisted_water_target(origin,loose)==null,"Car assist never shoots through a wall")
	game.queue_free()
	await process_frame
	await process_frame
	print("CAR WASH ASSIST CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
