extends SceneTree
# Use Compatibility: the headless Dummy renderer does not retain MultiMesh pivots.
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.sounds.set_process(false)
	game.life.set_physics_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	game.call_timer=0
	var sounds: TownAudio=game.sounds
	check(sounds.players.size()==12 and sounds.players.all(func(p): return p is AudioStreamPlayer3D and p.playback_type==AudioServer.PLAYBACK_TYPE_STREAM),"Scene Foley keeps twelve pooled, spatially mixed stream voices")
	for is_race in [false,true]:
		if is_race:
			game.intro.finish()
			game.travel.start(true)
			game.travel._swap_world()
		else: game.intro.start()
		var travel: PlayMatTravel=game.travel
		var growing:=travel.assembly_audio.filter(func(cue): return cue.kind=="house_grow")
		var blocks:=travel.assembly_audio.filter(func(cue): return cue.kind=="block_land")
		print("SCHEDULE ",is_race,": grows=",growing.size()," blocks=",blocks.size())
		check(growing.size()>=(2 if is_race else 4) and blocks.size()>40,"Both mats have deduplicated grow cues and a populated wooden perimeter cascade")
		var keys: Dictionary={}
		var unique:=true
		for cue in travel.assembly_audio:
			var key: String=str(cue.at)+cue.kind
			unique=unique and not keys.has(key)
			keys[key]=true
		check(unique,"Material batches do not duplicate a house's growth sound")
		var wood_before: int=sounds.counts.get("block_land",0)
		var grow_before: int=sounds.counts.get("house_grow",0)
		for i in 240:
			var elapsed: float=(i+1)*.1
			travel.assembly_camera(elapsed,is_race)
			travel.grow_assembly(PlayMatTravel.arrival_progress(elapsed,is_race))
			sounds._process(.1)
		var wood_count: int=int(sounds.counts.get("block_land",0))-wood_before
		var grow_count: int=int(sounds.counts.get("house_grow",0))-grow_before
		print("INTRO CUES ","Motorway" if is_race else "Maple Bay",": wooden landings=",wood_count," house growth=",grow_count)
		check(wood_count>=15 and grow_count>=(2 if is_race else 4),"The camera sweep hears frequent wooden landings and rising buildings on both mats")
		check(sounds.listener.global_position.distance_to(game.camera.global_position)>100,"The intro listener stays near the toys instead of the distant clipping-safe lens")
		travel.finish_assembly()
	game.queue_free()
	await process_frame
	await process_frame
	print("INTRO AUDIO: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
