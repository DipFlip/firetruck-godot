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
	game.end_dialogue()
	game.cat_rescued=true
	game.barbecue_discovered=false
	game.barbecue_notice_time=0
	game.barbecue_briefed=false
	game.barbecue_call_sent=false
	game.barbecue_call_delay=20
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
	await frames(110)
	var panel: SpeechFrame=game.hud.dialogue_panel
	check(game.dialogue_active and panel.phone_mode and game.hud.portrait.visible and game.hud.speaker_key=="DISPATCH","Initial dispatch retains the operator portrait in its speech bubble")
	var corner: Vector2=game.hud.get_viewport_rect().size-panel.size-Vector2(26,132)
	check(panel.position.distance_to(corner)<.1 and game.dialogue_actor==null and (panel.position+panel.tail_tip).distance_to(game.hud._phone_center()-Vector2(0,27))<.1,"Bottom-right dispatch bubble points to the separate phone icon")
	var parked_card:=panel.position
	game.truck.automated_drive=Vector2(1,0)
	await frames(35)
	check(panel.position.is_equal_approx(parked_card) and is_equal_approx(game.camera.size,25.8) and game.truck.enabled,"Driving during a phone call neither moves the card nor changes the camera framing")
	close_dialogue()
	await place(TownLayout.MAYA+Vector3(-2,1,4))
	game.cat_rescued=true
	game._after_cat_rescue()
	var rescued_at: float=game.elapsed
	check(game.hud.speaker_key=="MAYA" and game.stage==5 and game.barbecue_call_delay==20,"Cat rescue gives Maya a thank-you and starts a 20-second exploration interval")
	await frames(12)
	check(game.conversation_blend>0 and game.conversation_blend<.2 and game.camera.size>23,"NPC camera starts gently rather than snapping to the speaker")
	await frames(18)
	check(game.conversation_blend>.45 and game.conversation_blend<.55,"Camera transition is halfway through after half a second")
	await frames(31)
	var offset: Vector3=game.camera.position-game.camera_focus
	check(is_equal_approx(game.conversation_blend,1) and absf(game.camera.size-game.TALK_CAMERA_SIZE)<.01 and offset.distance_to(game.TALK_CAMERA_OFFSET)<.01,"After one second the camera is closer, lower, and shifted sideways")
	close_dialogue()
	await frames(30)
	check(game.conversation_blend>.45 and game.conversation_blend<.55,"Leaving the conversation also eases over a full second")
	await frames(31)
	check(game.conversation_blend==0 and is_equal_approx(game.camera.size,25.8),"Camera returns completely to the driving view")
	while game.elapsed<rescued_at+19.8: await frames(1)
	check(not game.phone_ringing() and not game.barbecue_call_sent and not game.dialogue_active,"No early barbecue call or immediate dispatch interrupts the exploration interval")
	await frames(20)
	check(game.phone_ringing() and not game.barbecue_call_sent,"Phone rings after the 20-second delay before dispatch speaks")
	await frames(80)
	check(game.barbecue_call_sent and game.hud.speaker_key=="DISPATCH" and game.stage==2 and game.hud.full_text.contains("barbecue") and not game.hud.full_text.contains("pool"),"The follow-up calls in only the still-undiscovered barbecue")
	close_dialogue()
	await frames(1800)
	check(not game.dialogue_active and game.barbecue_ring_timer<0 and game.barbecue_call_delay<0,"Barbecue dispatch is a one-shot call, not a repeating inactivity reminder")
	prepare_wait()
	await place(TownLayout.FIRE+Vector3(-7,1,0))
	await frames(80)
	check(game.barbecue_discovered and game.stage==3 and game.barbecue_call_delay<0,"Finding the barbecue yourself unlocks firefighting and cancels the pending call")
	await frames(1300)
	check(not game.barbecue_call_sent,"Discovery before the deadline suppresses the later operator call")
	await place(TownLayout.MAYA+Vector3(-2,1,4))
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
	await frames(180)
	check(game.dialogue_active and game.hud.speaker_key=="JUNE" and game.phone_ringing() and not game.barbecue_call_sent,"A due call rings visibly while waiting for the active NPC conversation to finish")
	game.barbecue_call_delay=5
	pause()
	await frames(120)
	check(game.barbecue_call_delay==5,"Pause also pauses the dispatch countdown")
	pause()
	game.queue_free()
	await process_frame
	await process_frame
	print("DISPATCH CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
