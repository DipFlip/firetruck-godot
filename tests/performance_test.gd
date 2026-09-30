extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+description)
	if not ok: failures+=1
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	await process_frame
	check(game.batched_decorations>1000,"Over 1000 static details are batched without changing interactive props")
	var water_meshes: Dictionary={}
	for drop in game.truck.pool+game.truck.splash_pool: water_meshes[drop.mesh.get_rid()]=true
	check(water_meshes.size()==1,"600 water/splash instances share one uploaded mesh")
	var track_meshes: Dictionary={}
	for track in game.truck.effects.track_pool: track_meshes[track.mesh.get_rid()]=true
	check(track_meshes.size()==1,"480 skid slots share one uploaded plane")
	var reward_count: int=game.rewards.get_child_count()
	for job in ["fire","dog","pool"]: game.rewards.celebrate(job,Vector3(200,2,200),"LEO","Thanks!")
	check(game.rewards.sparkles.size()==84 and game.rewards.get_child_count()==reward_count,"Three simultaneous rewards allocate no new render nodes")
	for i in 150:
		await physics_frame
		await process_frame
	check(game.rewards.sparkles.is_empty() and game.rewards.free_stars.size()==84,"Reward particles all return to their pool")
	check(game.rewards.get_child_count()==reward_count,"Reward cleanup retains reusable GPU resources")
	game.queue_free()
	await process_frame
	await process_frame
	print("PERFORMANCE CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
