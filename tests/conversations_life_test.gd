extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, description: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+description)
	if not ok: failures+=1
func press_space() -> void:
	var event:=InputEventAction.new()
	event.action="jump"
	event.pressed=true
	game._unhandled_input(event)
func click(point: Vector2, touch: bool=false) -> void:
	if touch:
		var event:=InputEventScreenTouch.new()
		event.position=point
		event.pressed=true
		game._unhandled_input(event)
	else:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		game._unhandled_input(event)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=1
	game.truck.freeze=true
	game.truck.use_automation=true
	game.life.set_physics_process(false)
	game.truck.position=TownLayout.MAYA+Vector3(0,1,5)
	game.camera_focus=game.truck.position
	game.proximity_latches[0]=true
	await frames(3)
	press_space()
	check(game.dialogue_active and game.dialogue_actor==game.town.people[0] and game.truck.charge==0,"Space starts a nearby NPC conversation without winding up a jump")
	var message: String=game.hud.dialogue_text
	check(game.hud.full_text==message and game.hud.dialogue_pages.size()==1,"The entire instruction is one message")
	click(game.hud.dialogue_panel.position+game.hud.dialogue_panel.size*.5)
	check(game.dialogue_active and game.hud.char_count==message.length(),"Clicking the bubble reveals all words")
	click(game.hud.dialogue_panel.position+game.hud.dialogue_panel.size*.5,true)
	check(not game.dialogue_active,"A second tap finishes the whole message without a leftover word")
	await frames(65)
	var actor: Node3D=game.town.people[0]
	var at: Vector2=game.camera.unproject_position(actor.global_position+Vector3.UP*1.3)
	click(at,true)
	check(game.dialogue_active and game.dialogue_actor==actor,"Tapping the neighbour starts another conversation after the proximity latch")
	game.truck.position=TownLayout.MAYA+Vector3(0,1,12)
	game.truck.reset_physics_interpolation()
	await frames(120)
	check(game.npc_in_view(actor) and game.dialogue_active,"Driving beyond the old nine-meter cutoff keeps a visible neighbour talking")
	game.truck.position=TownLayout.MAYA+Vector3(0,1,45)
	game.truck.reset_physics_interpolation()
	await frames(120)
	check(not game.dialogue_active and not game.npc_in_view(actor),"Conversation closes only after the entire neighbour leaves the view")
	game.set_process(false)
	for screen in [Vector2i(390,564),Vector2i(320,330),Vector2i(844,390),Vector2i(1440,900)]:
		root.size=screen
		game.hud.touch_mode=screen.x<1100
		await frames(3)
		game.hud.begin_dialogue("MAYA",message)
		await frames(3)
		check(game.hud.full_text==message and game.hud.dialogue_pages.size()==1,"Complete message on "+str(screen))
		check(game.hud.dialogue_label.get_minimum_size().y<=game.hud.dialogue_label.size.y+.1,"All wrapped rows fit in their label on "+str(screen))
		check(game.hud.dialogue_panel.size.y<game.hud.size.y-20,"Full message bubble fits the available screen on "+str(screen))
	game.end_dialogue()
	game.hud.dialogue_text=""
	game.life.set_physics_process(true)
	var bird: Dictionary=game.life.ground_birds[0]
	game.truck.position=bird.home+Vector3(0,1,4)
	await frames(60)
	check(bird.mode=="flee" and bird.node.position.y>2,"Ground birds take flight when the truck approaches")
	game.truck.position=Vector3(70,1,70)
	await frames(440)
	check(bird.mode=="ground" and bird.node.position.distance_to(bird.home)<.05,"Birds return to the ground after the truck leaves")
	for car in game.life.cars: car.node.freeze=true
	game.life.set_physics_process(false)
	# A full second of water is insufficient; uninterrupted spray reaches the
	# threshold once, and continued spray cannot repeat the honk immediately.
	for car in game.life.cars:
		for i in 60:
			game._water_hit(car.node.to_global(Vector3(.8,.9,0)),.0036)
			game.life._physics_process(1.0/60)
		check(car.honk_count==0,"Car does not honk prematurely")
		for i in 40:
			game._water_hit(car.node.to_global(Vector3(.8,.9,0)),.0036)
			game.life._physics_process(1.0/60)
		check(car.honk_count==1 and not game.rewards.sparkles.is_empty(),"Each town car honks and sparkles after about 1.5 seconds of water")
		for i in 60:
			game._water_hit(car.node.to_global(Vector3(.8,.9,0)),.0036)
			game.life._physics_process(1.0/60)
		check(car.honk_count==1,"Continuous spray has a cooldown instead of honking every frame")
	var washed: Dictionary=game.life.cars[0]
	washed.node.position=Vector3(-60,.12,-48)
	washed.node.rotation=Vector3.ZERO
	washed.wet_age=10.0
	washed.wash_time=0.0
	washed.wash_cooldown=0.0
	washed.honk_count=0
	game.truck.position=Vector3(-60,.85,-40)
	game.truck.automated_aim=washed.node.position+Vector3.UP*.9
	game.truck.automated_spray=true
	game.truck.reset_physics_interpolation()
	for i in 135:
		await physics_frame
		game.life._physics_process(1.0/60)
		for car in game.life.cars: car.node.freeze=true
	check(washed.honk_count==1 and game.truck.water<99,"Actual hose droplets collide with a car and trigger its wash reaction")
	game.truck.automated_spray=false
	game._water_hit(TownLayout.FIRE+Vector3.UP*1.8,20)
	game._water_hit(TownLayout.DOG+Vector3.UP*.7,20)
	game._water_hit(TownLayout.POOL+Vector3.UP*game.town.pool_water.position.y,20)
	check(game.hud.toast_label.text.is_empty(),"Mission completion uses sparkles and thanks without a banner")
	check(game.rewards.sound.stream.data.decode_s16(game.rewards.sound.stream.data.size()-2)==0,"Reward chime ends in silence without an abrupt cutoff")
	game.queue_free()
	await process_frame
	await process_frame
	print("CONVERSATION / LIFE CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
