extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func count(kind: String) -> int: return int(game.sounds.counts.get(kind,0))
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.set_process(false)
	game.travel.set_process(false)
	game.rewards.set_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	game.truck.global_position=TownLayout.FIRE+Vector3(0,.85,7)
	game.cat_rescued=true
	game._water_hit(TownLayout.FIRE+Vector3.UP*1.8,.001)
	game.hud.mission_label.text="Existing fire briefing"
	for i in 1000: game._water_hit(TownLayout.FIRE+Vector3.UP*1.8,.0001)
	check(game.stage==3 and game.hud.mission_label.text=="Existing fire briefing","Repeated fire contacts keep the existing mission UI instead of rebuilding it")
	game.truck.global_position=TownLayout.DOG+Vector3(0,.85,4)
	game.talk("JUNE","Please wash Biscuit.",game.stage)
	game.conversation_blend=1
	var washing:=count("dog_wash")
	game._water_hit(TownLayout.DOG+Vector3.UP*.7,4)
	check(game.dog_done and count("dog_wash")>washing and count("woof")>0,"Biscuit reacts to washing and barks when clean")
	check(not game.dialogue_active and game.camera_blend_to==1 and game.camera_subject==game.town.people[2],"The completion delay keeps June's close camera framing")
	game.rewards._process(2)
	check(game.dialogue_active and game.hud.speaker_key=="JUNE" and game.camera_blend_to==1,"Thank-you dialogue inherits the held camera without zooming out")
	game.end_dialogue()
	game.truck.extend_ladder()
	game.truck.retract_ladder()
	check(count("ladder_extend")>0 and count("ladder_retract")>0,"Both ladder directions have a mechanical sound")
	game.travel.start(true)
	game.travel.finish()
	var race: ToyRaceTrack=game.travel.race
	race.set_process(false)
	race.set_physics_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	var pond:=RaceCourse.POND_CENTRE
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(pond.x,-1.5,pond.y)
	game.truck.water=10
	race._update_pond(.5)
	check(game.truck.water==20 and not game.truck.splashes.is_empty(),"Immersing the truck refills the tank and creates pooled water splashes")
	var duck:=race.ducks[0]
	duck.position=Vector3(pond.x+3,-.27,pond.y)
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(pond.x,-.5,pond.y)
	for i in 20:
		race.animation_clock+=.05
		race._update_ducks(.05)
	check(duck.position.x>pond.x+4 and count("quack")>0,"An approaching truck makes a duck swim away and quack")
	var audience:=race.spectators[0]
	game.truck.global_position=audience.global_position+Vector3(8,0,0)
	race.running=true
	race.animation_clock+=5
	race._update_audience(.01)
	race._update_audience(.15)
	check(audience.position.y>race.audience_states[0].home.y+.05 and count("cheer")>0,"A passing racer triggers audience jumping, waving, and a pooled cheer")
	for pair in [["traffic_cone","plastic"],["tent","cloth"],["flower_pot","ceramic"]]:
		game.sounds.last.erase(pair[1])
		game.sounds.prop_impact(pair[0],game.truck.global_position,8)
		check(count(pair[1])>0,pair[0]+" uses its own material sound")
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(78,.85,60)
	game.sounds.truck_velocity=Vector3.RIGHT*10
	var wood:=count("wood")
	game.sounds.last.erase("wood")
	game.sounds._truck_contact(get_nodes_in_group("wooden_boundary").filter(func(n): return race.is_ancestor_of(n))[0])
	check(count("wood")>wood,"Motorway perimeter contact plays a wooden impact at the contact area")
	var kit:=race.people[0]
	check((-kit.basis.z).dot((ToyRaceTrack.SPAWN-kit.position).normalized())>.95,"Kit faces the arrival street")
	check(race.gates.all(func(g): return g.find_children("*","Label3D",true,false).is_empty()),"Race arches have no printed numbers")
	game.truck.arrival_pose(ToyRaceTrack.ORIGIN+ToyRaceTrack.SPAWN,PI,-2,.1)
	var high: float=game.truck.global_position.y
	game.truck.arrival_pose(ToyRaceTrack.ORIGIN+ToyRaceTrack.SPAWN,PI,-5,.7)
	check(high>3 and game.truck.global_position.y<1.1 and absf(game.truck.wheels[0].rotation.x)>5,"The entering truck drops onto the mat with rotating wheels")
	var rail: NorthlineRailway=game.railway
	rail.engine.linear_velocity=Vector3.RIGHT*3
	rail._physics_process(.1)
	var rod_y: float=rail.wheel_rods[0].position.y
	rail._physics_process(.1)
	check(absf(rail.wheel_rods[0].position.y-rod_y)>.03,"Train connecting rods follow the wheel crank vertically")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
