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
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://tests/"+label+".png")
func jump_height(speed: float) -> float:
	game.truck.reset_truck()
	game.truck.full_jump_speed=speed
	await frames(70)
	var ground: float=game.truck.position.y
	Input.action_press("jump")
	await frames(50)
	Input.action_release("jump")
	var top:=ground
	for i in 100:
		await frames(1)
		top=maxf(top,game.truck.position.y)
	return top-ground
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	var new_speed: float=game.truck.full_jump_speed
	var before:=await jump_height(9.0)
	var after:=await jump_height(new_speed)
	print("Full jump measured: ",before," → ",after," m; ratio=",after/before)
	check(after/before>1.14 and after/before<1.16,"Fully charged jump reaches 15% greater physical height")
	game.truck.global_position=TownLayout.JUNE+Vector3(0,1,4)
	game.truck.reset_physics_interpolation()
	await frames(180)
	check(game.dialogue_active and absf(game.camera.size-game.TALK_CAMERA_SIZE)<.03,"NPC conversation brings the camera into its closer framing")
	check(game.truck.enabled and not game.truck.freeze,"Conversation zoom preserves driving control")
	game.end_dialogue()
	game.truck.reset_truck()
	await frames(180)
	check(absf(game.camera.size-25.8)<.03,"Leaving restores the regular driving view")
	var probe:=PhysicsRayQueryParameters3D.create(TownLayout.POOL+Vector3.UP*3,TownLayout.POOL+Vector3.DOWN*3,1,[game.truck.get_rid()])
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(probe)
	check(hit and hit.position.y < -1.2,"Pool is physically recessed with no invisible ground floor across its opening")
	probe=PhysicsRayQueryParameters3D.create(TownLayout.POOL+Vector3(6,2,0),TownLayout.POOL+Vector3(6,-2,0),1,[game.truck.get_rid()])
	hit=game.get_world_3d().direct_space_state.intersect_ray(probe)
	check(hit and absf(hit.position.y)<.02,"Ground collision remains intact beside the pool")
	check(not game.town.pool_water.visible and game.pool_progress==0,"Pool starts visibly empty with an exposed tiled basin")
	var preview:=Camera3D.new()
	preview.projection=Camera3D.PROJECTION_ORTHOGONAL
	preview.size=14.5
	game.add_child(preview)
	preview.position=TownLayout.POOL+Vector3(10,13,15)
	preview.look_at(TownLayout.POOL+Vector3.DOWN*.3)
	preview.current=true
	game.hud.hide()
	await frames(5)
	shot("pool-empty")
	game._water_hit(TownLayout.POOL+Vector3.UP*PoolBasin.EMPTY_Y,1.5625)
	await frames(5)
	var half_height: float=game.town.pool_water.position.y
	check(is_equal_approx(game.pool_progress,.5) and half_height<-.5 and game.town.pool_water.visible,"Water visibly rises halfway up the recessed pool")
	shot("pool-half")
	game._water_hit(TownLayout.POOL+Vector3.UP*half_height,1.5625)
	await frames(5)
	check(game.pool_done and is_equal_approx(game.town.pool_water.position.y,PoolBasin.FULL_Y),"Pool fills just below its rim using half the original water")
	shot("pool-full")
	game._water_hit(TownLayout.DOG+Vector3.UP*.7,1.0/.6)
	check(game.dog_done,"Dog washing needs half the original water")
	game.stage=3
	game._water_hit(TownLayout.FIRE+Vector3.UP*1.8,.6/.22)
	check(game.fire_progress>.999 and game.stage==4,"Barbecue needs 60% of the original water")
	game.queue_free()
	await process_frame
	await process_frame
	print("TUNING CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
