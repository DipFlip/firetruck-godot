extends SceneTree

var game: Node3D
var failures:=0

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, description: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+description)
	if not ok: failures+=1
func shot(filename: String) -> void:
	await frames(4)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/"+filename+".png")
func rendered_bounds(node: Node3D) -> AABB:
	var result:=AABB()
	var first:=true
	var inverse:=node.global_transform.affine_inverse()
	for geometry in node.find_children("*","GeometryInstance3D",true,false):
		var parts: Array[AABB]=[]
		if geometry is MultiMeshInstance3D:
			for i in geometry.multimesh.instance_count:
				parts.append((inverse*geometry.global_transform*geometry.multimesh.get_instance_transform(i))*geometry.multimesh.mesh.get_aabb())
		elif geometry is MeshInstance3D:
			parts.append((inverse*geometry.global_transform)*geometry.mesh.get_aabb())
		for part in parts:
			result=part if first else result.merge(part)
			first=false
	return result
func push_frame(spray: bool) -> void:
	if game.dialogue_active: game.interact()
	var forward: Vector3=-game.camera.global_basis.z
	forward.y=0
	game.truck.automated_drive=Vector2(Vector3.RIGHT.dot(game.camera.global_basis.x),-Vector3.RIGHT.dot(forward.normalized()))
	game.truck.automated_spray=spray
	game.truck.automated_aim=game.truck.position+Vector3(-13,-.8,2)
	await frames(1)
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.set_process(false)
	game.travel.set_process(false)
	game.truck.use_automation=true
	var rail: NorthlineRailway=game.railway
	rail.briefed=true
	rail.driver_guard.enabled=false
	await frames(3)
	var tracks: Node3D=rail.get_node("TownRailTracks")
	var rails:=0
	for node in tracks.get_children():
		if node is MeshInstance3D and node.scale.x>159 and node.scale.z<.2: rails+=1
		if node is MultiMeshInstance3D:
			for i in node.multimesh.instance_count:
				var scale: Vector3=node.multimesh.get_instance_transform(i).basis.get_scale()
				if scale.x>159 and scale.z<.2: rails+=1
	if DisplayServer.get_name()!="headless":
		check(rails==2,"Both rails continue across all three roads")
	else: print("SKIP: Rail mesh transforms require a rendering server; covered by the Compatibility run")
	for road in [-36,0,36]:
		var crossing: Node3D=tracks.get_node("RoadCrossing"+str(road))
		var bounds:=rendered_bounds(crossing)
		if DisplayServer.get_name()!="headless":
			check(bounds.size.x>8.5 and bounds.size.z>3.2 and bounds.end.y<.16,"Timber crossing spans the street below the rail tops: "+str(road))
		else: check(crossing.get_child_count()>0,"Timber crossing exists at street "+str(road))
	check(rail.engine.position.x==0 and not game.travel.north_exit_clear(),"The stalled train starts across the Motorway road")
	var passage: Node3D=game.playroom.get_node("MotorwayPassage")
	check(passage.get_meta("boundary_blocks",false) and rendered_bounds(passage).size.z>15,"Turned timber borders line the exit passage up to the track")
	var space:=game.get_world_3d().direct_space_state
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,-55),Vector3(0,1,-83),2,[game.truck.get_rid()]))
	check(not hit.is_empty() and hit.collider==rail.engine,"The physical obstruction on the road is the locomotive")
	for side in [-1,1]:
		hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(side*6.4,1,-64),Vector3(side*6.4,1,-80),Playroom.WALL_LAYER))
		check(not hit.is_empty(),"The exit's timber lining has a solid collider: "+str(side))
	game.truck.position=Vector3(0,.85,-56)
	game.truck.heading=0
	game.truck.rotation.y=0
	game.truck.linear_velocity=Vector3(0,0,-12)
	game.truck.reset_physics_interpolation()
	await frames(90)
	check(game.truck.position.z>NorthlineRailway.TRACK_Z+2 and not game.travel.active,"Driving north stops against the train before entering the passage")
	game.truck.position=rail.engine.position+Vector3(-7,.73,.8)
	game.truck.heading=-PI/2
	game.truck.rotation.y=-PI/2
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	for i in 180: await push_frame(false)
	check(rail.pushed_once and rail.push_locked and not rail.started,"The train's rear remains accessible for a real unassisted push")
	for i in 360:
		if rail.started: break
		await push_frame(true)
	check(rail.started,"A real eastward push with backwards hose recoil still starts the relocated train")
	game.truck.automated_drive=Vector2.ZERO
	game.truck.automated_spray=false
	game.rewards._process(2)
	game.end_dialogue()
	rail.set_physics_process(false)
	rail.engine.position.x=18
	rail.engine.linear_velocity=Vector3.ZERO
	rail.engine.reset_physics_interpolation()
	await frames(3)
	check(game.travel.north_exit_clear(),"Moving the train aside physically opens the passage")
	hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,-65),Vector3(0,1,-84),Playroom.WALL_LAYER|2,[game.truck.get_rid()]))
	check(hit.is_empty(),"The cleared passage has no leftover barrier collider")
	game.truck.position=Vector3(0,.85,-78)
	game.truck.heading=0
	game.truck.rotation.y=0
	game.truck.linear_velocity=Vector3(0,0,-18)
	game.truck.reset_physics_interpolation()
	game.travel.exit_armed=true
	game.travel.set_process(true)
	await frames(75)
	check(game.travel.active and game.travel.destination_race,"Driving through the clear passage starts Motorway travel")
	game.travel.finish()
	game.travel.start(false)
	game.travel.finish()
	game.travel.set_process(false)
	game.call_timer=0
	game.end_dialogue()
	if "--capture" in OS.get_cmdline_user_args():
		game.hud.hide()
		game.truck.hide()
		rail.set_physics_process(false)
		rail.engine.freeze=true
		rail.engine.position=Vector3(0,.12,NorthlineRailway.TRACK_Z)
		game.camera.position=Vector3(24,36,-32)
		game.camera.look_at(Vector3(0,0,-68))
		game.camera.size=42
		await shot("railway-passage-closed")
		rail.engine.position.x=18
		await shot("railway-passage-open")
		game.camera.position=Vector3(32,70,-5)
		game.camera.look_at(Vector3(0,0,-61))
		game.camera.size=100
		await shot("railway-road-crossings")
	game.queue_free()
	await process_frame
	await process_frame
	print("RAILWAY PASSAGE CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(1 if failures else 0)
