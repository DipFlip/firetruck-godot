extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=1
	game.truck.use_automation=true
	game.truck.freeze=true
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.position=Vector3(400,0,400)
	var actor: Node3D=game.town.people[0]
	game.truck.position=actor.position+Vector3(0,1,6)
	game.truck.reset_physics_interpolation()
	await frames(20)
	var hud: FireHUD=game.hud
	var panel: SpeechFrame=hud.dialogue_panel
	game.talk("MAYA","Oh, thank goodness you're here! Pippin has decided he's a bird. Could you help him down from that tree?",1)
	var popup_at:=panel.position
	await frames(180)
	check(panel.position.distance_to(popup_at)<2 and hud.get_viewport_rect().encloses(Rect2(popup_at,panel.size)),"The balloon pops up immediately at its settled spot instead of animating across the screen")
	var head: Vector2=game.camera.unproject_position(actor.global_position+Vector3.UP*2.85)
	check(panel.position.y+panel.size.y<head.y and not Rect2(panel.position,panel.size).intersects(hud.conversation_subject_rect()),"The balloon appears above Maya and leaves the tree pet visible")
	check(not Rect2(panel.position,panel.size).intersects(hud.truck_screen_rect()),"The above-head balloon leaves the complete truck visible")
	check(hud.speaker_label.position.y>hud.portrait.position.y+hud.portrait.size.y and hud.dialogue_label.position.y<24 and not hud.continue_label.visible,"Compact layout has the name beneath the portrait, top-aligned text, and no continue hint")
	var truck_screen: Vector2=game.camera.unproject_position(game.truck.position)
	check(truck_screen.y>hud.size.y*.55 and truck_screen.y<hud.size.y*.86 and game.camera.size<25.8,"Conversation framing keeps the truck below centre with a close view")
	var initial:=panel.position
	game.truck.position=actor.position+Vector3(-8,1,14)
	game.truck.reset_physics_interpolation()
	await frames(1)
	check(panel.position.distance_to(initial)<15,"A world balloon begins moving gently rather than teleporting")
	var previous:=panel.position
	var max_step:=0.0
	for i in 150:
		await frames(1)
		max_step=maxf(max_step,panel.position.distance_to(previous))
		previous=panel.position
	check(game.dialogue_active and game.camera.size<25.8 and max_step<15,"Driving sixteen metres away retains the conversation zoom and smooth balloon tracking")
	head=game.camera.unproject_position(actor.global_position+Vector3.UP*2.85)
	check((panel.get_global_transform()*panel.tail_tip).distance_to(head)<1,"The rounded notch remains aimed at the on-screen speaker as the bubble scales")
	game.paused=true
	var paused_position:=panel.position
	await frames(20)
	check(panel.position==paused_position and not panel.visible,"Pause freezes and hides the conversation balloon")
	game.paused=false
	game.end_dialogue()
	var exit_size: float=game.camera.size
	var max_exit_size:=exit_size
	var max_zoom_step:=0.0
	for i in 75:
		var previous_size: float=game.camera.size
		await frames(1)
		max_exit_size=maxf(max_exit_size,game.camera.size)
		max_zoom_step=maxf(max_zoom_step,absf(game.camera.size-previous_size))
	check(max_exit_size<=maxf(25.8,exit_size)+.25 and max_zoom_step<.8,"Ending Maya’s conversation eases back to driving without a runaway zoom")
	game.talk("MAYA","Come visit again soon!",1,false)
	await frames(5)
	game.truck.position=game.town.people[1].position+Vector3(0,1,6)
	game.truck.reset_physics_interpolation()
	await frames(25)
	game._talk_to_npc(1,true)
	var leo_popup:=panel.position
	check(hud.get_viewport_rect().encloses(panel.get_global_rect()) and panel.scale.is_equal_approx(Vector2.ONE),"Talking to a new NPC while an earlier bubble is off-screen pops up full-size in place")
	await frames(90)
	check(panel.position.distance_to(leo_popup)<2,"New NPC dialogue stays where it popped up while the camera finishes framing")
	game.end_dialogue()
	root.size=Vector2i(390,564)
	hud.touch_mode=true
	hud.touch_portrait=true
	await frames(5)
	game.talk("DISPATCH","There's a barbecue fire near Leo's cottage. Head east and lend him a hose.",1)
	await frames(100)
	check(panel.phone_mode and panel.position.y+panel.size.y>hud.size.y*.75 and (panel.position+panel.tail_tip).distance_to(hud._phone_center()-Vector2(0,27))<1,"Portrait dispatch sits at the bottom and points to its phone icon")
	game.end_dialogue()
	game.set_paused(true)
	await frames(3)
	check(hud.pause_panel.visible and hud.resume_button.visible and hud.menu_button.visible and not hud.pause_title.visible and not hud.pause_help.visible,"Mobile pause offers only Resume and Main menu")
	check(hud.resume_button.position.x+hud.resume_button.size.x<=hud.menu_button.position.x and hud.menu_button.position.x+hud.menu_button.size.x<=hud.pause_panel.size.x,"Both pause buttons fit side by side inside the panel")
	hud.resume_button.pressed.emit()
	check(not game.paused and not hud.pause_panel.visible and game.truck.enabled and not game.truck.freeze,"Resume closes the pause menu and restores driving")
	# Controller: Start pauses, the stick or d-pad chooses, A confirms.
	var start_press:=InputEventJoypadButton.new()
	start_press.button_index=JOY_BUTTON_START
	start_press.pressed=true
	game._unhandled_input(start_press)
	check(game.paused and hud.pause_panel.visible and hud.pause_resume_selected,"Controller Start opens the pause menu with Resume selected")
	var confirm:=InputEventJoypadButton.new()
	confirm.button_index=JOY_BUTTON_A
	confirm.pressed=true
	game._unhandled_input(confirm)
	check(not game.paused and game.truck.jump_blocked_until_release,"A on Resume returns to play without hopping")
	game._unhandled_input(start_press)
	var right:=InputEventJoypadButton.new()
	right.button_index=JOY_BUTTON_DPAD_RIGHT
	right.pressed=true
	game._unhandled_input(right)
	check(not hud.pause_resume_selected,"Right selects Main menu")
	game._unhandled_input(confirm)
	await frames(2)
	check(game.in_main_menu and game.truck.freeze and not game.truck.enabled and hud.main_menu.visible and not hud.pause_panel.visible,"Main menu returns to the native title screen")
	check(hud.menu_titles.size()==3 and hud.menu_titles[2].text=="FIRE AWAY!" and hud.menu_start.visible,"The title screen shows the Fire Away! signage and a Start button")
	check(InputMap.action_has_event("continue",confirm) and InputMap.action_has_event("pause",start_press),"A or Start can begin the game from the title screen")
	game.queue_free()
	await process_frame
	await process_frame
	print("CONVERSATION PRESENTATION CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
