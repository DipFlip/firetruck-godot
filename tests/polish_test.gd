extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+text)
	if not ok: failures+=1
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(220)
	check(game.hud.char_count>0 and game.hud.char_count<game.hud.full_text.length(),"Dialogue reveals progressively")
	game.interact()
	check(game.dialogue_active and game.hud.char_count==game.hud.full_text.length(),"First continue reveals the line without dismissing it")
	game.interact()
	check(not game.dialogue_active and game.stage==1,"Second continue advances the conversation")
	game.truck.use_automation=true
	game.truck.automated_drive=Vector2(0,-1)
	await frames(90)
	check(absf(game.truck.wheel_travel)>5,"Wheels animate from actual travel")
	var aligned:=true
	for w in game.truck.wheels:
		aligned=aligned and absf(w.basis.x.dot(Vector3.RIGHT))>0.999
	check(aligned,"Wheel axle stays on local X through full rotations")
	game.truck.automated_drive=Vector2(1,0)
	await frames(15)
	check(absf(game.truck.wheel_steers[0].rotation.y)>0.05 and game.truck.wheel_steers[1].rotation.y==0,"Only the front axle steers")
	game.truck.automated_drive=Vector2.ZERO
	game.talk("MAYA  /  MAPLE GREEN","Pippin! Oh, thank goodness you're here.",1)
	await frames(10)
	check(game.hud.portrait.texture is AtlasTexture and game.hud.portrait.texture.region.position.x>0,"Maya uses her own portrait")
	check(game.hud.syllables.size()==3 and game.hud.syllables[0].data.size()>1000,"Dialogue voice uses three smooth baked vowel syllables")
	game.talk("OLIVER  /  POOL PARTY","Can you help with the pool?",4)
	check(game.hud.portrait.texture.resource_path.ends_with("oliver.png"),"Oliver has a distinct portrait")
	check(game.town.people[0].get_node_or_null("Eyes")!=null,"Neighbours have animated facial features")
	game.queue_free()
	await process_frame
	await process_frame
	print("POLISH CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
