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
	game.intro.start()
	var camera_from: Vector3=game.camera.position
	game.intro.update(.1)
	check(game.camera.position.distance_to(camera_from)>.5,"The room camera begins moving immediately")
	check(game.playroom.find_child("StarryWallpaper",true,false)!=null,"The room has star wallpaper behind the drawers")
	check(game.travel.mat.finish.get_shader_parameter("roll")>.99 and game.travel.mat.get_child_count()==0,"The opening roll is the continuous carpet sheet, with no cylinder stand-in")
	game.intro.finish()
	game.travel.start(true)
	check(not game.travel.short_transition and game.travel.duration==26,"The first race visit keeps the introduction")
	game.travel._update_transition(12)
	check(game.travel.title.visible and game.travel.title.reveal>0 and game.travel.title.is_race_title,"Maple Motor Park is written with the same pen-stroke title")
	game.travel.finish()
	check(not game.town.visible and game.travel.race.active,"Skipping the first visit hides the outgoing town as well as restoring controls")
	var race: ToyRaceTrack=game.travel.race
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
	check(game.travel.short_transition and game.travel.duration==2.8 and not race.mat.visible,"A return visit rolls away the complete mat in 2.8 seconds")
	game.travel._update_transition(1.2)
	check(not race.mat.visible and game.travel.mat.position.x>ToyRaceTrack.ORIGIN.x,"The rolled mat is placed to the side with no flat carpet left beneath it")
	game.travel._update_transition(1.65)
	check(not game.travel.active and not game.travel.in_race and game.truck.enabled,"The short return gives control back in Maple Bay")
	game.travel.start(true)
	check(game.travel.short_transition and game.travel.duration==2.8,"Later race visits also use the short mat swap")
	game.travel._update_transition(2.85)
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
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
