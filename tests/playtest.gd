extends SceneTree

var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition: print("PASS: "+description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

func frames(count: int) -> void:
	for i in count: await physics_frame

func interact() -> void:
	if game.dialogue_active and game.hud.char_count<game.hud.full_text.length(): game.interact()
	game.interact()

func place(pos: Vector3) -> void:
	game.truck.global_position=pos
	game.truck.linear_velocity=Vector3.ZERO
	await frames(3)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(120)
	check(game.dialogue_active,"Incoming dispatch starts the mission")
	interact()
	check(game.stage==1,"Accept call begins cat objective")
	game.truck.use_automation=true
	var start: Vector3=game.truck.position
	game.truck.automated_drive=Vector2(0,-1)
	await frames(90)
	check(game.truck.position.distance_to(start)>8,"Drive accelerates and covers ground")
	check(game.truck.position.y>0.65 and game.truck.position.y<1.1,"Chassis stays stably grounded")
	game.truck.automated_drive=Vector2.ZERO
	await place(TownLayout.MAYA+Vector3(-2,1,1))
	check(game.dialogue_active and game.rescued,"Maya starts talking automatically on proximity")
	interact()
	var ladder_event:=InputEventAction.new()
	ladder_event.action="interact"
	ladder_event.pressed=true
	game._unhandled_input(ladder_event)
	await frames(60)
	await place(Vector3(17,1,-3))
	await frames(200)
	interact()
	check(game.stage==5 and game.barbecue_call_delay>0,"Cat rescue leaves time to explore before dispatch calls")
	await place(TownLayout.LEO+Vector3(0,1,2))
	check(game.dialogue_active,"Leo greets truck automatically")
	interact()
	check(game.stage==3,"Leo enables firefighting objective")
	await place(TownLayout.FIRE+Vector3(1,1,8))
	game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.7
	game.truck.automated_spray=true
	Input.action_press("brake")
	await frames(420)
	print("Fire progress: ",game.fire_progress," tank: ",game.truck.water)
	check(game.stage==4,"Real water trajectories extinguish barbecue")
	check(game.truck.water<100,"Spray consumes tank")
	game.truck.automated_spray=false
	Input.action_release("brake")
	if game.dialogue_active: interact()
	await place(Vector3(0,1,12))
	var before: Vector3=game.truck.position
	game.truck.automated_aim=Vector3(0,1,-10)
	game.truck.automated_spray=true
	await frames(60)
	check(game.truck.position.z>before.z+1,"Water recoil pushes opposite nozzle")
	game.truck.automated_spray=false
	await place(Vector3(-5,1,12))
	game.truck.water=10
	await frames(240)
	check(game.truck.water>95,"Hydrant refills automatically without E")
	await place(TownLayout.JUNE+Vector3(0,1,3))
	check(game.dialogue_active,"June greets on proximity")
	interact()
	await place(TownLayout.DOG+Vector3(0,1,7))
	game.truck.automated_aim=TownLayout.DOG+Vector3.UP*.7
	game.truck.automated_spray=true
	Input.action_press("brake")
	await frames(300)
	check(game.dog_done,"Water cleans Biscuit")
	game.truck.automated_spray=false
	await place(TownLayout.OLIVER+Vector3(-2,1,0))
	check(game.dialogue_active,"Oliver greets on proximity")
	interact()
	await place(TownLayout.POOL+Vector3(0,1,-5))
	game.truck.automated_aim=TownLayout.POOL+Vector3.UP*.75
	game.truck.water=100
	game.truck.automated_spray=true
	await frames(600)
	check(game.pool_done,"Water fills pool")
	game.truck.automated_spray=false
	Input.action_release("brake")
	game.truck.reset_truck()
	await frames(120)
	check(game.truck.position.distance_to(Vector3(0,0.8,12))<1,"Recovery safely returns to station")
	game.truck.water=0
	game.truck.automated_spray=true
	await frames(10)
	check(not game.truck.spraying and game.truck.water==0,"Empty tank cannot spray or go negative")
	game.truck.automated_spray=false
	Input.action_press("jump")
	await frames(35)
	Input.action_release("jump")
	await frames(12)
	check(game.truck.position.y>1.5,"Charged hop lifts chassis off ground")
	await frames(120)
	var pause_event:=InputEventAction.new()
	pause_event.action="pause"
	pause_event.pressed=true
	game._unhandled_input(pause_event)
	var paused_position: Vector3=game.truck.position
	await frames(20)
	check(game.paused and game.truck.position.distance_to(paused_position)<0.01,"Pause freezes vehicle simulation")
	game._unhandled_input(pause_event)
	check(not game.paused and game.truck.is_physics_processing(),"Resume restores simulation")
	# Front wall of bakery: drive toward it and verify solid geometry blocks travel.
	await place(Vector3(18,1,26))
	game.truck.heading=0
	game.truck.automated_drive=Vector2(0.48,-0.88)
	await frames(150)
	check(game.truck.position.z>22.7,"Building collider blocks the truck")
	game.truck.automated_drive=Vector2.ZERO
	await place(TownLayout.FIRE+Vector3(0,1,-18))
	game.stage=3
	game.fire_progress=0
	game.truck.water=100
	game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.7
	game.truck.automated_spray=true
	Input.action_press("brake")
	await frames(120)
	check(game.fire_progress==0,"Building blocks water from reaching a target behind it")
	game.truck.automated_spray=false
	Input.action_release("brake")
	game.stage=4
	game.fire_progress=1
	game.town.fire_amount=0
	game._update_mission()
	game.truck.reset_truck()
	game.truck.water=100
	await frames(90)
	if DisplayServer.get_name()!="headless":
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://tests/town-preview.png")
	print("PLAYTEST: ","ALL PASS" if failures.is_empty() else str(failures))
	pause_event=null
	if game.audio: game.audio.stop()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
