extends SceneTree
# Isolate the CPU cost of cinematic toy transforms, independent of GPU/vsync.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game:=load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	await process_frame
	game.intro.finish()
	var results: Array=[]
	for is_race in [false,true]:
		if is_race: game.travel.race.show()
		for run in 2:
			var start:=Time.get_ticks_usec()
			game.travel.begin_assembly(is_race)
			var setup:=Time.get_ticks_usec()-start
			var phases: Array=[]
			for phase in 4:
				start=Time.get_ticks_usec()
				for frame in 180: game.travel.grow_assembly((phase*180+frame)/719.0)
				phases.append((Time.get_ticks_usec()-start)/180000.0)
			results.append({"race":is_race,"run":run,"pieces":game.travel.assembly.size(),"setup_ms":setup/1000.0,"grow_ms_per_frame":phases})
			game.travel.finish_assembly()
	var report:={"results":results}
	print("INTRO CPU BENCHMARK ",JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			FileAccess.open(arg.trim_prefix("--output="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free()
	await process_frame
	await process_frame
	quit()
