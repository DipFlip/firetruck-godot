extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var args:=OS.get_cmdline_user_args()
	var action := "--action" in args
	var drive := "--drive" in args
	var ground := "--ground" in args
	var conversation:="--conversation" in args
	var phone:="--phone" in args
	var pool_assist:="--pool-assist" in args
	if pool_assist:
		game.call_timer=0
		game.stage=4
		game.truck.global_position=TownLayout.POOL+Vector3(9,1,-5)
		game.camera_focus=game.truck.position
		game.truck.use_automation=true
		game.truck.automated_aim=TownLayout.POOL+Vector3(-5.2,-1.3,3.1)
		game.truck.automated_spray=true
		for i in 4: game.proximity_latches[i]=true
		Input.action_press("brake")
	if phone:
		game.call_timer=0
		game.cat_rescued=true
		game.talk("DISPATCH  /  INCOMING CALL","Unit 04, we've had a call from Willow Lane. Leo's barbecue has flared up! Head east and lend him a hose.",2)
	var hud_only:="--hud" in args
	if hud_only:
		game.call_timer=0
		game.stage=1
		game._update_mission()
	if action:
		game.call_timer=0
		game.stage=3
		game._update_mission()
		game.truck.global_position=TownLayout.FIRE+Vector3(1,1,8)
		game.truck.use_automation=true
		game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.7
		game.truck.automated_spray=true
		Input.action_press("brake")
	if drive or ground:
		game.call_timer=0
		game.stage=4
		game._update_mission()
		game.truck.use_automation=true
		game.truck.position=Vector3(0,1,12)
		if drive: game.truck.automated_drive=Vector2(.48,-.88)
		if ground:
			game.truck.automated_spray=true
			game.truck.automated_aim=Vector3(7,0,2)
			Input.action_press("brake")
	if conversation:
		game.call_timer=0
		game.truck.global_position=Vector3(10,1,-3)
		game.camera_focus=game.truck.position
		game.stage=1
		game._update_mission()
		game.talk("MAYA  /  MAPLE GREEN","Oh, thank goodness you're here! Pippin has decided he's a bird. Could you help him down from that tree?",1)
	await create_timer(7.5 if conversation or phone else 2.0).timeout
	RenderingServer.force_draw()
	if pool_assist:
		root.get_texture().get_image().save_png("res://tests/pool-assist.png")
	if phone:
		root.get_texture().get_image().save_png("res://tests/phone-call.png")
	if hud_only:
		root.get_texture().get_image().save_png("res://tests/hud-preview.png")
	root.get_texture().get_image().save_png("res://tests/driving-preview.png" if drive else "res://tests/splash-preview.png" if ground else "res://tests/dialogue-preview.png" if conversation else "res://tests/action-preview.png" if action else "res://tests/town-preview.png")
	if game.audio: game.audio.stop()
	game.queue_free()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	quit()
