extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/firedriver-"+label+".png")
func toys_hidden() -> bool:
	for label: Label3D in game.railway.find_children("*","Label3D",true,false):
		if label.layers&game.camera.cull_mask: return false
	for rig in game.toy_blending.rigs:
		var art: Array=[rig.art]
		for source in rig.sources: art.append(source.part)
		for part: GeometryInstance3D in art:
			if not part.is_visible_in_tree(): continue
			if part.layers&game.camera.cull_mask: return false
			if part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and part.layers&game.sun.shadow_caster_mask: return false
	return true
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.call_timer=0
	check(game.toy_blending.rigs.all(func(rig): return rig.art.layers==(PlayMatTravel.RACE_TOYS if game.travel.race.is_ancestor_of(rig) else PlayMatTravel.MAPLE_TOYS)),"Replacement meshes inherit their map's render layer")
	for level in [25,0,10,15,50,75,100]:
		game.toy_blending.set_strength(level)
		for destination in [true,false]:
			var world:="Maple Bay" if destination else "Motorway"
			game.travel.start(destination)
			check(toys_hidden(),"%s %d%%: all toy art and shadows hide before the departure zoom"%[world,level])
			game.travel._update_transition(.4)
			check(toys_hidden() and game.travel.sequence_clock==0,"%s %d%%: the zoom-out hides toys before roll-up begins"%[world,level])
			if level==25 and destination: await capture("maple-departure-zoom")
			game.travel._update_transition(PlayMatTravel.DEPARTURE_LEAD+.8-game.travel.clock)
			check(toys_hidden() and game.travel.outgoing_mat.visible and not game.travel.swapped,"%s %d%%: no replacement art or shadows remain over the rolling carpet"%[world,level])
			check((game.playroom.floor_art.layers&game.camera.cull_mask)!=0,"The room floor stays visible during departure")
			if level==25 and destination: await capture("maple-departure-roll")
			game.travel.finish()
			check(not game.travel.toys_hidden and game.toy_blending.rigs.filter(func(rig): return rig.toy.is_visible_in_tree()).all(func(rig): return rig.art.visible==(level>0) and (rig.art.layers&game.camera.cull_mask)!=0),"%s %d%%: arrival restores the selected art and render masks"%[world,level])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
