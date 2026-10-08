extends SceneTree
# Test the actual camera path against visible geometry bounds, including the
# conservative shader bounds around flying toys, throughout both introductions.
var game: Node3D
var failures:=0
var minimum_clearance:=INF
var clipping: Dictionary={}
func _initialize() -> void: call_deferred("run")
func crosses_near_plane(corners: Array[Vector3], half_width: float, half_height: float, near: float) -> bool:
	# A rotated wall or wide, flat road can have a view-space AABB that crosses
	# the lens while its actual box misses the visible near-plane rectangle.
	var cut:=PackedVector2Array()
	for i in 8:
		for bit in [1,2,4]:
			var j: int=i^bit
			if j<i: continue
			var a:=corners[i]
			var b:=corners[j]
			if (a.z+near)*(b.z+near)>0 or absf(a.z-b.z)<.00001: continue
			var p:=a.lerp(b,(-near-a.z)/(b.z-a.z))
			cut.append(Vector2(p.x,p.y))
	if cut.size()<3: return false
	var viewport:=PackedVector2Array([Vector2(-half_width,-half_height),Vector2(half_width,-half_height),Vector2(half_width,half_height),Vector2(-half_width,half_height)])
	return not Geometry2D.intersect_polygons(Geometry2D.convex_hull(cut),viewport).is_empty()
func scan(time: float, world: String) -> void:
	var camera: Camera3D=game.camera
	var inverse:=camera.global_transform.affine_inverse()
	var projection:=camera.get_camera_projection()
	var half_width:=1/projection.x.x
	var half_height:=1/projection.y.y
	for node in game.find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree() or (node.layers&camera.cull_mask)==0: continue
		# Dust instance transforms are random seeds. Its shader wraps tiny
		# billboards around the view; that seed AABB is not visible geometry.
		if node is RoomDust: continue
		var bounds: AABB=node.get_aabb()
		if node is MeshInstance3D and node.custom_aabb.has_volume(): bounds=node.custom_aabb
		# Floor planes span the room, but their actual surface is below the lens.
		if bounds.size.y<.05 and bounds.size.x>300: continue
		var view_bounds:=AABB(inverse*node.global_transform*bounds.position,Vector3.ZERO)
		var corners: Array[Vector3]=[]
		for corner in 8:
			var at: Vector3=inverse*node.global_transform*bounds.get_endpoint(corner)
			corners.append(at)
			view_bounds=view_bounds.expand(at)
		var end:=view_bounds.end
		if view_bounds.position.x>half_width or end.x< -half_width or view_bounds.position.y>half_height or end.y< -half_height: continue
		if view_bounds.position.z> -camera.near: continue
		var clearance: float=-end.z-camera.near
		if clearance>0: minimum_clearance=minf(minimum_clearance,clearance)
		elif crosses_near_plane(corners,half_width,half_height,camera.near): clipping[str(node.get_path())]={"time":time,"world":world,"clearance":clearance,"at":node.global_position,"bounds":bounds}
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.call_timer=0
	for portrait in [false,true]:
		root.size=Vector2i(480,850) if portrait else Vector2i(1280,800)
		await process_frame
		game.intro.start()
		for i in 480:
			var time:=i*.05
			game.intro.update(time-game.intro.clock)
			scan(time,"maple-portrait" if portrait else "maple")
		game.intro.finish()
		game.travel.race_visited=false
		game.travel.start(true)
		for i in 520:
			var time:=i*.05
			game.travel._update_transition(time-game.travel.clock)
			scan(time,"race-portrait" if portrait else "race")
		game.travel.finish()
		for x in [-72,-36,0,36,72]:
			game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(x,.85,76)
			game.camera_focus=game.truck.global_position
			game.camera.global_position=game.camera_focus+game.gameplay_camera_offset()
			game.camera.look_at(game.camera_focus)
			game.camera.size=25.8
			scan(0,"motorway-southern-edge")
		game.travel.start(false)
		for i in 84:
			var time:=i*.05
			game.travel._update_transition(time-game.travel.clock)
			scan(time,"return")
		game.travel.finish()
	if not clipping.is_empty():
		print("FAIL: Near-plane clipping: ",clipping)
		failures+=1
	else: print("PASS: No visible toy/furniture bounds intersect the camera's near plane across both complete tours and short return, in landscape and portrait")
	print("Minimum conservative geometry clearance: ",minimum_clearance)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
