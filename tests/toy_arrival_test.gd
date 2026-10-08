extends SceneTree
# Requires the Compatibility renderer: headless Dummy does not store MultiMesh transforms/custom data.
var failures:=0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func tank_hit(model: Node3D, from: Vector3, direction: Vector3) -> Vector3:
	var nearest:=Vector3.INF
	for node in model.find_children("*","MeshInstance3D",true,false):
		var transform: Transform3D=model.global_transform.affine_inverse()*node.global_transform
		var faces: PackedVector3Array=node.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var hit: Variant=Geometry3D.ray_intersects_triangle(from,direction,transform*faces[i],transform*faces[i+1],transform*faces[i+2])
			if hit!=null and from.distance_squared_to(hit)<from.distance_squared_to(nearest): nearest=hit
	return nearest
func outward_fabric_faces(sheet: ArrayMesh) -> bool:
	# Godot culls counter-clockwise front faces. Every closed slab face must
	# agree with its clockwise geometric normal, including the narrow cut edges.
	var arrays:=sheet.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var a:=indices[i]
		var b:=indices[i+1]
		var c:=indices[i+2]
		var face: Vector3=(vertices[c]-vertices[a]).cross(vertices[b]-vertices[a]).normalized()
		if face.dot(normals[a])<.999 or face.dot(normals[b])<.999 or face.dot(normals[c])<.999: return false
	return true
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.call_timer=0
	await process_frame
	var cottage: Node3D=game.town.get_node("Leo'sCottage")
	check(cottage.position.z==-25,"Barbecue cottage and its collider sit four metres farther onto grass")
	var model:=preload("res://assets/models/engine_body.glb").instantiate()
	root.add_child(model)
	var right:=tank_hit(model,Vector3(4,1.1,.25),Vector3.LEFT)
	var left:=tank_hit(model,Vector3(-4,1.1,.25),Vector3.RIGHT)
	var rear:=tank_hit(model,Vector3(0,1.1,4),Vector3.FORWARD)
	check(right.is_finite() and left.is_finite() and absf(right.x-.94)<.015 and absf(left.x+.94)<.015,"Both tank side walls contain real closed geometry behind the compartment gaps")
	check(rear.is_finite() and absf(rear.z-1.95)<.025,"The rear number sits on a closed tank wall")
	model.free()
	game.intro.start()
	game.intro.update(7.6)
	var travel: PlayMatTravel=game.travel
	check(travel.mat.visible and travel.mat.finish.get_shader_parameter("roll")==0.0,"The actual flattened map remains under the rising buildings during close shots")
	check(travel.mat.mesh.get_aabb().size.y>=.89,"The rolled carpet has a real underside and a thick closed hem")
	check(outward_fabric_faces(travel.mat.mesh),"Both fabric faces and every cut edge have outward winding and separate normals")
	check(not game.playroom.floor_art.material_override.get_shader_parameter("cut_pool"),"The room floor stays continuous beneath the empty incoming mat")
	check(travel.assembly.all(func(item): return not game.playroom.room_props.is_ancestor_of(item.node)),"Room furniture remains in place outside the mat's toy assembly")
	var early_house:=PlayMatTravel.arrival_delay(PlayMatTravel.first_house(false),2)
	var early_tree:=PlayMatTravel.arrival_delay(PlayMatTravel.first_house(false)+Vector3(12,0,2),3)
	var first_trees:=travel.assembly.filter(func(item): return item.node is BreakableProp and item.node.kind=="tree" and item.transform.origin.distance_to(PlayMatTravel.first_house(false))<32)
	check(first_trees.size()>=2 and first_trees.all(func(item): return item.delay>.015 and item.delay<.12),"Several real trees arrive beside the first cottage before the neighbour")
	var june:=travel.assembly.filter(func(item): return item.node==game.town.people[2])
	check(early_house<early_tree and not june.is_empty() and early_tree<june[0].delay,"The first house, nearby trees and neighbour arrive in that order")
	var actors:=travel.assembly.filter(func(item): return item.node in game.town.people or item.node==game.barbecue or game.life.cars.any(func(car): return car.node==item.node))
	check(actors.size()==game.town.people.size()+game.life.cars.size()+1 and actors.all(func(item): return item.drop),"People, cars and the barbecue fall as complete toys, with their parts attached")
	var ramp_toys:=travel.assembly.filter(func(item): return item.node is StaticBody3D and item.node in game.ramps.ramps)
	check(ramp_toys.is_empty(),"Experimental Maple Bay jump ramps are removed")
	var floors:=travel.assembly.filter(func(item): return not item.gpu and absf(item.transform.basis.get_scale().x)>150 and absf(item.transform.basis.get_scale().z)>150)
	check(not floors.is_empty() and floors.all(func(item): return item.flat and item.node.global_transform.is_equal_approx(item.transform)),"The full-size town foundation stays on the floor throughout toy arrivals")
	var baked:=travel.assembly.filter(func(item): return item.gpu)
	var kinds: Dictionary={}
	for item in baked:
		var colours: PackedColorArray=item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for colour in colours: kinds[roundi(colour.a*4)]=true
	check(not baked.is_empty() and kinds.has(2) and kinds.has(3) and kinds.has(4),"Baked scenery contains separate building-rise, toy-drop and small-detail sprout data without splitting its draw batches")
	var details:=travel.assembly.filter(func(item): return not item.gpu and item.sprout and item.instance>=0)
	check(details.size()>500,"Hundreds of tiny flower and leaf parts sprout instead of raining down")
	var detail: Dictionary=details[0]
	travel.grow_assembly(detail.delay+.07)
	var growing: Transform3D=detail.node.global_transform*detail.node.multimesh.get_instance_transform(detail.instance)
	check(growing.origin.y<=detail.transform.origin.y+.001 and growing.basis.get_scale().length()<detail.transform.basis.get_scale().length(),"Small details scale up at their planted location without a sky offset")
	var rounded:=true
	for point in travel.mat.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var corner:=Vector2(absf(point.x),absf(point.z))-Vector2(75.5,75.5)
		var distance:=corner.max(Vector2.ZERO).length()+minf(maxf(corner.x,corner.y),0)-4.5
		rounded=rounded and distance<.001
	check(rounded,"The physical mat and rounded binding follow the same corner curve")
	var blocks:=travel.assembly.filter(func(item): return item.drop and item.instance>=0 and item.node.get_parent().name=="BoundaryBlocks")
	var first: Dictionary=blocks[0]
	var last_delay:=0.0
	var first_delay:=1.0
	for block in blocks: first_delay=minf(first_delay,block.delay); last_delay=maxf(last_delay,block.delay)
	check(last_delay-first_delay>.035,"Border blocks have a visible stagger rather than a single simultaneous landing")
	var west:=travel.assembly.filter(func(item): return not item.gpu and item.boundary and item.transform.origin.x< -78 and item.transform.origin.x> -84 and absf(item.transform.origin.z)<78 and item.transform.origin.y<2.5)
	west.sort_custom(func(a,b): return a.transform.origin.z<b.transform.origin.z)
	var ordered:=west.size()>10
	for i in range(1,west.size()): ordered=ordered and west[i].delay>=west[i-1].delay
	check(ordered and (west[-1].delay-west[0].delay)*(PlayMatTravel.ARRIVAL_END-PlayMatTravel.ARRIVAL_START)>2.5,"The first perimeter wall assembles in a travelling cascade")
	var spread:=true
	# Each quadrant gets early, middle and late arrivals rather than a cohort
	# timed to whichever neighbourhood the camera is currently showing.
	for quadrant in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
		var buckets: Dictionary={}
		for x in range(8,70,8):
			for z in range(8,70,8):
				var delay:=PlayMatTravel.arrival_delay(Vector3(x*quadrant.x,0,z*quadrant.y),3)
				if delay>=.28: buckets[mini(2,floori((delay-.28)/.54*3))]=true
		spread=spread and buckets.size()==3
	check(spread,"Every map quadrant receives scattered arrivals throughout the assembly")
	var grain: Color=first.node.multimesh.get_instance_custom_data(first.instance)
	travel.grow_assembly(first.delay+.06)
	var falling: Transform3D=first.node.global_transform*first.node.multimesh.get_instance_transform(first.instance)
	check(falling.origin.y>first.transform.origin.y+3 and not falling.basis.is_equal_approx(first.transform.basis),"A falling block keeps its full size and tumbles before landing")
	check(first.node.multimesh.get_instance_custom_data(first.instance)==grain and grain.r>0,"Wood grain seed and rest dimensions remain fixed while the block moves")
	travel.grow_assembly(1)
	check(blocks.all(func(item): return item.settled),"All staggered blocks settle before camera handover")
	game.intro.finish()
	check(first.node.multimesh.get_instance_transform(first.instance).is_equal_approx(first.node.global_transform.affine_inverse()*first.transform),"Skip/completion restores exact block poses")
	check(baked.all(func(item): return item.node.material_override==item.original_material and item.node.custom_aabb==item.bounds),"Completion restores the normal materials and tight scenery culling bounds")
	travel.begin_assembly(false)
	var replay:=travel.assembly.filter(func(item): return item.gpu)
	check(replay.all(func(item): return baked.any(func(old): return old.node==item.node and old.material==item.material)),"The live intro reuses the actual materials prepared during background warmup")
	check(travel.mat.shared_flat_sheet.get_faces().size()<1000,"The settled carpet retains its thick rounded shape with a small mesh")
	travel.flatten_for_print()
	travel.grow_assembly(0)
	check(replay.all(func(item): return not item.node.visible and not item.material.get_shader_parameter("print_mode")),"Rewinding a flattened assembly hides its pending batches and restores toy animation")
	travel.grow_assembly(1)
	check(replay.all(func(item): return item.node.visible==item.visible and item.node.custom_aabb==item.bounds),"A warmed/replayed assembly restores every batch before handover")
	travel.finish_assembly()
	game.queue_free()
	await process_frame
	await process_frame
	print("TOY ARRIVAL CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
