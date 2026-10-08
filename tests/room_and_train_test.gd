extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.travel.set_process(false)
	var r_key:=InputEventKey.new()
	r_key.physical_keycode=KEY_R
	r_key.pressed=true
	var bound:=false
	for action in InputMap.get_actions(): bound=bound or InputMap.event_is_action(r_key,action)
	check(not bound,"R has no gameplay input binding")
	check(SpeechFrame.PHONE.get_width()>=256,"The phone handset has a high-resolution antialiased texture")
	game.intro.start()
	var camera_from: Vector3=game.camera.position
	game.intro.update(.1)
	check(game.camera.position.distance_to(camera_from)>.5,"The room camera begins moving immediately")
	check(game.playroom.find_child("StarryWallpaper",true,false)!=null,"The room has star wallpaper behind the drawers")
	check(game.playroom.find_child("WestStarryWallpaper",true,false)!=null,"The room also has a matching west wall")
	check(game.travel.mat.finish.get_shader_parameter("roll")<.9 and game.travel.mat.get_child_count()==0,"The continuous sheet begins its throw immediately, with no cylinder stand-in")
	game.intro.update(2.1)
	check(game.travel.mat.finish.get_shader_parameter("roll")==0.0,"The opening mat finishes unfolding in just over two seconds")
	game.intro.update(1.7)
	check(game.intro.title.reveal==0,"Maple Bay's handwriting waits two additional seconds")
	game.intro.update(.3)
	check(game.intro.title.reveal>0,"The town name begins writing after four seconds")
	for is_race in [false,true]:
		var start:=PlayMatTravel.fly_in_start(is_race)
		game.travel.assembly_camera(start-.001,is_race)
		var before: Transform3D=game.camera.global_transform
		game.travel.assembly_camera(start+.001,is_race)
		check(before.origin.distance_to(game.camera.position)<.3,"Fly-in joins the moving rollout without a camera cut")
		game.travel.assembly_camera(start+.25,is_race)
		check(game.camera.size<180,"Both fly-ins begin before the last half-second of unfolding is finished")
	game.travel.assembly_camera(4.109,false)
	check(game.camera.size<55,"Maple Bay reaches its first close-up without a pause on the flat carpet")
	game.travel.assembly_camera(3.061,true)
	check(game.camera.size<55,"Motorway also reaches the start gate sooner")
	var first_house_end:=6.25
	check(first_house_end-(PlayMatTravel.fly_in_start(false)+3.8/1.5)<2.15,"The first cottage's close view lasts half as long")
	game.travel.grow_assembly(PlayMatTravel.arrival_progress(first_house_end))
	var featured: Array=game.travel.assembly.filter(func(item): return not item.gpu and (item.node is BreakableProp and item.node.kind=="tree" or item.node in game.town.people) and item.transform.origin.distance_to(PlayMatTravel.first_house(false))<25)
	check(not featured.is_empty() and featured.all(func(item): return item.settled),"The first trees and neighbour finish landing before the camera leaves them")
	game.intro.finish()
	game.travel.start(true)
	check(not game.travel.outgoing_mat.finish.get_shader_parameter("unfolding"),"Rolling the outgoing mat uses the flat gathering motion")
	check(not game.travel.short_transition and game.travel.duration==26,"The first race visit keeps the introduction")
	game.travel._update_transition(1.999)
	var room_before: Vector2=game.camera.unproject_position(Vector3(-124,33,-115))
	game.travel._update_transition(.002)
	check(room_before.distance_to(game.camera.unproject_position(ToyRaceTrack.ORIGIN+Vector3(-124,33,-115)))<.01,"Both rooms preserve the same screen composition across the world swap")
	check(game.travel.race.get_node("RacePlayroomFloor").material_override.get_shader_parameter("floor_origin")==Vector2(400,0),"The destination floor grain uses the same room coordinates")
	game.travel._update_transition(5.9-game.travel.clock)
	check(game.travel.title.reveal==0,"The club name also waits until four seconds into its incoming intro")
	check(game.travel.mat.finish.get_shader_parameter("unfolding"),"The incoming mat uses the held-edge shake-out motion")
	game.travel._update_transition(6.1)
	check(game.travel.title.visible and game.travel.title.reveal>0 and game.travel.title.is_race_title and TownTitle.RACE_NAME=="Motorway Race Club","Motorway Race Club is written with the same pen-stroke title")
	game.travel._update_transition(23-game.travel.clock)
	check(game.travel.mat.material_override==game.travel.mat.print_fade and game.travel.mat.print_fade.get_shader_parameter("print_opacity")>0 and game.travel.mat.print_fade.get_shader_parameter("print_opacity")<1,"The flat print fades gradually before the truck entry")
	game.travel._update_transition(25.999-game.travel.clock)
	var truck_before: Vector2=game.camera.unproject_position(game.truck.global_position)
	game.travel.finish()
	check(truck_before.distance_to(game.camera.unproject_position(game.truck.global_position))<.1 and game.camera_trauma==0,"The Motorway handover preserves the truck's screen position without residual impact shake")
	check(game.hud.toast_label.text.is_empty(),"Entering the club shows no numbered-arch instruction toast")
	check(not game.town.visible and game.travel.race.active,"Skipping the first visit hides the outgoing town as well as restoring controls")
	var race: ToyRaceTrack=game.travel.race
	var entrance: MeshInstance3D=race.get_node("EntranceRoadInsideHem")
	check((entrance.transform*entrance.get_aabb()).position.z>=-77.5,"The Motorway entrance asphalt stops inside the orange carpet binding")
	var duck_from: Vector3=race.ducks[0].position
	await frames(40)
	check(race.ducks[0].position.distance_to(duck_from)>.2,"The pond's ducks swim rather than remaining fixed")
	var piers:=race.get_children().filter(func(n): return str(n.name).begins_with("NorthBridgePier"))
	check(piers.size()==2 and piers.all(func(n): return n.position.z< -5),"Bridge supports sit north of the crossing")
	var loose: BreakableProp=race.props.filter(func(p): return p.kind=="parked_racer")[0]
	loose.knock(Vector3(8,0,0))
	await frames(6)
	var pose:=loose.global_transform
	game.travel.start(false)
	check(game.travel.assembly.is_empty() and game.travel.toys_hidden and (game.camera.cull_mask&PlayMatTravel.WORLD_TOYS)==0 and (game.sun.shadow_caster_mask&PlayMatTravel.WORLD_TOYS)==0,"Repeat travel hides toys and their shadows without rebuilding their transforms")
	check(game.travel.short_transition and game.travel.duration==4.2 and not race.mat.visible,"A return visit rolls away the complete mat in 4.2 seconds")
	game.travel._update_transition(1.65)
	check(not race.mat.visible and game.travel.outgoing_mat.position.y>20 and game.travel.outgoing_mat.position.x<ToyRaceTrack.ORIGIN.x and game.travel.mat.visible,"The old roll lifts away while the new mat arrives without a remaining flat layer")
	game.travel._update_transition(2.6)
	check(not game.travel.active and not game.travel.in_race and game.truck.enabled,"The short return gives control back in Maple Bay")
	check(not game.travel.toys_hidden and (game.camera.cull_mask&PlayMatTravel.MAPLE_TOYS)!=0 and (game.sun.shadow_caster_mask&PlayMatTravel.MAPLE_TOYS)!=0,"Returning restores the original toy rendering and shadow masks")
	game.travel.start(true)
	check(game.travel.short_transition and game.travel.duration==4.2,"Later race visits also use the short mat swap")
	game.travel._update_transition(4.25)
	check(loose.global_transform.is_equal_approx(pose) and loose.loose,"A short visit preserves the moved toys rather than rebuilding their positions")
	game.travel.start(false)
	game.travel.finish()
	var rail: NorthlineRailway=game.railway
	rail._start_engine()
	rail._physics_process(.6)
	check(rail.roof_hinge.rotation.z>1.7 and rail.driver.visible and not rail.boarded,"The roof hinges open while the conductor visibly boards")
	rail._physics_process(.5)
	check(rail.driver.position.y>3.5,"The conductor jumps above the cab opening")
	rail._physics_process(1.25)
	check(rail.boarded and rail.driver.get_parent()==rail.engine and rail.driver.visible and rail.roof_hinge.rotation.z==0,"The roof closes and the visible conductor rides with the locomotive")
	check(rail.engine.has_node("CabFootwell") and rail.driver.position.distance_to(NorthlineRailway.CAB_STANDING_POSE)<.01 and -rail.driver.global_basis.z.dot(rail.engine.global_basis.x)>.98,"The conductor stands inside the deep cab and faces the locomotive's front")
	var right: Node3D=rail.driver.get_node("ArmRight")
	check((rail.engine.global_transform.affine_inverse()*(right.global_transform*Vector3(0,-.62,0))).z>1.28,"One hand hangs outside the open side window")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
