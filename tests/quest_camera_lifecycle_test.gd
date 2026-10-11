extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func place(at: Vector3) -> void:
	game.truck.global_position=at
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.reset_physics_interpolation()
	await physics_frame
	await process_frame
func settle(seconds: float=3) -> void:
	for i in int(seconds*60):
		game._process(1.0/60)
		game.hud._position_dialogue(1.0/60)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 15:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/firedriver-quest-"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	game.call_timer=0
	game.stage=4
	for i in 5: game.proximity_latches[i]=true
	var dialogue: DialogueControl=game.dialogue_control
	dialogue.start_phone()
	dialogue.update_phone(1.05)
	dialogue._process(0)
	check(dialogue.pickup_button.visible and dialogue.pickup_prompt.text=="to pick up" and is_equal_approx(dialogue.pickup_button.clock,.05),"The initial call shows the shared pressing-button animation after its one-second delay")
	check(InteractionButton.pressed_at(.1) and not InteractionButton.pressed_at(.3) and InteractionButton.pressed_at(.9) and NPCAttention.CLICK_PERIOD==InteractionButton.CLICK_PERIOD,"Phone and help buttons share the same 0.8-second cycle and 0.25-second press")
	await capture("phone-pressed")
	dialogue.update_phone(.4)
	dialogue._process(0)
	await capture("phone-released")
	game.controls.set_mode(ControlPrompts.Mode.GAMEPAD)
	dialogue._process(0)
	await capture("phone-controller")
	dialogue.pickup()
	game.end_dialogue()
	game.controls.set_mode(ControlPrompts.Mode.KEYBOARD)
	game.stage=4
	var oliver: Node3D=game.town.people[3]
	var lenses: Array[float]=[]
	for distance in [26.0,20.0,14.0,8.0,5.0]:
		await place(oliver.global_position+Vector3(0,.855,distance))
		settle()
		lenses.append(game.camera.size)
		check(game.pool_camera_interest.weight<.001,"The pool does not compete with Oliver's approach at "+str(distance)+" metres")
	check(lenses[1]<=lenses[0]+.1 and lenses[2]<=lenses[1]+.1 and lenses[3]<=lenses[2]+.1 and lenses[4]<=lenses[3]+.1,"Approaching Oliver tightens the lens without a second zoom back out: "+str(lenses))
	game._talk_to_npc(3,true)
	settle()
	check(game.dialogue_active and dialogue.interrupting and game.pool_camera_interest.weight<.001,"Oliver's first briefing remains focused on him throughout his dialogue")
	await capture("oliver-briefing")
	game.end_dialogue()
	settle()
	check(game.pool_camera_interest.weight>.95,"Acknowledging Oliver's briefing reveals the pool for his mission")
	await capture("pool-revealed")
	game.pool_done=true
	game.rewards.celebrate("pool",TownLayout.POOL,"OLIVER","Thank you for saving the pool party!")
	game.rewards._process(2)
	settle()
	check(game.dialogue_actor==oliver and dialogue.interrupting and game.conversation_blend>.9,"The first thank-you still holds its celebration camera")
	game.end_dialogue()
	settle(4)
	check(game.conversation_blend<.001 and game.pool_camera_interest.weight<.001 and absf(game.camera.size-25.8)<.1,"After Oliver's thank-you the camera returns to driving even while parked beside him")
	for index in [0,1,2]:
		if index==0: game.cat_rescued=true
		elif index==1: game.fire_progress=1
		else: game.dog_done=true
		var actor: Node3D=game.town.people[index]
		await place(actor.global_position+Vector3(0,.855,6))
		game.talk(["MAYA","LEO","JUNE"][index],"Thank you so much!",4,true)
		settle()
		check(game.conversation_blend>.9,"Completed NPC "+str(index)+" keeps the camera during their thank-you")
		game.end_dialogue()
		settle(4)
		check(game._approach_camera_subject(game.truck.global_position)!=actor and game.conversation_blend<.001,"Completed NPC "+str(index)+" releases proximity zoom after the thank-you")
		await place(actor.global_position+Vector3(0,.855,35))
		settle()
		await place(actor.global_position+Vector3(0,.855,6))
		settle()
		check(game.conversation_blend<.001,"Returning to completed NPC "+str(index)+" does not zoom in again")
		game._talk_to_npc(index,true)
		check(game.dialogue_active and not dialogue.interrupting,"Manual repeat dialogue remains available for completed NPC "+str(index))
		game.end_dialogue()
	game.pool_done=false
	dialogue.spoken_actors.erase(oliver)
	game.pool_camera_interest.reset()
	await place(TownLayout.POOL+Vector3(0,.855,8))
	game._water_hit(TownLayout.POOL+Vector3.UP*game.town.pool_water.position.y,.01)
	settle(.5)
	check(game.pool_camera_interest.weight>.9,"Filling the pool directly still engages mission framing without a briefing")
	game.travel.start(true)
	game.travel.finish()
	var race: ToyRaceTrack=game.travel.race
	race.jobs[0].done=true
	race.jobs[1].done=true
	race.jobs[2].done=true
	race.challenge.has_raced=true
	for index in [1,2,3]:
		await place(race.people[index].global_position+Vector3(0,.855,6))
		check(not game._npc_needs_camera(race.people[index]) and game._approach_camera_subject(game.truck.global_position)!=race.people[index],"Completed Motorway mission "+str(index)+" no longer attracts the camera")
	game.queue_free()
	await process_frame
	await process_frame
	print("QUEST CAMERA LIFECYCLE CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
