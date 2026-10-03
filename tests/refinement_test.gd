extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func action(name: String) -> void:
	var event:=InputEventAction.new()
	event.action=name
	event.pressed=true
	game._unhandled_input(event)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=3
	game._update_mission()
	game.truck.use_automation=true
	game.truck.position=TownLayout.FIRE+Vector3(0,1,23)
	game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.7
	game.truck.automated_spray=true
	Input.action_press("brake")
	await frames(180)
	check(game.fire_progress==0 and not game.truck.assisted,"Shorter hose cannot extinguish a fire across the block")
	game.truck.position=TownLayout.FIRE+Vector3(0,1,8)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.automated_aim=TownLayout.FIRE+Vector3(3.5,1.7,0)
	await frames(25)
	check(game.truck.assisted,"Aim assist acquires fire when aiming beside its hitbox")
	await frames(155)
	check(game.fire_progress>.25,"Assisted ballistic water actually reaches and cools the fire")
	check(game.fire_feedback>0 and not game.atmosphere.steam.is_empty(),"Successful fire hits produce visible white steam")
	game.truck.automated_aim=game.truck.position+Vector3(0,0,10)
	await frames(150)
	var before: float=game.fire_progress
	check(not game.truck.assisted,"Aim assist does not pull shots toward a target behind the aim")
	await frames(90)
	check(game.fire_progress==before and game.fire_feedback==0 and game.atmosphere.steam.is_empty(),"Misses cause no cooling and the hit feedback clears")
	game.truck.automated_spray=false
	game.truck.position=TownLayout.FIRE+Vector3(0,1,8)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.7
	await frames(5)
	check(game.truck.shot_is_clear(game.truck.cannon.global_position,TownLayout.FIRE+Vector3.UP*1.7),"Nearby fire has a reachable ballistic path before obstruction")
	var wall:=Node3D.new()
	game.add_child(wall)
	TownProps.collider(wall,TownLayout.FIRE+Vector3(0,2.5,4),Vector3(6,5,.5))
	await frames(5)
	check(not game.truck.shot_is_clear(game.truck.cannon.global_position,TownLayout.FIRE+Vector3.UP*1.7),"Ballistic assist rejects an obstacle within hose range")
	before=game.fire_progress
	game.truck.automated_spray=true
	await frames(100)
	check(not game.truck.assisted and game.fire_progress==before,"Neither assist nor water can cool a fire through a wall")
	game.truck.automated_spray=false
	wall.queue_free()
	await frames(3)
	game.stage=4
	game.truck.position=TownLayout.DOG+Vector3(0,1,7)
	game.truck.linear_velocity=Vector3.ZERO
	game.proximity_latches[2]=true
	game.truck.automated_aim=TownLayout.DOG+Vector3(2.8,.7,0)
	game.truck.automated_spray=true
	game.truck.water=100
	await frames(25)
	var dog_assisted: bool=game.truck.assisted
	await frames(95)
	check(dog_assisted and game.dog_progress>.1,"Aim assist also helps the dog washing job")
	game.truck.position=TownLayout.POOL+Vector3(0,1,-5)
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.automated_aim=TownLayout.POOL+Vector3(5.3,.85,0)
	game.truck.water=100
	await frames(120)
	check(game.truck.assisted and game.pool_progress>.1,"Aim assist guides near-edge pool shots into the water")
	game.truck.automated_spray=false
	Input.action_release("brake")
	game.truck.reset_truck()
	await frames(40)
	game.truck.position=TownLayout.MAYA+Vector3(0,1,4)
	game.truck.linear_velocity=Vector3.ZERO
	game.talk("MAYA  /  MAPLE GREEN","Space can reveal this line and advance it.",4)
	Input.action_press("jump")
	action("jump")
	check(game.dialogue_active and game.hud.char_count==game.hud.full_text.length(),"First Space reveals the complete dialogue line")
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	action("jump")
	await frames(30)
	check(not game.dialogue_active and game.truck.charge==0,"Space advances dialogue without charging a jump while held")
	Input.action_release("jump")
	await frames(10)
	check(game.truck.position.y<1.1,"Releasing conversation Space does not accidentally jump")
	action("interact")
	await frames(40)
	check(game.truck.ladder_amount>.95,"E deploys the ladder")
	action("interact")
	await frames(40)
	check(game.truck.ladder_amount==0,"Second E retracts the ladder immediately")
	var large_mounds:=0
	for child in game.town.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh and child.scale.x>10: large_mounds+=1
	check(large_mounds==0,"Oversized grass mounds are removed from the baked scene")
	var butterfly: Node3D=game.gardens.butterflies[0].node
	game.set_process(false)
	game.camera.position=butterfly.position+game.camera_offset
	game.camera.look_at(butterfly.position)
	var initial:=butterfly.position
	await frames(80)
	check(butterfly.position.distance_to(initial)>.3 and game.gardens.flower_count>100,"Butterflies animate around the new flower beds")
	action("pause")
	initial=butterfly.position
	await frames(10)
	check(butterfly.position==initial,"Butterflies respect pause")
	game.queue_free()
	await process_frame
	await process_frame
	print("REFINEMENT CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
