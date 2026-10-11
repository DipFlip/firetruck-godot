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
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.set_process(false)
	game.life.set_physics_process(false)
	game.travel.set_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	var race: ToyRaceTrack=game.travel.race
	check(game.maple_fire is ToyFire and race.grill_fire is ToyFire and game.town.flames==game.maple_fire.flames,"Both grill fires use the same component, preserving Maple's authored flames")
	for is_race in [false,true]:
		if is_race:
			game.travel.start(true)
			check(not game.maple_fire.visible and not race.grill_fire.visible,"Town transitions hide every fire until control returns")
			game.travel.finish()
			race.set_process(false)
			race.set_physics_process(false)
		var fire: ToyFire=race.grill_fire if is_race else game.maple_fire
		game.truck.global_position=fire.global_position+Vector3(0,.85,8)
		var target: Vector3=fire.global_position+Vector3.UP*1.8
		var before: float=game.sounds.counts.get("fire_sizzle",0)
		game._water_hit(target,fire.water_required*.25)
		await frames(12)
		check(absf(fire.progress-.25)<.001 and absf(fire.intensity-.75)<.001 and not fire.steam.is_empty(),"Water shrinks the "+("Motorway" if is_race else "Maple")+" fire and creates pooled white steam")
		check(game.sounds.counts.get("fire_sizzle",0)>before and game.sounds.loops.fire_sizzle.global_position.distance_to(fire.global_position+Vector3.UP*1.6)<.01,"Cooling hiss plays at the actual fire's position")
		game.paused=true
		var paused_time:=fire.time
		var feedback:=fire.feedback
		await frames(5)
		check(fire.time==paused_time and fire.feedback==feedback,"The shared fire pauses flames, steam and cooling feedback")
		game.paused=false
		game._water_hit(target,fire.water_required*.75)
		await frames(2)
		check(fire.progress==1 and fire.flames.all(func(flame): return not flame.visible) and not fire.steam.is_empty(),"Extinguishing removes flames but lets the final steam fade naturally")
		await frames(120)
		check(fire.steam.is_empty() and not game.sounds.loop_active.fire_sizzle,"Both fire steam and hiss stop after water contact ends")
	check(race.jobs[1].done and game.fire_progress==1,"Each level retains its own mission completion while using shared fire response")
	var small:=ToyFire.new()
	small.game=game
	small.water_required=.5
	game.add_child(small)
	small.global_position=game.truck.global_position
	check(small.apply_water(.25) and small.progress==.5,"A newly placed fire can use a different water requirement without level-specific code")
	small.queue_free()
	# The tent uses the same real rigid-body physics as all other loose props.
	var tent: BreakableProp=race.props.filter(func(prop): return prop.kind=="tent")[0]
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(0,.85,-70)
	tent.global_transform=Transform3D(Basis.IDENTITY,ToyRaceTrack.ORIGIN+Vector3(74,0,68))
	tent.home=tent.global_transform
	tent.reset_physics_interpolation()
	check(tent.knock(Vector3.RIGHT*16),"A real tent can be pushed toward the outer blocks")
	var farthest:=0.0
	for i in 150:
		await frames(1)
		farthest=maxf(farthest,tent.global_position.x-ToyRaceTrack.ORIGIN.x)
	check(farthest<78 and tent.linear_velocity.x<2,"The loose tent collides with the Motorway perimeter instead of passing through it: x "+str(farthest))
	var props: Array[BreakableProp]=game.interactions.props.duplicate()
	props.append_array(race.props)
	check(props.all(func(prop): return prop.collision_mask==0 or (prop.collision_mask&Playroom.WALL_LAYER)!=0),"Anchored, loose and returning props on both maps include the perimeter collision layer")
	var cones: Array=race.props.filter(func(prop): return prop.kind=="traffic_cone")
	check(cones.size()==14,"Four existing cones and ten new cones share one striped model")
	var clear:=true
	for cone in cones.slice(4):
		var at: Vector3=cone.home.origin-ToyRaceTrack.ORIGIN
		var distance:=RaceCourse.distance_to_track(Vector2(at.x,at.z))
		print("Cone at ",at," / track clearance ",distance)
		clear=clear and distance>RaceCourse.HALF_WIDTH+1 and absf(at.x)<77 and absf(at.z)<77 and ((Vector2(at.x,at.z)-RaceCourse.POND_CENTRE)/RaceCourse.POND_RADIUS).length()>1
	check(clear,"The added cones mark bends from clear grass outside the driving ribbon and pond")
	var wind_flags: Array=race.find_children("WindFlags","MultiMeshInstance3D",true,false)
	check(wind_flags.size()==2 and wind_flags.all(func(flags): return flags.multimesh.instance_count==13 and flags.multimesh.use_custom_data and flags.material_override.shader.resource_path=="res://shaders/bunting.gdshader"),"Twenty-six wind-animated flags use only two instanced draw batches")
	check(wind_flags.all(func(flags): return flags.get_parent().get_child_count()==41),"Every flag has two visible ties attached to the sagging support cord")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
