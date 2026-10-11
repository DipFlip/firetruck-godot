extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures+=1
func frame_npc(index: int) -> void:
	var actor: Node3D=game._npc_actors()[index]
	game.truck.global_position=actor.global_position+Vector3(0,.855,6)
	game.truck.reset_physics_interpolation()
	game.camera.position=actor.global_position+game.gameplay_camera_offset()
	game.camera.look_at(actor.global_position)
	game.dialogue_control.attention._process(.1)
func press() -> void:
	var event:=InputEventAction.new()
	event.action="jump"
	event.pressed=true
	game._unhandled_input(event)
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.stage=1 # The first dispatch has already been accepted.
	game.set_process(false)
	game.travel.set_process(false)
	var attention: NPCAttention=game.dialogue_control.attention
	for i in 4:
		frame_npc(i)
		game.truck.linear_velocity=Vector3(2,0,7)
		game._proximity_talk()
		check(attention.visible and attention.actor_index==i and not game.dialogue_active and not game.truck.freeze and game.truck.linear_velocity==Vector3(2,0,7),"Driving past quest NPC "+str(i)+" shows help without stopping the truck")
		check(game._approach_camera_subject(game.truck.global_position)==game.town.people[i],"The approach camera still notices quest NPC "+str(i))
		check(not game._talk_to_npc(i),"An automatic request cannot enter the blocking briefing")
		press()
		attention._process(.1)
		check(game.dialogue_control.interrupting and game.truck.freeze and not attention.visible,"Explicit talk enters the blocking briefing for NPC "+str(i))
		game.end_dialogue()
		frame_npc(i)
		game._proximity_talk()
		check(not attention.visible and not game.dialogue_active,"Spoken-to quest NPC "+str(i)+" stops announcing and cannot start an automatic repeat")
		press()
		check(game.dialogue_active and not game.dialogue_control.interrupting,"Space still opens a non-interrupting repeat conversation for NPC "+str(i))
		game.end_dialogue()
		game.truck.global_position=Vector3(0,.855,12)
		attention._process(.1)
		check(not attention.visible,"Driving away dismisses the help bubble")
	game.dog_done=true
	frame_npc(2)
	check(not attention.visible,"Completed jobs no longer ask for help")
	game.travel.start(true)
	game.travel.finish()
	var race: ToyRaceTrack=game.travel.race
	for i in [1,2,3]:
		frame_npc(i)
		game.truck.linear_velocity=Vector3.ZERO
		race.proximity_talk()
		check(attention.visible and attention.actor_index==i and not game.dialogue_active and not game.truck.freeze,"Motorway quest or challenge "+str(i)+" waits for explicit talk")
		press()
		check(game.dialogue_control.interrupting and game.truck.freeze,"Motorway explicit talk opens its blocking conversation")
		game.end_dialogue()
		frame_npc(i)
		race.proximity_talk()
		check(not attention.visible and not game.dialogue_active,"Spoken-to Motorway NPC "+str(i)+" no longer announces or automatically repeats")
		press()
		check(game.dialogue_active,"Space still talks to Motorway NPC "+str(i))
		game.end_dialogue()
		game.truck.global_position=ToyRaceTrack.ORIGIN+ToyRaceTrack.SPAWN
		attention._process(.1)
	game.travel.start(false)
	game.travel.finish()
	await physics_frame
	var body: StaticBody3D=game.atmosphere.fountain.get_node("FountainStone")
	check(body.get_child_count()==4 and body.collision_layer & game.truck.collision_mask,"The fountain's four stone tiers collide with the truck")
	var space:=game.get_world_3d().direct_space_state
	for probe in [Vector3(2.8,.06,0),Vector3(0,.4,0),Vector3(0,1.3,0),Vector3(.7,1.65,0)]:
		var at: Vector3=game.atmosphere.fountain.global_position+probe
		var query:=PhysicsRayQueryParameters3D.create(at+Vector3(4,0,0),at,1)
		var hit:=space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider==body,"Physics hits the visible stone at "+str(probe))
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
