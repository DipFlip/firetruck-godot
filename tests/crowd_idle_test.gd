extends SceneTree
# Check rendered joints/props, including the hand paths that used to enter torsos.
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func hand(actor: Node3D, rig: Dictionary) -> Vector3:
	return actor.to_local(rig.right.to_global(Vector3(0,-.62,0)))
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.call_timer=0
	game.intro.start()
	var cat: Node3D=game.town.cat
	var parts: Array=game.travel.assembly.filter(func(piece): return piece.node==cat or cat.is_ancestor_of(piece.node))
	check(parts.size()==1 and parts[0].node==cat and parts[0].drop and not parts[0].sprout,"Pippin assembles as one complete falling toy, with no independent ears, paws or tail")
	game.intro.finish()
	game.travel.start(true)
	game.travel.finish()
	var race: ToyRaceTrack=game.travel.race
	race.set_process(false)
	race.set_physics_process(false)
	var centre:=ToyRaceTrack.ORIGIN+ToyRaceTrack.WEST_STAND
	game.truck.global_position=centre+Vector3(0,.85,25)
	game.camera.position=centre+Vector3(7,7,18)
	game.camera.look_at(centre)
	game.camera.size=18
	race.running=false
	race.animation_clock=14
	for i in 60: race._update_audience(.016667)
	var audience:=race.spectators.filter(func(actor): return actor.position.distance_to(ToyRaceTrack.WEST_STAND)<12)
	check(audience.size()==9 and audience.all(func(actor): return hand(actor,race.actor_rigs[actor]).x>.48),"Resting audience hands stay outside their torsos")
	var actor: Node3D=audience[0]
	var rig: Dictionary=race.actor_rigs[actor]
	var before: Transform3D=rig.head.global_transform
	race.animation_clock=2
	for i in 60: race._update_audience(.016667)
	check(not rig.head.global_transform.is_equal_approx(before) and rig.eyes.get_parent()==rig.head,"Head turns move the complete face, ears and hair while eyes can still blink")
	var snack_actor: Node3D=audience.filter(func(person): return race.actor_rigs[person].snack!=null)[0]
	var snack_rig: Dictionary=race.actor_rigs[snack_actor]
	var index:=race.spectators.find(snack_actor)
	race.animation_clock=fposmod(9-index*2.37,20.0+(index%4)*1.7)
	for i in 90: race._update_audience(.016667)
	var grip: Vector3=snack_rig.right.to_global(Vector3(0,-.62,0))
	var mouth: Vector3=snack_rig.head.to_global(Vector3(0,.13,-.41))
	check(grip.distance_to(mouth)<.45 and (-snack_actor.global_basis.z).dot(grip-snack_actor.global_position)>.2,"A snack reaches the mouth in front of the body instead of entering the torso")
	check(snack_rig.snack.global_basis.y.normalized().dot(Vector3.UP)>.93 and snack_rig.snack.find_children("*","MeshInstance3D",true,false).any(func(mesh): return mesh.layers!=0),"The visible held snack keeps its own wrist pose and remains upright during a sip")
	var gestures: Dictionary={}
	for person in audience: gestures[roundi(race.actor_rigs[person].right.rotation.x*10)]=true
	check(gestures.size()>2,"Neighbour glances and refreshments are staggered across the audience")
	race.running=true
	game.truck.global_position=centre+Vector3(0,.85,5)
	for state in race.audience_states:
		state.age=.2
		state.next_cheer=race.animation_clock+10
	for i in 30: race._update_audience(.016667)
	check(audience.all(func(person): return hand(person,race.actor_rigs[person]).x>.8),"Cheering raises right arms outward, clear of faces and bodies")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
