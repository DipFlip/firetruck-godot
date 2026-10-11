extends SceneTree
var game: Node3D
var failures:=0
var record_backup: PackedByteArray
var had_record:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	had_record=FileAccess.file_exists(ToyRaceTrack.SAVE_PATH)
	if had_record: record_backup=FileAccess.get_file_as_bytes(ToyRaceTrack.SAVE_PATH)
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.intro.finish()
	game.travel.start(true)
	game.travel.finish()
	game.travel.set_process(false)
	game.set_process(false)
	var race: ToyRaceTrack=game.travel.race
	var challenge: RaceChallenge=race.challenge
	var car: RaceRival=challenge.opponent
	challenge.offer()
	game.hud._resize_dialogue()
	check(challenge.offering and game.dialogue_actor==race.people[3] and challenge.choices.visible and game.truck.freeze,"Quinn offers an interrupting Yes/No choice beside the prize podium")
	check(challenge.choices.position.y>=game.hud.dialogue_label.position.y+game.hud.dialogue_label.size.y,"Challenge choices fit beneath the full speech text")
	challenge.accept()
	challenge.update(.36)
	check(challenge.staging and game.truck.freeze and car.freeze and car.collision_layer==2,"Countdown holds both racers on a physical starting grid")
	var grid: Vector3=game.truck.global_position
	await frames(20)
	check(game.truck.global_position.distance_to(grid)<.001,"Grid cannot roll or jump before GO")
	game.paused=true
	var countdown:=challenge.countdown
	challenge.update(.8)
	check(challenge.countdown==countdown,"Pause freezes the countdown")
	game.paused=false
	while challenge.staging: challenge.update(.1)
	check(challenge.active and game.truck.enabled and not game.truck.freeze and not car.freeze,"GO unlocks the player and the rigid-body rival")
	# A real broadside collision, without AI steering, must move the rival.
	var contact_origin:=car.global_position
	var right:=car.global_basis.x
	game.truck.global_position=car.global_position+right*3.8+Vector3.UP*.8
	game.truck.linear_velocity=-right*12
	game.truck.reset_physics_interpolation()
	await frames(30)
	print("CONTACT: origin=",contact_origin," car=",car.global_position," velocity=",car.linear_velocity," truck=",game.truck.global_position," freeze=",car.freeze," modes=",race.process_mode,",",challenge.process_mode)
	check(absf((car.global_position-contact_origin).dot(right))>.12,"Actual truck contact pushes the rival out of its trajectory")
	# Start afresh and obstruct the straight ahead of the rival.
	car.grid(challenge.start_distance-RaceChallenge.GRID_BACK)
	car.start_driving()
	game.truck.freeze=true
	game.truck.global_position=car.global_position-car.global_basis.z*11+Vector3.UP*.8
	await frames(24)
	print("AVOID: car=",car.global_position," player=",game.truck.global_position," lane=",car.lane," target=",car.lane_target," progress=",car.progress," driving=",car.driving)
	check(car.lane_target>0 and car.lane> -2.4,"A blocking truck makes Quinn steer toward an open passing lane")
	car.set_paused(true)
	game.paused=true
	await frames(2)
	var parked:=car.global_position
	await frames(20)
	check(car.global_position.distance_to(parked)<.001,"Pause stops the rival's physics as well as its clock")
	game.paused=false
	car.set_paused(false)
	# Complete a real uninterrupted lap through both bridge levels.
	challenge.cancel()
	challenge.offer()
	challenge.accept()
	while challenge.staging: challenge.update(.1)
	game.truck.freeze=true
	game.truck.global_position=ToyRaceTrack.ORIGIN+Vector3(-60,.85,60)
	var bridge_seen:=false
	var rival_clear:=true
	var peak_speed:=0.0
	for i in 5400:
		await physics_frame
		await process_frame
		if i%600==0: print("LAP: ",i," progress=",car.progress," pos=",car.global_position-ToyRaceTrack.ORIGIN," velocity=",car.linear_velocity," elapsed=",challenge.elapsed)
		if challenge.result_open: break
		bridge_seen=bridge_seen or car.global_position.y>6.9
		var surface:=RaceCourse.surface_at(car.global_position-ToyRaceTrack.ORIGIN+Vector3.UP*.8)
		rival_clear=rival_clear and absf(car.global_position.y-surface.height)<.3
		peak_speed=maxf(peak_speed,car.speed)
	check(challenge.result_open and challenge.rival_distance>=challenge.course_length+6,"Quinn physically drives the complete circuit and finishes without player input")
	check(bridge_seen and rival_clear,"Rival follows upper bridge and lower crossing at their proper heights")
	check(peak_speed>16.8 and RaceRival.MAX_SPEED==11.5*1.5 and RaceRival.CORNER_SPEED==8*1.5,"Straight and corner speed targets are 50% faster")
	print("RIVAL LAP: ",challenge.rival_finish," peak speed=",peak_speed," remaining position=",car.global_position-ToyRaceTrack.ORIGIN)
	check(not car.visible and car.freeze and car.collision_layer==0 and car.collision_mask==0 and car.find_children("*","StaticBody3D",true,false).is_empty(),"At the finish Quinn's hidden car has no collision and is parked below the mat")
	for i in 120:
		await frames(1)
		if challenge.awards.announced: break
	check(game.hud.full_text.begins_with("Well, better luck next time") and game.truck.global_position.distance_to(ToyRaceTrack.ORIGIN+RaceAwards.PODIUM+Vector3(0,.855,6))<.01,"Loss returns to the podium for Quinn's better-luck message")
	game.interact()
	await frames(60)
	check(not challenge.result_open and not game.truck.freeze and game.truck.enabled,"Acknowledging the result returns ordinary truck control")
	challenge.offer()
	challenge.accept()
	while challenge.staging: challenge.update(.1)
	challenge.elapsed=29.4
	challenge.finish_player()
	await frames(90)
	var awards: RaceAwards=challenge.awards
	check(awards.active and awards.won and awards.troupe.visible and awards.confetti.multimesh.instance_count==96,"Winning stages the TV crew and in-game confetti ceremony")
	check(game.truck.global_position.distance_to(ToyRaceTrack.ORIGIN+RaceAwards.PODIUM+Vector3(0,2.755,0))<.01 and absf(race.people[3].position.y-1.2)<.01,"Fire truck occupies podium number one and Quinn claps on number two")
	check(game.dialogue_actor==awards.reporter and game.hud.full_text==RaceAwards.ANNOUNCEMENT and game.dialogue_control.interrupting,"The filmed reporter announces Fire Truck as the new Motorway Race Club champion")
	var left_arm: Node3D=race.people[3].get_node("ArmLeft")
	var right_arm: Node3D=race.people[3].get_node("ArmRight")
	check(left_arm.find_children("*","MeshInstance3D",true,false).any(func(mesh): return mesh.layers!=0) and right_arm.find_children("*","MeshInstance3D",true,false).any(func(mesh): return mesh.layers!=0),"Both clapping arms retain visible articulated geometry")
	var hand_gap_min:=INF
	var hand_gap_max:=0.0
	for i in 40:
		awards.clock=2+float(i)*.02
		awards.animate(.02)
		var left_hand: Vector3=left_arm.global_transform*Vector3(0,-.62,0)
		var right_hand: Vector3=right_arm.global_transform*Vector3(0,-.62,0)
		var gap:=left_hand.distance_to(right_hand)
		hand_gap_min=minf(hand_gap_min,gap)
		hand_gap_max=maxf(hand_gap_max,gap)
	check(hand_gap_min<.23 and hand_gap_max>.5,"Clapping hands meet in front of the body and separate rhythmically")
	check(race.people[3].get_node("ArmRight").rotation.x>1 and not car.collision_layer,"Clapping animates and the rival collider stays removed throughout the ceremony")
	game.interact()
	await frames(60)
	check(not awards.active and not awards.troupe.visible and not challenge.result_open and game.truck.enabled and not game.truck.freeze and race.people[3].visible,"Ceremony dismissal restores the podium NPCs and free driving")
	challenge.offer()
	challenge.accept()
	challenge.cancel()
	check(not challenge.staging and not game.truck.freeze and not car.collision_layer,"Recovery cancels a race without leaving frozen controls or hidden collisions")
	if had_record:
		var restore:=FileAccess.open(ToyRaceTrack.SAVE_PATH,FileAccess.WRITE)
		restore.store_buffer(record_backup)
	elif FileAccess.file_exists(ToyRaceTrack.SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(ToyRaceTrack.SAVE_PATH))
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
