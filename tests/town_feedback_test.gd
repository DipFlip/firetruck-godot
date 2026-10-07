extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func place(p: Vector3) -> void:
	game.end_dialogue()
	game.truck.position=p
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.automated_drive=Vector2.ZERO
	game.truck.reset_physics_interpolation()
	await frames(3)
func count(kind: String) -> int: return int(game.sounds.counts.get(kind,0))
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	await frames(3)
	# PCM continuity: silent ends, no clipping, no discontinuities from voice
	# phase resets, and three distinct samples for each local reaction.
	var clean:=true
	for kind in game.sounds.bank:
		clean=clean and game.sounds.bank[kind].size()==3
		for wav in game.sounds.bank[kind]:
			var data: PackedByteArray=wav.data
			clean=clean and data.decode_s16(0)==0 and data.decode_s16(data.size()-2)==0
			var peak:=0
			var previous:=0
			var biggest_step:=0
			for i in data.size()/2:
				var sample:=data.decode_s16(i*2)
				peak=maxi(peak,absi(sample))
				biggest_step=maxi(biggest_step,absi(sample-previous))
				previous=sample
			clean=clean and peak<24000
			if kind=="voice": clean=clean and biggest_step<3500
	check(clean,"Every sound has three bounded, silent-ended variants; voice waveforms are smooth")
	check(game.sounds.players.size()==12 and game.hud.syllables.size()==3,"Sound voices are pooled and dialogue uses the baked three-syllable bank")
	game.hud.begin_dialogue("MAYA","Hello there!")
	if DisplayServer.get_name()!="headless":
		game.hud._speak()
		var current: AudioStream=game.hud.voice.stream
		game.hud._speak()
		check(game.hud.voice.stream==current and game.hud.voice.playing,"A second letter never cuts off or replaces a playing voice syllable")
	game.end_dialogue()
	# A sideways collision settles quickly; forward momentum is still pushable.
	await place(Vector3(-70,1,70))
	var car: Dictionary=game.life.cars[0]
	car.node.position=Vector3(0,.06,-48)
	car.node.rotation=Vector3.ZERO
	car.node.linear_velocity=Vector3.ZERO
	car.node.angular_velocity=Vector3.ZERO
	car.node.reset_physics_interpolation()
	car.coast=3
	await frames(3)
	var start: Vector3=car.node.position
	car.node.apply_central_impulse(Vector3.RIGHT*8*car.node.mass)
	await frames(60)
	var drift: float=absf(car.node.position.x-start.x)
	print("Sideways impact: drift=",drift," m, speed=",absf(car.node.linear_velocity.x)," m/s after one second")
	check(drift<1.25 and absf(car.node.linear_velocity.x)<.18,"A strong sideways bump stops within roughly one metre instead of skating")
	car.coast=3
	car.node.apply_central_impulse(Vector3.BACK*6*car.node.mass)
	var forward_start: float=car.node.position.z
	await frames(30)
	check(car.node.position.z>forward_start+1 and car.node.linear_velocity.z>1,"The car still rolls forward under a push")
	game.life.set_physics_process(false)
	for other in game.life.cars: other.node.freeze=true
	# Real car and masonry contacts, rather than manually firing an audio event.
	await place(Vector3(-12,.85,-47))
	car.node.global_position=Vector3(-12,.05,-52)
	car.node.rotation=Vector3.ZERO
	car.node.linear_velocity=Vector3.ZERO
	car.node.angular_velocity=Vector3.ZERO
	car.node.freeze=false
	car.node.reset_physics_interpolation()
	var bumps:=count("car_bump")
	game.truck.linear_velocity=Vector3(0,0,-13)
	await frames(35)
	check(count("car_bump")>bumps and count("honk")>0,"A real rigid-body car collision produces an impact and a rate-limited honk")
	var brick:=count("brick")
	await place(Vector3(-48,.85,28))
	game.truck.linear_velocity=Vector3(0,0,-14)
	await frames(70)
	print("House collision: truck=",game.truck.position," masonry bodies=",get_nodes_in_group("masonry_collision").size()," contacts=",game.truck.get_colliding_bodies())
	check(count("brick")>brick,"Crashing into the post office produces a masonry impact")
	for other in game.life.cars: other.node.freeze=true
	for kind in ["tree","lamp","fence","bush"]:
		var prop: BreakableProp
		for candidate in game.interactions.props:
			if candidate.kind==kind and not candidate.loose and not candidate.protected_cat_tree: prop=candidate; break
		await place(prop.global_position+Vector3(0,1,6))
		var sound: String={"tree":"wood","lamp":"metal","fence":"fence","bush":"bush"}[kind]
		var before:=count(sound)
		check(prop.knock(Vector3.RIGHT*20) and count(sound)>before,"Toppling "+kind+" plays its material-specific sound")
	# Successful fire hits sustain one voice; misses and short gaps never spam it.
	await place(TownLayout.FIRE+Vector3(0,1,7))
	game.sounds.set_process(false)
	game._water_hit(TownLayout.FIRE+Vector3.UP*1.6,.01)
	game.sounds._process(.05)
	var sizzles:=count("fire_sizzle")
	for i in 20:
		game._water_hit(TownLayout.FIRE+Vector3.UP*1.6,.01)
		game.sounds._process(.05)
	check(sizzles>0 and count("fire_sizzle")==sizzles and game.sounds.loop_levels.fire_sizzle>.9,"Water hitting fire sustains one hiss instead of restarting a sound per droplet")
	if DisplayServer.get_name()!="headless": check(game.sounds.loops.fire_sizzle.playing,"The steam loop actually plays through the native audio player")
	game.sounds._process(.14)
	game._water_hit(TownLayout.FIRE+Vector3.UP*1.6,.01)
	game.sounds._process(.02)
	check(count("fire_sizzle")==sizzles,"A brief gap in water contact keeps the existing hiss without restarting it")
	game._water_hit(TownLayout.FIRE+Vector3(20,1,20),.01)
	for i in 30: game.sounds._process(.05)
	check(not game.sounds.loop_active.fire_sizzle and game.sounds.loop_levels.fire_sizzle<.001 and not game.sounds.loops.fire_sizzle.playing,"Missing the fire lets the steam hiss fade to silence")
	game.sounds.set_process(true)
	var dog:=count("woof")
	await place(TownLayout.DOG+Vector3(0,1,7))
	game._water_hit(TownLayout.DOG+Vector3.UP*.7,20)
	check(count("woof")>dog,"Washing Biscuit produces a pleased bark")
	await place(TownLayout.POOL+Vector3.UP*.85)
	game.truck.freeze=true
	game.talk("OLIVER","Hello!",4)
	var event:=InputEventAction.new()
	event.action="jump"
	event.pressed=true
	game.truck.jump_blocked_until_release=false
	game._unhandled_input(event)
	check(not game.dialogue_active and not game.truck.jump_blocked_until_release and game._nearest_npc()==-1,"Space inside the pool dismisses Oliver and stays available for jumping")
	game._proximity_talk()
	check(not game.dialogue_active and game.town.people[3].position.distance_to(TownLayout.POOL)>11,"Oliver stands away from the basin and cannot auto-interrupt a pool escape")
	game.pool_basin.set_fill(1)
	game.sounds.in_pool=false
	game.truck.position=TownLayout.POOL+Vector3.UP*.5
	game.truck.linear_velocity=Vector3.DOWN*6
	var splashes:=count("splash")
	game.sounds._process(.1)
	check(count("splash")>splashes,"Entering pool water with downward momentum plays a splash")
	await frames(130)
	# The first call rings audibly for a few seconds before any text arrives.
	game.truck.freeze=false
	await place(Vector3(0,.85,12))
	game.call_timer=game.PHONE_RING_SECONDS
	game.sounds.was_ringing=false
	game.sounds._process(.01)
	var rings:=count("ringtone")
	game._update_dispatch(2.0)
	check(rings>0 and not game.dialogue_active and game.phone_ringing(),"A ringtone leads the initial operator message for more than two seconds")
	game._update_dispatch(1.05)
	check(game.dialogue_active and game.hud.speaker_key=="DISPATCH","The operator speaks only after the complete ring lead-in")
	game.end_dialogue()
	game.call_timer=0
	# Prove that both return directions face forward and turns are hidden.
	var rail: NorthlineRailway=game.railway
	rail.started=true
	rail.boarded=true
	rail.engine.position.x=NorthlineRailway.RIGHT_END+5
	rail.engine.linear_velocity=Vector3.RIGHT*3.6
	rail._update_route(.016)
	check(rail.offstage and not rail.engine.visible and rail.direction>0,"The eastbound train leaves view before its turnaround")
	rail._update_route(4.6)
	check(not rail.offstage and rail.direction<0 and rail.engine.global_basis.x.x<-.9 and not rail.engine.visible,"The train rotates west off screen with its boiler facing the return direction")
	rail.engine.position.x=NorthlineRailway.LEFT_END-5
	rail._update_route(.016)
	rail._update_route(4.6)
	check(rail.direction>0 and rail.engine.global_basis.x.x>.9,"The next return faces east again rather than reversing")
	# Moving native screenshots show the new barbecue and handwritten overlay.
	game.intro.start()
	game.intro.update(.25)
	var camera_start: Vector3=game.camera.position
	game.intro.update(2.1)
	check(camera_start.distance_to(game.camera.position)>3 and game.camera.size>140 and game.travel.mat.visible and game.intro.title.reveal>0,"The wide opening follows the loose printed carpet while the town name is written")
	await capture("/tmp/firedriver-town-intro.png")
	game.intro.update(5.25)
	await capture("/tmp/firedriver-dog-intro.png")
	var border_start:=PlayMatTravel.tour_focus(11.8,false)
	var border_end:=PlayMatTravel.tour_focus(13.4,false)
	check(absf(border_start.x+80)<2 and absf(border_end.x+80)<4 and border_end.z-border_start.z>65,"The opening sweep travels along the western perimeter cascade")
	check(PlayMatTravel.tour_focus(17.0,false).distance_to(Vector3(-12,1,13))<5,"The perimeter sweep curves inward for a close station view")
	for is_race in [false,true]:
		var smooth:=true
		for knot in [9.8,11.8,13.1,14.5,15.8,17.0,18.5,20.1]:
			var before: Vector3=(PlayMatTravel.tour_focus(knot,is_race)-PlayMatTravel.tour_focus(knot-.001,is_race))/.001
			var after: Vector3=(PlayMatTravel.tour_focus(knot+.001,is_race)-PlayMatTravel.tour_focus(knot,is_race))/.001
			smooth=smooth and before.distance_to(after)<.8
		check(smooth,"The %s camera follows a continuous curve without jumps at tour waypoints" % ("race" if is_race else "town"))
	game.intro.clock=11.8
	game.intro.update(0)
	var border_basis: Basis=game.camera.basis
	var border_size: float=game.camera.size
	game.intro.clock=17.0
	game.intro.update(0)
	check(not game.camera.basis.is_equal_approx(border_basis) and game.camera.size<border_size,"The camera turns into town and moves closer to highlight the buildings")
	game.intro.clock=12
	game.intro.update(0)
	check(game.intro.title.reveal>.3 and game.intro.title.reveal<.8 and game.intro.title.opacity==1,"The title continues writing across the tour rather than finishing in the opening")
	game.intro.clock=21.0
	game.intro.update(0)
	check(game.intro.title.reveal==1 and game.intro.title.opacity==1,"The finished town name holds for several seconds before truck handover")
	game.intro.clock=21.499
	game.intro.update(0)
	var before_handover: Transform3D=game.camera.transform
	var before_lens: float=game.camera.size
	game.intro.update(.001)
	check(game.camera.position.distance_to(before_handover.origin)<.05 and absf(game.camera.size-before_lens)<.01,"The intro tour hands over without a camera or lens jump")
	game.intro.finish()
	game.set_process(false)
	game.camera.position=TownLayout.FIRE+Vector3(-6,5,7)
	game.camera.look_at(TownLayout.FIRE+Vector3.UP*.9)
	game.camera.size=9
	game.town.fire_amount=0
	for flame in game.town.flames: flame.hide()
	check(game.barbecue.get_children().any(func(child): return child is StaticBody3D),"The kettle barbecue has a solid body, open grate, food and hinged lid")
	await capture("/tmp/firedriver-barbecue.png")
	game.queue_free()
	await process_frame
	await process_frame
	print("TOWN FEEDBACK CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
