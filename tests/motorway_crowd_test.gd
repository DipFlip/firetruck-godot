extends SceneTree
# Compatibility retains the baked vertex data used by the browser intro.
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func visible_skin(actor: Node3D, skin: Color) -> bool:
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.layers==0: continue
		var colours: PackedColorArray=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for colour in colours:
			if Vector3(colour.r,colour.g,colour.b).distance_to(Vector3(skin.r,skin.g,skin.b))<.001: return true
	return false
func foot(actor: Node3D) -> Vector3:
	var leg: Node3D=actor.get_node("LegLeft")
	for mesh in leg.find_children("*","MeshInstance3D",true,false):
		if mesh.layers!=0: return actor.to_local(mesh.global_transform*mesh.mesh.get_aabb().get_center())
	return Vector3.INF
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.call_timer=0
	var race: ToyRaceTrack=game.travel.race
	var actors: Array[Node3D]=[]
	actors.append_array(race.people)
	actors.append_array(race.spectators)
	for walker in race.walkers: actors.append(walker.actor)
	var tones: Dictionary={}
	var skin_in_batches:=true
	for actor in actors:
		var skin: Color=actor.get_node("Head").get_active_material(0).albedo_color
		tones[skin.to_html(false)]=true
		skin_in_batches=skin_in_batches and visible_skin(actor,skin)
	check(tones.size()>=6 and skin_in_batches,"Light through deep skin tones appear in the rendered Motorway crowd, including baked bodies")
	for centre in [Vector3(73,0,-22),Vector3(-71,0,42)]:
		var stand_tones: Dictionary={}
		for actor in race.spectators:
			if Vector2(actor.position.x-centre.x,actor.position.z-centre.z).length()<12:
				stand_tones[actor.get_node("Head").get_active_material(0).albedo_color.to_html(false)]=true
		check(stand_tones.size()>=5,"Each audience stand contains a varied crowd")
	game.intro.finish()
	game.travel.start(true)
	game.travel._swap_world()
	var travel: PlayMatTravel=game.travel
	var east:=0
	var food:=0
	var timely:=true
	var pivots: Dictionary={}
	for item in travel.assembly:
		if item.gpu:
			var arrays: Array=item.node.mesh.surface_get_arrays(0)
			var coordinates: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
			var colours: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			for i in coordinates.size():
				var kind:=roundi(colours[i].a*4)
				var at:=Vector3(coordinates[i].x,0,coordinates[i].y)
				var key:=Vector3i(roundi(at.x*8),kind,roundi(at.z*8))
				if kind==1 or pivots.has(key): continue
				pivots[key]=true
				var end:=PlayMatTravel.RACE_ARRIVAL_START+(PlayMatTravel.arrival_delay(at,kind,true)+PlayMatTravel.arrival_span(at,kind,true))*(PlayMatTravel.ARRIVAL_END-PlayMatTravel.RACE_ARRIVAL_START)
				if Vector2(at.x-73,at.z+22).length()<12:
					east+=1
					timely=timely and end<=9.15
				if PlayMatTravel.race_food_court(at):
					food+=1
					timely=timely and end<=12.2
		elif not item.flat and not item.boundary:
			var at: Vector3=item.pivot-ToyRaceTrack.ORIGIN
			var end: float=PlayMatTravel.RACE_ARRIVAL_START+(item.delay+item.span)*(PlayMatTravel.ARRIVAL_END-PlayMatTravel.RACE_ARRIVAL_START)
			if Vector2(at.x-73,at.z+22).length()<12:
				east+=1
				timely=timely and end<=9.35
			if PlayMatTravel.race_food_court(at):
				food+=1
				timely=timely and end<=12.2
	check(east>=15 and food>=10 and timely,"Eastern benches, spectators, food court and outer tables settle before the camera leaves their views")
	check(PlayMatTravel.tour_focus(8.8,true).distance_to(Vector3(73,5,-22))<4,"The race camera turns toward the eastern audience during its assembly")
	travel.assembly_camera(9.4,true)
	travel.grow_assembly(PlayMatTravel.arrival_progress(9.4,true))
	var east_people:=travel.assembly.filter(func(item): return item.node in race.spectators and Vector2(item.transform.origin.x-ToyRaceTrack.ORIGIN.x-73,item.transform.origin.z+22).length()<12)
	check(east_people.size()==9 and east_people.all(func(item): return item.settled and item.node.global_transform.is_equal_approx(item.transform)),"All nine eastern spectators have visibly landed during the pan")
	travel.assembly_camera(12.2,true)
	travel.grow_assembly(PlayMatTravel.arrival_progress(12.2,true))
	var food_toys:=travel.assembly.filter(func(item): return not item.gpu and not item.flat and not item.boundary and PlayMatTravel.race_food_court(item.pivot-ToyRaceTrack.ORIGIN))
	check(food_toys.size()>=8 and food_toys.all(func(item): return item.settled),"Patio toys and walkers are already settled during the food court view")
	travel.finish()
	race.set_process(false)
	var before: Array[Vector3]=[]
	for walker in race.walkers: before.append(foot(walker.actor))
	var motion: Array[float]=[0.0,0.0,0.0,0.0]
	var gait:=true
	for frame in 12:
		race._update_walkers(.1)
		for i in race.walkers.size():
			var actor: Node3D=race.walkers[i].actor
			gait=gait and before[i].is_finite()
			motion[i]=maxf(motion[i],before[i].distance_to(foot(actor)))
			gait=gait and absf(actor.get_node("LegLeft").rotation.x+actor.get_node("LegRight").rotation.x)<.001
			gait=gait and absf(actor.get_node("ArmLeft").rotation.x+actor.get_node("ArmRight").rotation.x)<.001
	gait=gait and motion.all(func(distance): return distance>.1)
	check(gait,"All four food court walkers swing visible feet and opposite arms rather than sliding fixed meshes")
	var walker:=race.walkers[0]
	game.truck.global_position=walker.actor.global_position+Vector3(0,.85,2)
	var stopped: Vector3=walker.actor.position
	race._update_walkers(.5)
	check(Vector2(stopped.x,stopped.z).distance_to(Vector2(walker.actor.position.x,walker.actor.position.z))<.001,"Food court walkers pause when the truck approaches")
	print("MOTORWAY CROWD: ",tones.size()," skin tones, ",east," eastern pieces, ",food," food court pieces")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
