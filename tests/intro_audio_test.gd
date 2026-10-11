extends SceneTree
# Use Compatibility: the headless Dummy renderer does not retain MultiMesh pivots.
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func perimeter_pcm(travel: PlayMatTravel, sounds: TownAudio, begin: float, audible: bool) -> void:
	if DisplayServer.get_name()=="headless": return
	for player in sounds.players: player.stop()
	var bus:=AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus,"IntroPerimeterProbe")
	var master_volume:=AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-80)
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=3
	AudioServer.add_bus_effect(bus,capture)
	for player in sounds.players: player.bus="IntroPerimeterProbe"
	var original_bank:=sounds.bank
	sounds.bank={"block_land":original_bank.block_land}
	travel.grow_assembly(PlayMatTravel.arrival_progress(begin))
	# Let the first rendered frame finish shader preparation before timing PCM.
	for i in 6: await process_frame
	await create_timer(.12).timeout
	capture.clear_buffer()
	var start:=Time.get_ticks_msec()
	var previous:=start
	while Time.get_ticks_msec()-start<int(1900/PlayMatTravel.INTRO_PACE):
		var now:=Time.get_ticks_msec()
		var elapsed:=begin+float(now-start)/1000*PlayMatTravel.INTRO_PACE
		travel.assembly_camera(elapsed,false)
		travel.grow_assembly(PlayMatTravel.arrival_progress(elapsed))
		sounds._process(float(now-previous)/1000)
		previous=now
		await process_frame
	var frames:=capture.get_buffer(capture.get_frames_available())
	var sum:=0.0
	var peak:=0.0
	var tail_energy:=0.0
	var tail_start:=maxi(0,frames.size()-int(AudioServer.get_mix_rate()*.35))
	for i in frames.size():
		var energy: float=frames[i].length_squared()
		sum+=energy
		peak=maxf(peak,maxf(absf(frames[i].x),absf(frames[i].y)))
		if i>=tail_start: tail_energy+=energy
	var rms:=sqrt(sum/maxi(1,frames.size()*2))
	var tail_rms:=sqrt(tail_energy/maxi(1,(frames.size()-tail_start)*2))
	print("PERIMETER WINDOW ",begin," PCM: frames=",frames.size()," peak=",peak," rms=",rms," final .35s rms=",tail_rms)
	check(frames.size()>20000 and (rms>.001 if audible else rms<.0001),"Visible west/south drops are audible; the northbound pan stays quiet (start "+str(begin)+")")
	check(peak<.5,"The wooden cascade retains ample mixer headroom")
	sounds.bank=original_bank
	for player in sounds.players: player.stop(); player.bus="Master"
	AudioServer.remove_bus(bus)
	AudioServer.set_bus_volume_db(0,master_volume)
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
	# Check all spawns and the dog-side pedestrian's complete route.
	var clear_hydrants:=true
	for walker in game.life.walkers:
		for hydrant in game.town.hydrants:
			clear_hydrants=clear_hydrants and walker.node.position.distance_to(hydrant)>1.2
		if walker!=game.life.walkers[-1]: continue
		for i in walker.path.size():
			var a: Vector3=walker.path[i]
			var b: Vector3=walker.path[(i+1)%walker.path.size()]
			for hydrant in game.town.hydrants:
				var p: Vector3=Geometry3D.get_closest_point_to_segment(hydrant,a,b)
				clear_hydrants=clear_hydrants and Vector2(p.x-hydrant.x,p.z-hydrant.z).length()>1.2
	check(clear_hydrants,"Walking NPCs spawn clear of hydrants and the dog's neighbour follows a clear route")
	var sounds: TownAudio=game.sounds
	check(sounds.players.size()==12 and sounds.players.all(func(p): return p is AudioStreamPlayer3D and p.playback_type==AudioServer.PLAYBACK_TYPE_STREAM),"Scene Foley keeps twelve pooled, spatially mixed stream voices")
	var grows: Array=sounds.bank.house_grow
	var hashes: Dictionary={}
	var clean_ends:=true
	for clip: AudioStreamWAV in grows:
		hashes[hash(clip.data)]=true
		clean_ends=clean_ends and clip.data.decode_s16(0)==0 and clip.data.decode_s16(clip.data.size()-2)==0 and clip.get_length()>1.2
	check(grows.size()==6 and hashes.size()==6 and clean_ends,"Six distinct longer house gestures have click-free sample boundaries")
	var varied:=true
	var previous:=-1
	for i in 12:
		sounds.time+=2
		sounds.play("house_grow",game.truck.global_position,1,0)
		varied=varied and sounds.last_house_variant!=previous
		previous=sounds.last_house_variant
	check(varied,"Consecutive houses never repeat the same growth gesture")
	for player in sounds.players: player.stop()
	for is_race in [false,true]:
		if is_race:
			game.intro.finish()
			game.travel.start(true)
			game.travel._swap_world()
		else:
			game.intro.start()
			game.intro.update(1)
			check(game.intro.clock>1.14 and game.intro.clock<1.16,"One real second advances the intro by about fifteen percent more")
			game.intro.finish()
			game.intro.start()
		var travel: PlayMatTravel=game.travel
		var same_falls:=true
		for item in travel.assembly:
			if not item.get("boundary",false): continue
			var at: Vector3=item.pivot-travel.assembly_origin
			var length: float=PlayMatTravel.ARRIVAL_END-(PlayMatTravel.RACE_ARRIVAL_START if is_race else PlayMatTravel.ARRIVAL_START)
			var seconds: float=item.span*length/PlayMatTravel.INTRO_PACE
			same_falls=same_falls and absf(seconds-PlayMatTravel.arrival_span(at,3,is_race)*length)<.001
		check(same_falls,"Tighter cascading starts preserve each individual block's fall duration")
		var growing:=travel.assembly_audio.filter(func(cue): return cue.kind=="house_grow")
		var blocks:=travel.assembly_audio.filter(func(cue): return cue.kind=="block_land")
		print("SCHEDULE ",is_race,": grows=",growing.size()," blocks=",blocks.size())
		check(growing.size()>=(2 if is_race else 4) and blocks.size()>40,"Both mats have deduplicated grow cues and a populated wooden perimeter cascade")
		var keys: Dictionary={}
		var unique:=true
		for cue in travel.assembly_audio:
			var key: String=str(cue.at)+cue.kind+str(cue.get("contact","impact"))
			unique=unique and not keys.has(key)
			keys[key]=true
		check(unique,"Material batches do not duplicate a house's growth sound")
		var impacts:=blocks.filter(func(cue): return cue.get("contact","")=="impact")
		var rebounds:=blocks.filter(func(cue): return cue.get("contact","")=="rebound")
		check(impacts.size()==rebounds.size() and rebounds.all(func(cue): return cue.strength<.4),"Each perimeter block has one impact and a quieter animation-timed rebound")
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
		# The Motorway audience now sits inward from the wooden perimeter.
		check(wood_count>=(12 if is_race else 15) and grow_count>=(2 if is_race else 4),"The camera sweep hears frequent wooden landings and rising buildings on both mats")
		check(sounds.listener.global_position.distance_to(game.camera.global_position)>100,"The intro listener stays near the toys instead of the distant clipping-safe lens")
		if not is_race:
			var south:=impacts.filter(func(cue): return cue.at.z>75 and cue.at.x< -60)
			var visible_south:=false
			for cue in south:
				var elapsed: float=PlayMatTravel.ARRIVAL_START+cue.progress*(PlayMatTravel.ARRIVAL_END-PlayMatTravel.ARRIVAL_START)
				travel.assembly_camera(elapsed,false)
				visible_south=visible_south or travel._perimeter_sound_in_view(cue.at,cue.progress)
			check(visible_south,"Southern corner landings can be heard before the camera turns north")
			var late:=impacts.filter(func(cue): return cue.progress>PlayMatTravel.arrival_progress(11.2))
			check(late.all(func(cue): return not travel._perimeter_sound_in_view(cue.at,cue.progress)),"All Maple perimeter cues stop once the camera turns north")
			travel.assembly_audio_index=0
			await perimeter_pcm(travel,sounds,9.3,true)
			await perimeter_pcm(travel,sounds,12.4,false)
		travel.finish_assembly()
	game.queue_free()
	await process_frame
	await process_frame
	print("INTRO AUDIO: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
