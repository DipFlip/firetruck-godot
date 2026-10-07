extends SceneTree

var game: Node3D
var failures:=0
var record_backup: PackedByteArray
var had_record:=false

func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func place(local: Vector3) -> void:
	game.truck.global_position=game.truck.world_origin+local
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()

func run() -> void:
	had_record=FileAccess.file_exists(ToyRaceTrack.SAVE_PATH)
	if had_record: record_backup=FileAccess.get_file_as_bytes(ToyRaceTrack.SAVE_PATH)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.travel.set_process(false)
	var travel: PlayMatTravel=game.travel
	var race: ToyRaceTrack=travel.race
	await frames(3)
	check(not race.visible and not race.active and race.process_mode==Node.PROCESS_MODE_DISABLED,"The unloaded race mat submits no scenery or simulation work")
	var proxy:=WebWarmup.make_pool_proxy(game.town.pool_water)
	check(proxy.visible and proxy.material_override.shader==game.town.pool_water.material_override.shader and proxy.material_override.get_shader_parameter("depth")==.5,"Warmup draws the actual hidden pool's transparent shader at a visible depth")
	check(game.pool_progress==0 and not game.town.pool_water.visible and game.town.pool_water.material_override.get_shader_parameter("depth")==0.0,"Warming pool water leaves the mission dry and untouched")
	proxy.free()
	for at in [1.2,5.0,8.5,19.4]:
		game.intro.start()
		game.intro.update(at)
		check(game.intro.active and (at>=5 or not travel.assembly.is_empty() and not travel.root_modes.is_empty()),"Intro unrolls the printed mat and assembles scenery with simulation suspended")
		if at==1.2:
			check(travel.assembly.any(func(item): return item.drop and item.instance>=0),"Boundary blocks participate individually in the assembly")
			check(travel.assembly.filter(func(item): return item.drop and item.instance<0).all(func(item): return not item.node.visible),"Solid border pieces are hidden while the loose mat is in the air")
		if at==8.5: check(game.camera.size<60,"The camera is close while buildings grow, rather than watching from the overview")
		game.intro.finish()
		check(travel.assembly.is_empty() and travel.root_modes.is_empty() and game.truck.enabled and not game.truck.freeze,"Skipping any intro phase restores scenery, physics and control")
	game.travel.set_process(true)
	await frames(2)
	check(travel.north_gate.collision_layer==Playroom.WALL_LAYER,"The north road stays physically closed before the stalled train is moved")
	game.railway.started=true
	await frames(115)
	check(travel.gate_opening>=.99 and travel.north_gate.collision_layer==0,"Starting Northline permanently reveals the one northbound town exit")
	game.pool_progress=.55
	game.pool_basin.set_fill(.55)
	game.dog_done=true
	var tree: BreakableProp=game.interactions.props[0]
	var tree_pose:=tree.global_transform
	place(Vector3(0,.82,-78))
	game.truck.linear_velocity=Vector3(0,0,-18)
	await frames(30)
	check(travel.active and travel.destination_race and not game.truck.enabled,"Driving through the unlocked street begins the race-track loading transition")
	travel.set_process(false)
	travel._update_transition(3)
	check(travel.in_race and travel.swapped and not travel.assembly.is_empty(),"The rolled town is exchanged for the unrolling square race mat")
	travel._update_transition(23.499-travel.clock)
	var before_entry: Vector3=game.camera.position
	var entry_lens: float=game.camera.size
	travel._update_transition(.001)
	check(game.camera.position.distance_to(before_entry)<.05 and absf(game.camera.size-entry_lens)<.01,"The race tour smoothly hands over to the entering truck")
	travel._update_transition(30)
	await frames(3)
	check(race.active and not travel.active and game.truck.enabled and game.truck.global_position.x>390 and game.truck.global_position.z< -70 and absf(game.truck.heading-PI)<.01,"The truck enters from the race mat's north edge facing inward with control restored")
	check(not game.town.visible and game.town.process_mode==Node.PROCESS_MODE_DISABLED and tree.freeze,"Maple Bay's scenery and simulation are suspended while away")
	check(game.pool_progress==.55 and game.dog_done and tree.global_transform.is_equal_approx(tree_pose),"Travel preserves partially completed missions and independent town props")
	await frames(30)
	check(game.truck.global_position.x>390,"The truck's out-of-bounds protection uses the active mat, avoiding reset loops")
	check(race.people.size()==3 and race.spectators.size()>=12 and race.walkers.size()>=4,"The paddock has named neighbours, spectators and strolling campers")
	check(absf(race.gates[0].basis.x.dot(Vector3.RIGHT))<.01,"The start arch spans across the eastbound road")
	check(not ToyRaceTrack.crosses_pose(Vector3(2,.82,6),Vector3(-2,.82,2),3),"Driving underneath Sky Bridge cannot earn its elevated checkpoint")
	place(Vector3(-17,.82,-71))
	check(game._talk_to_npc(0,true) and game.dialogue_actor==race.people[0] and game.hud.full_text.contains("Sky Bridge"),"Race neighbours use the full conversation and close camera system")
	game.end_dialogue()
	game.truck.reset_truck()
	check(game.truck.global_position.x==400,"Recovery stays in the active race paddock")
	check(not ToyRaceTrack.crosses(Vector2(3,-54),Vector2(-3,-54),0),"Reverse start-line crossings do not start a lap")
	check(ToyRaceTrack.crosses(Vector2(-8,-54),Vector2(8,-54),0),"A swept start crossing catches fast motion at low frame rates")
	check(not ToyRaceTrack.crosses(Vector2(-8,-10),Vector2(8,-10),0),"Crossing the infield cannot impersonate the start line")
	race.previous=Vector2(-2,-54)
	place(Vector3(2,.82,-54))
	race._physics_process(.016)
	check(race.running and race.checkpoint==1,"Crossing START clockwise begins a timed lap")
	game.paused=true
	var paused_time:=race.lap_time
	race._physics_process(5)
	check(race.lap_time==paused_time,"Pausing does not advance the lap clock")
	game.paused=false
	# Checkpoint order rejects an early finish and a missed east gate.
	race.previous=Vector2(-2,-54)
	place(Vector3(2,.82,-54))
	race._physics_process(.016)
	check(race.checkpoint==1 and race.last_time==0,"Returning to finish without the circuit's gates awards no record")
	place(Vector3(-25,.82,0))
	race._physics_process(.016)
	check(not race.running,"Cutting across the infield cancels the lap")
	race.previous=Vector2(-2,-54)
	place(Vector3(2,.82,-54))
	race._physics_process(.016)
	for gate in [1,2,3,0]:
		var direction:=RaceCourse.gate_direction(gate)
		race.previous=ToyRaceTrack.GATES[gate]-direction*2
		var target:=ToyRaceTrack.GATES[gate]+direction*2
		race.previous_height=RaceCourse.gate_position(gate).y+.82
		place(Vector3(target.x,race.previous_height,target.y))
		race._physics_process(4)
	check(race.last_time>15 and race.running and race.checkpoint==1,"A full clockwise circuit records a time and immediately starts another lap")
	check(race.best_time>0 and race.billboard.text.contains(ToyRaceTrack.format_time(race.best_time)),"The roadside billboard displays the best lap")
	var saved:=ConfigFile.new()
	check(saved.load(ToyRaceTrack.SAVE_PATH)==OK and saved.get_value("race","best_seconds",0.0)==race.best_time,"The personal best is persisted across game restarts")
	for job in race.jobs:
		race.water_hit(ToyRaceTrack.ORIGIN+job.point,4)
	check(race.jobs.all(func(job): return job.done) and game.pool_progress==.55,"All three optional paddock hose jobs complete without changing town missions")
	place(Vector3(-12,.82,-68))
	game.truck.water=50
	race.previous=Vector2(-12,-68)
	race.running=false
	for i in 60: race._physics_process(1.0/60)
	check(game.refill_hose.active and game.truck.water>50,"The paddock hydrant refills through the existing animated hose")
	travel.set_process(true)
	place(Vector3(0,.82,-74))
	await frames(3)
	place(Vector3(0,.82,-83))
	await frames(3)
	check(travel.active and not travel.destination_race,"The north race entrance also starts the return to Maple Bay")
	travel.set_process(false)
	travel._update_transition(30)
	await frames(3)
	check(not travel.in_race and not race.active and game.town.visible and travel.root_modes.is_empty(),"Returning restores Maple Bay and stops the race scene")
	check(game.pool_progress==.55 and game.pool_basin.progress==.55 and game.dog_done and tree.global_transform.is_equal_approx(tree_pose),"Town mission and prop state survives the complete round trip")
	check(not travel.exit_armed and game.truck.global_position.z> -76,"Arrival is latched so travel cannot immediately bounce to the other mat")
	if had_record:
		var restore:=FileAccess.open(ToyRaceTrack.SAVE_PATH,FileAccess.WRITE)
		restore.store_buffer(record_backup)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(ToyRaceTrack.SAVE_PATH))
	game.queue_free()
	await process_frame
	await process_frame
	print("MAT TRAVEL CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
