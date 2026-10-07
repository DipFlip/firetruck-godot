extends SceneTree
# Test the actual camera path against visible geometry bounds, including the
# conservative shader bounds around flying toys, throughout both introductions.
var game: Node3D
var failures:=0
var minimum_clearance:=INF
var clipping: Dictionary={}
func _initialize() -> void: call_deferred("run")
func scan(time: float, world: String) -> void:
	var camera: Camera3D=game.camera
	var inverse:=camera.global_transform.affine_inverse()
	var projection:=camera.get_camera_projection()
	var half_width:=1/projection.x.x
	var half_height:=1/projection.y.y
	for node in game.find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree() or node.layers==0: continue
		var bounds: AABB=node.get_aabb()
		if node is MeshInstance3D and node.custom_aabb.has_volume(): bounds=node.custom_aabb
		# Floor planes span the room, but their actual surface is below the lens.
		if bounds.size.y<.05 and bounds.size.x>300: continue
		var view_bounds:=AABB(inverse*node.global_transform*bounds.position,Vector3.ZERO)
		for corner in 8:
			view_bounds=view_bounds.expand(inverse*node.global_transform*bounds.get_endpoint(corner))
		var end:=view_bounds.end
		if view_bounds.position.x>half_width or end.x< -half_width or view_bounds.position.y>half_height or end.y< -half_height: continue
		if view_bounds.position.z> -camera.near: continue
		var clearance: float=-end.z-camera.near
		minimum_clearance=minf(minimum_clearance,clearance)
		if clearance<=0: clipping[str(node.get_path())]={"time":time,"world":world,"clearance":clearance}
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
		game.travel.start(false)
		for i in 56:
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
