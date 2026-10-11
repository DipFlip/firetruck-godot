extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.set_process(false)
	game.travel.set_process(false)
	game.intro.start()
	game.intro.update((21.5)/PlayMatTravel.INTRO_PACE)
	check(game.travel.mat.visible and game.travel.mat.print_fade.get_shader_parameter("print_opacity")>0,"The remaining printed ground is still fading during the final pan")
	check(game.hud.water_entrance_scale==0,"The meter waits until the arrival's last moment")
	game.intro.update((TownIntro.LENGTH-game.intro.clock)/PlayMatTravel.INTRO_PACE-.7)
	game.hud._update_water_entrance(0)
	check(game.travel.assembly.is_empty() and not game.travel.mat.visible,"Scenery batches and printed ground are fully ready during the final pan")
	check(game.hud.water_entrance_scale>0 and game.hud.water_entrance_scale<1,"The water meter begins scaling up while the camera is still panning")
	game.intro.update(.24)
	game.hud._update_water_entrance(0)
	check(game.hud.water_entrance_scale>1 and game.hud.water_entrance_scale<1.09,"The meter eases through a small overshoot")
	game.intro.update(.459)
	game.hud._update_water_entrance(0)
	var before: Transform3D=game.camera.global_transform
	var sun_range: float=game.sun.directional_shadow_max_distance
	var far: float=game.camera.far
	check(game.hud.water_entrance_scale==1 and absf(game.camera.far-250)<.01,"The meter and shadow range settle before the starting view is reached")
	game.intro.update(.001)
	game.hud._update_water_entrance(0)
	check(game.camera.global_position.distance_to(before.origin)<.05 and absf(game.camera.far-far)<.01 and absf(game.sun.directional_shadow_max_distance-sun_range)<.01 and game.hud.water_entrance_scale==1,"Camera, lighting and meter remain continuous across the Maple handoff")
	game.travel.start(true)
	check(game.hud.water_entrance_scale==0,"A new scene resets the shared meter entrance")
	game.travel._update_transition(game.travel.duration-.7)
	game.hud._update_water_entrance(0)
	check(game.travel.assembly.is_empty() and absf(game.camera.far-500)<.01 and game.hud.water_entrance_scale>0 and game.hud.water_entrance_scale<1,"Motorway's full intro also prepares lighting and scales in its meter")
	game.travel._update_transition(.24)
	game.hud._update_water_entrance(0)
	check(game.hud.water_entrance_scale>1,"Motorway uses the same bounce easing")
	game.travel._update_transition(.459)
	game.hud._update_water_entrance(0)
	far=game.camera.far
	game.travel._update_transition(.001)
	game.hud._update_water_entrance(0)
	check(absf(game.camera.far-far)<.01 and game.hud.water_entrance_scale==1,"Full Motorway handoff keeps the final depth range and settled meter")
	game.travel.start(false)
	game.travel._update_transition(3.5+PlayMatTravel.DEPARTURE_LEAD)
	game.hud._update_water_entrance(0)
	check(game.travel.short_transition and game.hud.water_entrance_scale>0 and game.hud.water_entrance_scale<1,"Short return trips also animate the shared meter")
	game.travel._update_transition(.24)
	game.hud._update_water_entrance(0)
	check(game.hud.water_entrance_scale>1,"Short returns include the same slight overshoot")
	game.travel._update_transition(.459)
	game.hud._update_water_entrance(0)
	far=game.camera.far
	game.travel._update_transition(.001)
	game.hud._update_water_entrance(0)
	check(absf(game.camera.far-far)<.01 and game.hud.water_entrance_scale==1,"The return view and meter settle before control resumes")
	game.intro.start()
	game.intro.finish()
	game.hud._update_water_entrance(.2)
	check(game.hud.water_entrance_scale>0 and game.hud.water_entrance_scale<1,"Skipping an intro still plays the meter entrance")
	game.paused=true
	var scale: float=game.hud.water_entrance_scale
	game.hud._update_water_entrance(.5)
	check(game.hud.water_entrance_scale==scale,"Pause freezes the meter entrance without restarting it")
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
