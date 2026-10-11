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
func close_dialogue() -> void:
	if game.dialogue_active: game.interact()
	if game.dialogue_active: game.interact()
func place(p: Vector3) -> void:
	game.truck.position=p
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.automated_drive=Vector2.ZERO
	game.truck.reset_physics_interpolation()
	await frames(3)
func prepare_wait() -> void:
	while not game.rewards.pending.is_empty():
		game.rewards._process(2)
		game.end_dialogue()
	game.end_dialogue()
	game.cat_rescued=true
	game.barbecue_discovered=false
	game.barbecue_notice_time=0
	game.barbecue_briefed=false
	game.barbecue_call_sent=false
	game.barbecue_call_delay=game.BARBECUE_CALL_DELAY
	game.barbecue_ring_timer=-1
	game.fire_progress=0
	game.stage=5
	game.proximity_latches.clear()
func pause() -> void:
	var event:=InputEventAction.new()
	event.action="pause"
	event.pressed=true
	game._unhandled_input(event)
func run() -> void:
	# The exact desktop camera size is not the adaptive 75px headless window.
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.truck.use_automation=true
	game.intro.finish()
	await frames(70)
	check(game.dialogue_control.waiting_for_phone and not game.dialogue_active and game.truck.freeze,"Initial dispatch rings and waits for pickup rather than starting automatically")
	var pickup:=InputEventAction.new()
	pickup.action="jump"
	pickup.pressed=true
	game._unhandled_input(pickup)
	await frames(10)
	var panel: SpeechFrame=game.hud.dialogue_panel
	check(game.dialogue_active and panel.phone_mode and game.hud.portrait.visible and game.hud.speaker_key=="DISPATCH","Initial dispatch retains the operator portrait in its speech bubble")
	var corner: Vector2=game.hud.get_viewport_rect().size-panel.size-Vector2(26,120)
	check(panel.position.distance_to(corner)<.1 and game.dialogue_actor==null and (panel.position+panel.tail_tip).distance_to(game.hud._phone_center()-Vector2(0,27))<.1,"Bottom-right dispatch bubble points to the separate phone icon")
	var parked_card:=panel.position
	game.truck.automated_drive=Vector2(1,0)
	await frames(35)
	check(panel.position.is_equal_approx(parked_card) and game.camera_requested_subject==null and not game.truck.enabled and game.truck.freeze,"An interrupting phone call holds the truck and keeps the card anchored without requesting the NPC close view: blend "+str(game.conversation_blend)+", card motion "+str(panel.position.distance_to(parked_card)))
	close_dialogue()
	await place(TownLayout.MAYA+Vector3(-2,1,4))
	game.cat_rescued=true
	game._after_cat_rescue()
	game.rewards._process(2)
	check(game.hud.speaker_key=="MAYA" and game.stage==5 and game.barbecue_call_delay==15,"Cat rescue gives Maya a thank-you and schedules a 15-second quiet interval")
	var beginning_blend: float=game.conversation_blend
	await frames(12)
	check(game.conversation_blend>beginning_blend and game.conversation_blend-beginning_blend<.75,"A sudden approach still eases the NPC camera rather than snapping to the speaker")
	await frames(90)
	var offset: Vector3=game.camera.position-game.camera_focus
	check(game.conversation_blend>.99 and game.camera.size<25.8 and offset.distance_to(game.TALK_CAMERA_OFFSET)<.02,"A close neighbour settles into the lower, closer conversation view")
	close_dialogue()
	await frames(180)
	check(game.barbecue_call_delay>0 and game.barbecue_call_delay<15 and not game.phone_ringing(),"Acknowledging a completed mission starts the quiet interval even while parked beside its NPC")
	check(game.conversation_blend<.001 and absf(game.camera.size-25.8)<.1,"Finishing the thank-you releases the completed NPC's close view")
	await place(Vector3(0,1,23))
	await frames(180)
	check(game.conversation_blend==0 and absf(game.camera.size-25.8)<.01,"Driving away restores the regular view gradually: blend "+str(game.conversation_blend)+", size "+str(game.camera.size))
	game.set_process(false)
	game.barbecue_call_delay=15
	game._update_dispatch(14.9)
	check(not game.phone_ringing() and not game.barbecue_call_sent and not game.dialogue_active,"No call before fifteen uninterrupted idle seconds")
	game.truck.spray_requested=true
	game._update_dispatch(.1)
	check(game.barbecue_call_delay==15 and not game.phone_ringing(),"Hose use resets rather than pauses the quiet interval")
	game.truck.spray_requested=false
	game.truck.spraying=false
	game._update_dispatch(14.9)
	check(not game.phone_ringing(),"Leaving an activity requires a fresh full quiet interval")
	game._update_dispatch(.11)
	check(game.phone_ringing() and not game.barbecue_call_sent,"Phone rings after fifteen consecutive idle seconds")
	game.truck.ladder_deployed=true
	game._update_dispatch(.1)
	check(not game.phone_ringing() and game.barbecue_call_delay==15,"Beginning ladder work cancels a ringing call")
	game.truck.ladder_deployed=false
	game._update_dispatch(15)
	game._update_dispatch(3)
	check(game.barbecue_call_sent and game.hud.speaker_key=="DISPATCH" and game.stage==2 and game.hud.full_text.contains("barbecue") and not game.hud.full_text.contains("pool"),"The follow-up calls in only the still-undiscovered barbecue")
	close_dialogue()
	game._update_dispatch(60)
	check(not game.dialogue_active and game.barbecue_ring_timer<0 and game.barbecue_call_delay<0,"Barbecue dispatch remains a one-shot call")
	game.set_process(true)
	prepare_wait()
	await place(TownLayout.FIRE+Vector3(-7,1,0))
	await frames(80)
	check(game.barbecue_discovered and game.stage==3 and game.barbecue_call_delay<0,"Finding the barbecue yourself unlocks firefighting and cancels the pending call")
	game._update_dispatch(30)
	check(not game.barbecue_call_sent,"Discovery before the deadline suppresses the later operator call")
	await place(Vector3(0,1,23))
	await frames(150)
	prepare_wait()
	game.barbecue_call_delay=.03
	await frames(5)
	check(game.phone_ringing(),"Delayed phone ring starts when the channel is free")
	await place(TownLayout.LEO+Vector3(0,1,3))
	await frames(90)
	check(not game.barbecue_call_sent and not game.phone_ringing(),"Discovery during the ringing lead-in cancels an obsolete call")
	# A player may find and extinguish the fire before rescuing Pippin.
	game.end_dialogue()
	game.cat_rescued=false
	game.stage=1
	game.fire_progress=0
	game.barbecue_discovered=false
	game.barbecue_notice_time=0
	await place(TownLayout.FIRE+Vector3(-7,1,0))
	await frames(80)
	check(game.barbecue_discovered and game.stage==1,"Early discovery preserves the unfinished cat objective")
	game._water_hit(TownLayout.FIRE+Vector3.UP*1.8,.6/.22)
	check(game.fire_progress>=1 and game.stage==1,"Putting out the fire early also preserves the cat objective")
	close_dialogue()
	game.cat_rescued=true
	await place(TownLayout.MAYA+Vector3(-2,1,4))
	game._after_cat_rescue()
	check(game.stage==4 and game.barbecue_call_delay<0,"A previously handled barbecue is never called in after the cat rescue")
	close_dialogue()
	prepare_wait()
	await place(TownLayout.JUNE+Vector3(0,1,4))
	game.barbecue_call_delay=.01
	await frames(90)
	game._update_dispatch(30)
	check(not game.dialogue_active and not game.phone_ringing() and game.barbecue_call_delay==15,"An automatic help prompt and NPC zoom count as mission activity without blocking driving")
	game._talk_to_npc(2,true)
	game._update_dispatch(30)
	check(game.dialogue_active and game.hud.speaker_key=="JUNE" and not game.phone_ringing(),"The phone stays silent throughout an accepted mission conversation")
	close_dialogue()
	await place(Vector3(0,1,23))
	await frames(150)
	game.barbecue_call_delay=5
	pause()
	await frames(30)
	check(game.barbecue_call_delay==5,"Pause also pauses the dispatch countdown")
	pause()
	game.set_process(false)
	for activity in ["rescue", "mission camera", "racetrack", "travel"]:
		game.barbecue_call_delay=.01
		match activity:
			"rescue": game.rescue_running=true
			"mission camera":
				game.pool_camera_interest.weight=1
				game.camera_framing.active.append(game.pool_camera_interest)
			"racetrack": game.travel.in_race=true
			"travel": game.travel.active=true
		game._update_dispatch(30)
		check(not game.phone_ringing() and game.barbecue_call_delay==15,activity+" prevents ringing and restarts the idle wait")
		game.rescue_running=false
		game.camera_framing.reset()
		game.travel.in_race=false
		game.travel.active=false
	game.barbecue_call_delay=.01
	game._update_dispatch(.02)
	check(game.phone_ringing(),"Free exploration allows the deferred phone ring")
	game.set_process(true)
	await place(TownLayout.JUNE+Vector3(0,1,4))
	check(not game.phone_ringing() and game.barbecue_call_delay==15,"Approaching an NPC during ringing immediately silences the phone")
	game.queue_free()
	await process_frame
	await process_frame
	print("DISPATCH CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
