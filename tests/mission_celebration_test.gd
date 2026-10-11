extends SceneTree

var game: Node3D
var failures:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+description)
	if not ok: failures+=1
func press(action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=true
	game._unhandled_input(event)
func capture(filename: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	for i in 40: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://output/playwright/"+filename+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.set_process(false)
	game.travel.set_process(false)
	game.rewards.set_process(false)
	game.truck.set_physics_process(false)
	game.truck.use_automation=true
	var rewards: JobRewards=game.rewards
	for index in [1,2,3]:
		var actor: Node3D=game.town.people[index]
		game.truck.global_position=actor.global_position+Vector3(0,.85,12)
		game._talk_to_npc(index,true)
		press("jump")
		var home_y:=actor.position.y
		var left: Vector3=actor.get_node("ArmLeft").rotation
		var right: Vector3=actor.get_node("ArmRight").rotation
		game.truck.linear_velocity=Vector3(3,0,4)
		game.truck.spraying=true
		var target: Vector3=[TownLayout.FIRE+Vector3.UP*1.8,TownLayout.DOG+Vector3.UP*.7,TownLayout.POOL+Vector3.UP*game.town.pool_water.position.y][index-1]
		game._water_hit(target,20)
		check(rewards.controls_locked() and game.dialogue_control.interrupting and game.truck.freeze and not game.truck.enabled and game.truck.linear_velocity==Vector3.ZERO and not game.truck.spraying,"Completion immediately holds controls and stops the hose for mission "+str(index))
		press("forward")
		press("jump")
		check(not game.dialogue_active and rewards.pending.size()==1 and game.truck.freeze,"Input cannot skip the jingle or start another conversation")
		rewards._process(.42)
		check(actor.position.y>home_y+.4 and absf(actor.get_node("ArmLeft").rotation.z)>2 and actor.get_node("ArmRight").rotation.z>2,"The neighbour jumps with both arms raised during the jingle")
		game.town._process(.016)
		check(actor.position.y>home_y+.4 and actor.get_node("ArmRight").rotation.z>2,"Idle greeting animation cannot overwrite the celebration")
		game.camera.position=actor.global_position+Vector3(16,18,22)
		game.camera.look_at(actor.global_position+Vector3.UP)
		game.camera.size=22
		await capture("mission-celebration-"+str(index))
		var remaining: float=rewards.pending[0].remaining
		game.paused=true
		rewards._process(1)
		check(rewards.pending[0].remaining==remaining and actor.position.y>home_y+.4,"Pause holds the jingle interval and celebration pose")
		game.paused=false
		rewards._process(1.4)
		check(game.dialogue_active and game.dialogue_actor==actor and game.dialogue_control.interrupting and game.truck.freeze and not game.truck.enabled,"The thank-you starts automatically even beyond nine metres, retaining the same control lock")
		check(is_equal_approx(actor.position.y,home_y) and actor.get_node("ArmLeft").rotation.is_equal_approx(left) and actor.get_node("ArmRight").rotation.is_equal_approx(right) and not actor.has_meta("mission_celebrating"),"The neighbour lands and restores their pose before speaking")
		await capture("mission-thanks-"+str(index))
		press("forward")
		check(not game.dialogue_active and not game.dialogue_control.interrupting and not game.truck.freeze and game.truck.enabled and game.truck.input_blocked_until_release,"Acknowledging the thank-you restores controls with held-input protection")
		game._talk_to_npc(index,true)
		check(game.dialogue_active and not game.dialogue_control.interrupting,"Later manual thank-you conversations remain non-interrupting")
		game.end_dialogue()
	game.cat_rescued=true
	game._after_cat_rescue()
	check(rewards.controls_locked() and game.truck.freeze,"Cat rescue uses the same uninterrupted celebration")
	rewards._process(2)
	check(game.dialogue_active and game.hud.speaker_key=="MAYA" and game.truck.freeze,"Maya's thank-you retains the rescue lock")
	press("jump")
	game.railway._start_engine()
	game.railway._physics_process(.7)
	check(rewards.controls_locked() and game.truck.freeze and game.railway.driver.get_node("ArmRight").rotation.z>2,"Train completion holds controls while Rowan raises his arms to board")
	rewards._process(2)
	game.railway._physics_process(3)
	check(game.dialogue_active and game.hud.speaker_key=="ROWAN" and game.truck.freeze,"Finishing boarding cannot dismiss Rowan's unread thank-you")
	press("jump")
	game.travel.start(true)
	game.travel.finish()
	var race: ToyRaceTrack=game.travel.race
	for index in [1,2]:
		var actor: Node3D=race.people[index]
		game.truck.global_position=actor.global_position+Vector3(0,.85,12)
		var job: Dictionary=race.jobs[index]
		var target: Vector3=job.fire.global_position+Vector3.UP*1.8 if job.has("fire") else ToyRaceTrack.ORIGIN+job.point
		race.water_hit(target,20)
		rewards._process(.42)
		race._process(.016)
		check(game.truck.freeze and actor.position.y>.4 and actor.get_node("ArmRight").rotation.z>2,"Motorway mission neighbours also jump with raised arms under a continuous lock")
		rewards._process(2)
		check(game.dialogue_active and game.dialogue_actor==actor and game.truck.freeze,"Motorway rewards automatically hand the same lock to the thank-you")
		press("jump")
		check(game.truck.enabled and not game.truck.freeze,"Motorway controls return after acknowledging the thank-you")
	rewards.celebrate("queue_first",race.people[1].global_position,"SAMI","First thanks!")
	rewards.celebrate("queue_second",race.people[2].global_position,"NORA","Second thanks!")
	rewards._process(2)
	check(game.dialogue_active and game.hud.speaker_key=="SAMI" and rewards.pending.size()==1,"Simultaneous completions queue their own celebrations and dialogues")
	press("jump")
	check(not game.dialogue_active and game.truck.freeze and not game.truck.enabled,"Acknowledging the first queued thanks cannot release controls before the next reward")
	rewards._process(.42)
	check(rewards.pending[0].remaining>1 and race.people[2].position.y>.4,"The second queued completion receives its full jingle and jump interval")
	rewards._process(2)
	press("jump")
	check(game.truck.enabled and not game.truck.freeze and rewards.pending.is_empty(),"The final queued acknowledgement restores driving")
	game.queue_free()
	await process_frame
	await process_frame
	print("MISSION CELEBRATION CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(1 if failures else 0)
