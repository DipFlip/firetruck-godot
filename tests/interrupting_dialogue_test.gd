extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func press(action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=true
	game._unhandled_input(event)
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.set_process(false)
	game.travel.set_process(false)
	game._update_dispatch(.5)
	check(game.dialogue_control.waiting_for_phone and game.truck.freeze and not game.truck.enabled and not game.dialogue_active,"Arriving starts a ringing phone and holds truck controls")
	press("jump")
	check(not game.dialogue_active,"Pickup waits for the one-second ringing lead-in")
	game._update_dispatch(.51)
	await process_frame
	await process_frame
	check(game.dialogue_control.pickup_prompt.visible and game.dialogue_control.pickup_prompt.text=="to pick up" and game.dialogue_control.pickup_button.is_visible_in_tree(),"A pickup arrow and animated Space button appear after one second")
	game.controls.set_mode(ControlPrompts.Mode.GAMEPAD)
	await process_frame
	check(game.dialogue_control.pickup_button.is_visible_in_tree() and ControlPrompts.mode==ControlPrompts.Mode.GAMEPAD,"Controller pickup uses the shared animated south-button layout")
	for action in ["left","right","forward","back","aim_left","aim_right","aim_up","aim_down"]: press(action)
	check(game.dialogue_control.waiting_for_phone and not game.dialogue_active,"Directional buttons cannot answer the ringing phone")
	press("jump")
	check(game.dialogue_active and game.dialogue_control.interrupting and game.hud.speaker_key=="DISPATCH" and game.hud.char_count==game.hud.full_text.length(),"Pickup shows the complete interrupting dispatch message")
	Input.action_press("forward")
	press("forward")
	check(game.dialogue_active and game.truck.freeze,"Driving forward cannot acknowledge the call")
	for key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		var arrow:=InputEventKey.new()
		arrow.physical_keycode=key
		arrow.pressed=true
		game._unhandled_input(arrow)
		check(game.dialogue_active and game.truck.freeze,"Arrow key leaves the conversation open: "+str(key))
	var movement:=InputEventJoypadMotion.new()
	movement.axis=JOY_AXIS_LEFT_X
	movement.axis_value=.8
	game._unhandled_input(movement)
	var dpad:=InputEventJoypadButton.new()
	dpad.button_index=JOY_BUTTON_DPAD_DOWN
	dpad.pressed=true
	game._unhandled_input(dpad)
	check(game.dialogue_active and game.truck.freeze,"Controller sticks and D-pad cannot advance ordinary dialogue")
	press("jump")
	check(not game.dialogue_active and not game.truck.freeze and game.truck.enabled and game.truck.input_blocked_until_release,"Space acknowledges the call and enables driving")
	await frames(3)
	check(game.truck.drive_input()==Vector2.ZERO and game.truck.input_blocked_until_release,"A held acknowledgement key cannot immediately drive the truck")
	Input.action_release("forward")
	await frames(3)
	check(not game.truck.input_blocked_until_release,"Releasing the acknowledgement restores ordinary inputs")
	game.talk("DISPATCH  /  CHECK", "Ready when you are.",1,true)
	Input.action_press("brake")
	press("brake")
	await frames(3)
	check(game.truck.brake_engagement<.01 and game.truck.charge==0,"A held brake acknowledgement cannot brake or charge a jump")
	Input.action_release("brake")
	await frames(3)
	for index in 4:
		game._talk_to_npc(index,true)
		check(game.dialogue_control.interrupting and game.truck.freeze,"First mission briefing interrupts: "+str(index))
		for action in ["left","right","forward","back","aim_left","aim_right","aim_up","aim_down"]: press(action)
		check(game.dialogue_active and game.truck.freeze,"Direction inputs leave the mission briefing open: "+str(index))
		press("interact")
		check(not game.dialogue_active and not game.truck.ladder_deployed,"Acknowledging a briefing cannot accidentally extend the ladder")
		game._talk_to_npc(index,true)
		check(not game.dialogue_control.interrupting and not game.truck.freeze,"Repeat conversation permits driving: "+str(index))
		game.end_dialogue()
	game._after_cat_rescue()
	game.rewards._process(2)
	check(game.dialogue_control.interrupting,"The first cat rescue thank-you interrupts")
	press("map")
	check(not game.dialogue_active and not game.hud.map_open,"A thank-you acknowledgement cannot open the map")
	game.cat_rescued=true
	check(not game._talk_to_npc(0),"Completed missions do not automatically repeat their thank-you")
	game._talk_to_npc(0,true)
	check(not game.dialogue_control.interrupting,"Manual repeat thanks remains non-interrupting")
	game.end_dialogue()
	game.travel.start(true)
	game.travel.finish()
	var challenge: RaceChallenge=game.travel.race.challenge
	challenge.offer()
	var stick:=InputEventJoypadMotion.new()
	stick.axis=JOY_AXIS_LEFT_X
	stick.axis_value=.8
	game._unhandled_input(stick)
	check(not challenge.selected_yes,"A controller stick selects No")
	stick.axis_value=-.8
	game._unhandled_input(stick)
	check(challenge.selected_yes,"Reversing the controller stick selects Yes without needing a neutral event")
	press("right")
	check(challenge.offering and not challenge.selected_yes and game.truck.freeze,"Right selects No without accepting or driving")
	press("forward")
	check(challenge.offering,"Directional input cannot confirm a multiple choice")
	press("brake")
	check(not challenge.offering and not challenge.staging and not game.dialogue_control.interrupting and not game.truck.freeze,"Any non-directional button confirms the chosen No")
	challenge.offer()
	press("right")
	press("left")
	press("map")
	check(challenge.staging and not game.hud.map_open,"Left selects Yes and any non-directional button starts the countdown")
	challenge.cancel()
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
