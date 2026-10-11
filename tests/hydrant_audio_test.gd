extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.set_process(false)
	game.travel.set_process(false)
	game.sounds.set_process(false)
	game.life.set_physics_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	var sounds: TownAudio=game.sounds
	for is_race in [false,true]:
		if is_race:
			game.travel.start(true)
			game.travel.finish()
		var hydrant: BreakableProp=game.travel.race.hydrant if is_race else game.interactions.hydrant_props[0]
		var source: PropGroundEffects=hydrant.ground_effect
		game.truck.global_position=hydrant.home.origin+Vector3(0,.855,6)
		hydrant.knock(Vector3.RIGHT*9)
		source._process(.016)
		sounds._process(.1)
		var emitter: Dictionary=sounds.hydrant_emitters[source]
		check(emitter.gain>0 and emitter.gain<1 and emitter.player.global_position.distance_to(hydrant.home.origin+Vector3.UP*.4)<.001,"A broken hydrant starts a fading spatial jet at its pipe on "+str(is_race))
		var before: int=sounds.counts.hydrant_jet
		for i in 20: sounds._process(.05)
		check(sounds.counts.hydrant_jet==before and emitter.gain>.99,"The continuous jet reuses one voice instead of restarting each frame")
		await physics_frame
		await process_frame
		game.paused=true
		var gain: float=emitter.gain
		sounds._process(.1)
		await physics_frame
		await process_frame
		check(emitter.player.stream_paused and emitter.gain==gain,"Pause holds both the jet voice and fade")
		game.paused=false
		game.truck.global_position+=Vector3.RIGHT*100
		for i in 24: sounds._process(.05)
		check(emitter.gain<.001 and not emitter.player.playing,"Leaving the hydrant fades its jet to silence")
		game.truck.global_position=hydrant.home.origin+Vector3(0,.855,6)
		sounds._process(.1)
		hydrant.age=hydrant.respawn_seconds
		hydrant._physics_process(.02)
		source._process(.02)
		for i in 24: sounds._process(.05)
		check(not hydrant.loose and emitter.gain<.001 and not emitter.player.playing,"Repair stops the water sound with a release fade")
	var soft:=true
	for kind in ["refill","hydrant_jet"]:
		for clip: AudioStreamWAV in sounds.bank[kind]:
			var energy:=0.0
			var difference:=0.0
			var previous:=0
			for i in clip.data.size()/2:
				var value:=clip.data.decode_s16(i*2)
				energy+=float(value)*value
				difference+=float(value-previous)*(value-previous)
				previous=value
			soft=soft and difference/maxf(1,energy)<.015 and clip.data.decode_s16(0)==0 and clip.data.decode_s16(clip.data.size()-2)==0
	check(soft,"Both water banks have little high-frequency energy and silent loop boundaries")
	check(TownAudio.LEVELS.refill<= -29 and TownAudio.LEVELS.hydrant_jet<= -27,"Water loops remain quiet in the scene mix")
	game.queue_free()
	await process_frame
	await process_frame
	print("HYDRANT AUDIO: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
