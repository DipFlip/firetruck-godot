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
	check(game.batched_decorations>700,"Over 700 static details are batched without changing interactive props (pavements are single generated meshes)")
	check(game.merged_scenery>120 and game.town.has_node("BakedScenery"),"Fixed scenery uses prebuilt spatial batches, including model LODs")
	var tree_surfaces:=0
	var tree_props:=0
	for prop in game.interactions.props:
		if prop.kind!="tree": continue
		tree_props+=1
		for geometry in prop.meshes:
			if geometry is MeshInstance3D: tree_surfaces=maxi(tree_surfaces,geometry.mesh.get_surface_count())
	check(tree_props==51 and tree_surfaces<=2,"Tree palette batching preserves all 51 independent interactive trees")
	var spatial_gardens:=0
	var garden_bounds_ok:=true
	for child in game.gardens.get_children():
		if child is MultiMeshInstance3D:
			spatial_gardens+=1
			var bounds: AABB=child.multimesh.get_aabb()
			garden_bounds_ok= garden_bounds_ok and bounds.size.x<20 and bounds.size.z<20
	check(spatial_gardens>20 and garden_bounds_ok,"Flower beds have local culling bounds rather than one town-wide bound")
	var water_meshes: Dictionary={}
	for drop in game.truck.pool+game.truck.splash_pool: water_meshes[drop.mesh.get_rid()]=true
	check(water_meshes.size()==1,"600 water/splash instances share one uploaded mesh")
	check(game.truck.water_batch.multimesh.instance_count==600 and game.truck.water_batch.multimesh.visible_instance_count==0,"Inactive water slots submit no visible instances")
	game.truck.use_automation=true
	game.truck.freeze=true
	game.truck.automated_spray=true
	game.truck.automated_aim=game.truck.position+Vector3(0,0,-12)
	for i in 12:
		await physics_frame
		await process_frame
	check(game.truck.water_batch.multimesh.visible_instance_count>0,"Live spray is rendered by the shared water batch")
	check(game.truck.pool.all(func(drop): return drop.layers==0),"Water does not also render individual duplicate meshes")
	game.truck.automated_spray=false
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
