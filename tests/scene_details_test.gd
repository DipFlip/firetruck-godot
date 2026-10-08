extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.intro.finish()
	game.travel.set_process(false)
	await frames(2)
	var pavements: Node3D=game.atmosphere.get_node("Sidewalks")
	var within_mat:=true
	for node in pavements.get_children():
		if not node is MeshInstance3D: continue
		for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			within_mat=within_mat and absf(vertex.x)<=80 and absf(vertex.z)<=80
	check(within_mat,"Every sidewalk vertex stays inside the felt mat")
	var hydrants_on_pavement:=true
	for p in game.town.hydrants:
		for offset in [Vector3.ZERO,Vector3(.45,0,.25),Vector3(-.45,0,-.25),Vector3(.45,0,-.25),Vector3(-.45,0,.25)]:
			var query:=PhysicsRayQueryParameters3D.create(p+offset+Vector3.UP,p+offset+Vector3.DOWN,8)
			var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
			hydrants_on_pavement=hydrants_on_pavement and not hit.is_empty() and hit.position.y>=.099
	check(hydrants_on_pavement,"Each hydrant's full footprint is supported by the sidewalk")
	check(game.ramps.ramps.is_empty(),"Maple Bay has no experimental jump wedges")
	game.intro.start()
	check(game.town.fire_amount==0 and game.town.flames.all(func(flame): return not flame.is_visible_in_tree()),"Barbecue flames are absent while the mat and toys are introduced")
	check(game.railway.gates.all(func(gate): return not gate.is_visible_in_tree()),"Complete railway portals, including striped stoppers, wait for their toy arrival")
	game.intro.finish()
	await frames(2)
	check(game.town.fire_amount==1 and game.town.flames.all(func(flame): return flame.is_visible_in_tree()),"The barbecue emergency starts after the intro hands over control")
	game.travel.start(true)
	game.travel._update_transition(3)
	var race: ToyRaceTrack=game.travel.race
	var floating:=race.find_children("*","Label3D",true,false).filter(func(label): return label.billboard!=BaseMaterial3D.BILLBOARD_DISABLED)
	check(floating.is_empty(),"The race scene has no floating shop, exit, mission or arch labels")
	var bunting: Array=game.travel.assembly.filter(func(item): return not item.gpu and item.node.get_meta("toy_kind","")=="Bunting")
	# A bunting line is merged into the static batch; its UV2 pivot and kind
	# make every flag and pole use the same drop timing, not the flat-paint path.
	var flags_timed:=true
	var flag_vertices:=0
	for mesh in race.get_node("ToyBuildings").find_children("*","MeshInstance3D",true,false):
		if not mesh.get_meta("assembly_vertices",false): continue
		var arrays: Array=mesh.mesh.surface_get_arrays(0)
		var pivots: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
		var colours: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in pivots.size():
			if pivots[i].distance_to(Vector2(-30,-61))<.01 or pivots[i].distance_to(Vector2(65,33))<.01:
				flag_vertices+=1
				flags_timed=flags_timed and roundi(colours[i].a*4)==3
	check(flag_vertices>0 and flags_timed and bunting.all(func(item): return item.drop and not item.node.visible),"Flag strings arrive as whole toys instead of appearing as early flat surfaces")
	game.travel.finish()
	await frames(3)
	var types: Dictionary={}
	for prop in race.props:
		types[prop.kind]=true
		check(prop.spawn_shape!=null and prop.get_parent()==race,"Race prop uses the shared body, sweep and respawn setup: "+prop.kind)
	check(types.has_all(["tree","camper","parked_racer","flower_pot","picnic_table","tent","traffic_cone","tire_stack","race_grill","hydrant"]),"Both small scenery and substantial paddock toys are breakable")
	var racer: BreakableProp=race.props.filter(func(prop): return prop.kind=="parked_racer")[0]
	var tires:=racer.find_children("*","MeshInstance3D",true,false).filter(func(mesh): return mesh.mesh is CylinderMesh)
	check(tires.size()==4 and tires.all(func(tire): return absf(tire.basis.y.dot(Vector3.BACK))>.99),"Parked racer wheel axles point across the car's width")
	var prop: BreakableProp=race.props.filter(func(item): return item.kind=="flower_pot")[0]
	prop.respawn_seconds=1.3
	var home:=prop.global_transform
	check(prop.knock(Vector3(10,0,0)),"A race prop releases from its anchor on impact")
	await frames(12)
	check(not prop.freeze and prop.global_position.distance_to(home.origin)>.25,"Race prop movement is real rigid-body physics")
	race.deactivate()
	var away:=prop.global_transform
	await frames(12)
	check(prop.freeze and prop.global_transform.is_equal_approx(away),"Loose race props stop simulating when their world is suspended")
	race.activate()
	await frames(110)
	check(not prop.loose and prop.freeze and prop.global_transform.is_equal_approx(home),"Race props safely return to their authored pose after respawn")
	race.running=false
	race._physics_process(.2)
	check(not race.timer_label.visible,"Idle racing has no start instruction or best-time HUD")
	game.truck.global_position=ToyRaceTrack.ORIGIN+RaceCourse.gate_position(0)+Vector3(3,.85,0)
	race.previous=Vector2(3,-54)
	race.running=true
	race.lap_time=2.5
	race._physics_process(.2)
	check(race.timer_label.text.begins_with("LAP") and not race.timer_label.text.contains("gates") and not race.timer_label.text.contains("BEST"),"The race HUD shows only lap time")
	var distinct_times: Dictionary={}
	for i in 6:
		race._physics_process(1.0/60)
		distinct_times[race.timer_label.text]=true
	check(distinct_times.size()==6,"The live hundredths clock advances on all six race ticks within a tenth of a second")
	var road: MeshInstance3D=race.get_node("RibbonRoadAndBridge")
	var faces:=road.mesh.get_faces()
	var unfolded:=true
	for i in range(0,faces.size(),3): unfolded=unfolded and (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).y<0
	check(unfolded,"All asphalt faces remain correctly wound through the rounded bridge approaches")
	var steepest:=0.0
	var path:=RaceCourse.points()
	for i in path.size()-1:
		var segment:=path[i+1]-path[i]
		steepest=maxf(steepest,absf(segment.y)/maxf(.001,Vector2(segment.x,segment.z).length()))
	check(steepest<.26,"Both bridge slopes stay below a gentle fifteen-degree grade")
	check(race.gates[3].position.is_equal_approx(RaceCourse.gate_position(3)+Vector3.UP*.055) and race.has_node("ContinuousBridgeDeck"),"The elevated arch is aligned to a continuous supporting bridge deck")
	game.queue_free()
	await process_frame
	await process_frame
	print("SCENE DETAILS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
