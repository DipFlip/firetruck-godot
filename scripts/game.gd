extends Node3D

var town: LittleTown
var truck: FireEngine
var camera: Camera3D
var hud: FireHUD
var stage := 0
var dialogue_active := false
var dialogue_next := 0
var dialogue_actor: Node3D
var dialogue_seen_in_view:=false
var dialogue_out_of_view_time:=0.0
var paused := false
var fire_progress := 0.0
var fire_feedback := 0.0
var fire_hud_percent:=-1
var fire_hud_on_target:=false
var dog_progress := 0.0
var pool_progress := 0.0
var dog_done := false
var pool_done := false
var rescued := false
var elapsed := 0.0
var toast_time := 0.0
var audio: AudioStreamPlayer
var stream: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var audio_phase := 0.0
var audio_clock := 0.0
const PHONE_RING_SECONDS:=3.0
var call_timer := PHONE_RING_SECONDS
var barbecue_discovered := false
var barbecue_notice_time := 0.0
var barbecue_briefed := false
var barbecue_call_delay := -1.0
var barbecue_ring_timer := -1.0
var barbecue_call_sent := false
const BARBECUE_CALL_DELAY := 20.0
const HYDRANT_REFILL_RADIUS:=6.75
var marker: MeshInstance3D
var job_label: Label3D
var camera_offset:=Vector3(16,23,29)
var sun: DirectionalLight3D
var gameplay_shadow_distance:=60.0
var camera_focus:=Vector3.ZERO
const TALK_CAMERA_SIZE := 18.8
const TALK_FULL_RADIUS:=18.0
const TALK_RELEASE_RADIUS:=36.0
const TALK_CAMERA_OFFSET := Vector3(22,16.5,26)
var camera_subject: Node3D
var conversation_blend := 0.0
var camera_blend_from := 0.0
var camera_blend_to := 0.0
var camera_transition_time := 1.0
var music: AudioStreamPlayer
var music_muted:=false
var water_audio: AudioStreamPlayer
var hose_volume := 0.0
var camera_trauma := 0.0
var proximity_latches: Dictionary = {}
var rescue_running := false
var rescue_tween: Tween
var cat_cuddle_tween: Tween
var in_main_menu:=false
var cat_ladder_event: LadderEvent
var cat_rescued:=false
var cat_home:=Vector3.ZERO
var cat_home_rotation:=Vector3.ZERO
var cat_paws: Array[Node3D]=[]
var life: TownLife
var gardens: TownGardens
var atmosphere: TownAtmosphere
var surfaces: DriveSurfaces
var pool_basin: PoolBasin
var ramps: TownRamps
var rewards: JobRewards
var interactions: TownInteractions
var refill_hose: RefillHose
var web_controls: WebControls
var loading:=false
var pool_shader_warmed:=false
var batched_decorations:=0
var merged_scenery:=0
var conversation_pan:=0.0
var railway: NorthlineRailway
var dog_puddle: DogPuddle
var intro: TownIntro
var sounds: TownAudio
var barbecue: Barbecue
var miniature: MiniatureLook
var playroom: Playroom
var travel: PlayMatTravel
var controls: ControlPrompts

func _ready() -> void:
	# Frame-driven scenery and camera are not physics-interpolated a second time.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	_setup_input()
	controls=ControlPrompts.new()
	add_child(controls)
	_setup_light()
	town=$MapleBay
	town.people[3].position=TownLayout.OLIVER
	truck=FireEngine.new()
	truck.name="Engine04"
	truck.position=Vector3(0,1,12)
	add_child(truck)
	truck.hit_receiver = _water_hit
	truck.aim_assist = _assisted_water_target
	truck.bump.connect(func(strength: float): camera_trauma=maxf(camera_trauma,strength))
	town.truck=truck
	cat_home=town.cat.global_position
	cat_home_rotation=town.cat.rotation
	for child in town.cat.get_children():
		if child is MeshInstance3D and is_equal_approx(child.position.y,.2): cat_paws.append(child)
	cat_ladder_event=LadderEvent.new()
	cat_ladder_event.name="PippinLadderEvent"
	cat_ladder_event.availability=func(): return stage==1 and not paused and not rescue_running and not cat_rescued
	cat_ladder_event.activated.connect(_on_cat_ladder_reached)
	town.cat.add_child(cat_ladder_event)
	camera=Camera3D.new()
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=25.8
	camera.far=250
	add_child(camera)
	camera.position=truck.position+camera_offset
	camera.look_at(truck.position)
	camera.current=true
	camera_focus=truck.position
	truck.camera=camera
	miniature=MiniatureLook.new()
	miniature.game=self
	add_child(miniature)
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	hud=FireHUD.new()
	hud.game=self
	canvas.add_child(hud)
	controls.mode_changed.connect(func(_mode): hud.refresh_controls())
	truck.empty_spray.connect(hud.on_empty_spray)
	marker=MeshInstance3D.new()
	var ring:=TorusMesh.new()
	ring.inner_radius=1.78
	ring.outer_radius=1.83
	marker.mesh=ring
	marker.material_override=TownProps.material(Color("e5b378"),true)
	marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	job_label=TownProps.label(self,Vector3(12,4,-7),"01  /  A CAT IN A TREE",28)
	_setup_audio()
	sounds=TownAudio.new()
	sounds.game=self
	add_child(sounds)
	barbecue=Barbecue.new()
	barbecue.town=town
	add_child(barbecue)
	atmosphere=TownAtmosphere.new()
	atmosphere.game=self
	add_child(atmosphere)
	life=TownLife.new()
	life.game=self
	add_child(life)
	life.clear_start_area()
	gardens=TownGardens.new()
	gardens.game=self
	add_child(gardens)
	pool_basin=PoolBasin.new()
	pool_basin.game=self
	add_child(pool_basin)
	surfaces=DriveSurfaces.new()
	add_child(surfaces)
	surfaces.register(town)
	surfaces.register(atmosphere)
	ramps=TownRamps.new()
	add_child(ramps)
	rewards=JobRewards.new()
	rewards.game=self
	add_child(rewards)
	interactions=TownInteractions.new()
	interactions.game=self
	add_child(interactions)
	refill_hose=RefillHose.new()
	refill_hose.game=self
	add_child(refill_hose)
	railway=NorthlineRailway.new()
	railway.game=self
	add_child(railway)
	truck.drive_guide=railway.guide_push
	playroom=Playroom.new()
	add_child(playroom)
	var dust:=RoomDust.new()
	dust.game=self
	add_child(dust)
	dog_puddle=DogPuddle.new()
	dog_puddle.game=self
	add_child(dog_puddle)
	intro=TownIntro.new()
	intro.game=self
	add_child(intro)
	batched_decorations=TownProps.batch_decorations(atmosphere)
	var animated: Array[Node3D]=[town.cat,town.dog,town.pool_water]
	animated.append_array(town.people)
	animated.append_array(town.flames)
	animated.append_array(atmosphere.fountain_drops)
	animated.append_array(atmosphere.embers)
	merged_scenery=TownProps.merge_fixed_geometry(town,animated)+TownProps.merge_fixed_geometry(atmosphere,animated)
	travel=PlayMatTravel.new()
	travel.game=self
	add_child(travel)
	web_controls=WebControls.new()
	web_controls.game=self
	add_child(web_controls)
	if OS.has_feature("web"):
		loading=true
		var warmup:=WebWarmup.new()
		warmup.game=self
		add_child(warmup)
		warmup.call_deferred("run")
	elif DisplayServer.get_name()!="headless" and not OS.get_cmdline_args().has("--script"):
		intro.call_deferred("start")

func _setup_input() -> void:
	var bindings := {"left":KEY_A,"right":KEY_D,"forward":KEY_W,"back":KEY_S,"jump":KEY_SPACE,"brake":KEY_SHIFT,"interact":KEY_E,"continue":KEY_ENTER,"pause":KEY_ESCAPE,"aim_left":KEY_LEFT,"aim_right":KEY_RIGHT,"aim_up":KEY_UP,"aim_down":KEY_DOWN,"map":KEY_TAB,"music":KEY_M}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event:=InputEventKey.new()
		event.physical_keycode=bindings[action]
		InputMap.action_add_event(action,event)
	InputMap.add_action("spray")
	var mouse:=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	InputMap.action_add_event("spray",mouse)

func _setup_light() -> void:
	var compatibility:=RenderingServer.get_current_rendering_method()=="gl_compatibility"
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	# Daylight through a large window: near-white sun with a hint of warmth.
	sun.light_color=Color("fff7ec")
	# Compatibility blends shadowed lighting differently from Forward+.
	# Keep browser highlights below the pale shoulder of the ACES curve.
	sun.light_energy=.22 if compatibility else .95
	# A window is a broad source: soft penumbras, and shadows filled in by the
	# light bouncing around the room rather than going dark.
	sun.light_angular_distance=2.2
	sun.shadow_opacity=.72
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=60 if compatibility else 100
	gameplay_shadow_distance=sun.directional_shadow_max_distance
	# The fixed orthographic camera does not need four perspective shadow splits.
	if compatibility: sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	# Bounce light from the opposite wall and ceiling: broad, shadowless, cool.
	var bounce:=DirectionalLight3D.new()
	bounce.rotation_degrees=Vector3(-62,148,0)
	bounce.light_color=Color("e6eefa")
	bounce.light_energy=.07 if compatibility else .28
	bounce.light_specular=.15
	add_child(bounce)
	var world:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	# Pale painted walls beyond the floor; strong soft fill from the room.
	env.background_color=Color("e9e4da")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("eef1f5")
	env.ambient_light_energy=0.42
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.ssao_enabled=not compatibility
	env.ssao_radius=1.1
	env.ssao_intensity=1.6
	env.ssao_light_affect=0.35
	env.glow_enabled=not compatibility
	env.glow_intensity=0.12
	env.glow_bloom=0.0
	env.adjustment_enabled=true
	env.adjustment_saturation=1.14 if compatibility else 1.08
	env.adjustment_contrast=1.04 if compatibility else 1.0
	env.tonemap_exposure=.75 if compatibility else .92
	world.environment=env
	add_child(world)

func objective() -> Vector3:
	if railway and railway.briefed and not railway.started: return railway.engine.position+Vector3(-4.5,0,0)
	if stage<=1: return TownLayout.MAYA
	if stage==2: return TownLayout.LEO
	return TownLayout.FIRE

func navigation_active() -> bool:
	if travel and (travel.in_race or travel.active): return false
	return stage>0 and stage<4 or railway!=null and railway.briefed and not railway.started

func talk(speaker: String, words: String, next: int) -> void:
	dialogue_active=true
	dialogue_next=next
	var index: int={"MAYA":0,"LEO":1,"JUNE":2,"OLIVER":3}.get(speaker.get_slice("  /",0),-1)
	dialogue_actor=town.people[index] if index>=0 else null
	if speaker.begins_with("ROWAN") and railway: dialogue_actor=railway.driver
	if travel and travel.in_race:
		var race_index:=ToyRaceTrack.NAMES.find(speaker.get_slice("  /",0))
		dialogue_actor=travel.race.people[race_index] if race_index>=0 else null
	dialogue_seen_in_view=false
	dialogue_out_of_view_time=0
	if dialogue_actor: camera_subject=dialogue_actor
	_set_conversation_camera(dialogue_actor!=null)
	# These are instructions, not choices: a neighbour's job remains available
	# if the player drives away halfway through hearing about it.
	stage=next
	_update_mission()
	hud.begin_dialogue(speaker,words)
	truck.enabled=not paused and not rescue_running

func end_dialogue(keep_camera: bool=false) -> void:
	if dialogue_active and dog_done and hud.speaker_key=="JUNE": sounds.play("woof",town.dog.global_position,.85,1.0)
	dialogue_active=false
	dialogue_actor=null
	if not keep_camera: _set_conversation_camera(false)
	hud.dialogue_panel.hide()
	# Each syllable is only 65 ms and already fades to silence. Let the final
	# one finish: stopping halfway through its waveform makes an audible tick.
	truck.enabled=not paused and not rescue_running

func _set_conversation_camera(active: bool) -> void:
	var target:=1.0 if active else 0.0
	if target==camera_blend_to: return
	camera_blend_from=conversation_blend
	camera_blend_to=target
	camera_transition_time=0.0

func phone_ringing() -> bool:
	if travel and (travel.in_race or travel.active): return false
	if intro and intro.active: return false
	return call_timer>0 or barbecue_ring_timer>=0

func _discover_barbecue() -> void:
	if barbecue_call_sent and dialogue_active and hud.speaker_key=="DISPATCH": end_dialogue()
	if barbecue_discovered: return
	barbecue_discovered=true
	barbecue_call_delay=-1
	barbecue_ring_timer=-1
	if fire_progress<1 and (cat_rescued or stage==2):
		stage=3
		_update_mission()

func _check_barbecue_discovery(dt: float) -> void:
	if barbecue_discovered: return
	# A brief drive past the neighbourhood is not acknowledgement of the job.
	# Talking to Leo or spraying the fire still discovers it immediately.
	var close:=truck.global_position.distance_to(TownLayout.FIRE)<8
	var speed:=Vector2(truck.linear_velocity.x,truck.linear_velocity.z).length()
	if not close or speed>5:
		barbecue_notice_time=0
		return
	var query:=PhysicsRayQueryParameters3D.create(truck.cannon.global_position,TownLayout.FIRE+Vector3.UP*1.7,1,[truck.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		barbecue_notice_time=0
		return
	barbecue_notice_time+=dt
	if barbecue_notice_time>=1.25: _discover_barbecue()

func _update_dispatch(dt: float) -> void:
	if call_timer>0:
		call_timer=maxf(0,call_timer-dt)
		if call_timer==0:
			if dialogue_active or rescue_running or rewards.playing_reward(): call_timer=.1
			else: talk("DISPATCH  /  INCOMING CALL","Morning, rookie! Quiet shift today... except Maya's cat thinks he's a bird. Follow the arrow to Maple Green. You've got this.",1)
	if barbecue_discovered or fire_progress>=1:
		barbecue_call_delay=-1
		barbecue_ring_timer=-1
		return
	if barbecue_call_delay>=0:
		barbecue_call_delay=maxf(0,barbecue_call_delay-dt)
		if barbecue_call_delay==0 and not rescue_running and not rewards.playing_reward():
			barbecue_call_delay=-1
			barbecue_ring_timer=PHONE_RING_SECONDS
	elif barbecue_ring_timer>=0:
		barbecue_ring_timer=maxf(0,barbecue_ring_timer-dt)
		# A finished rescue thank-you can hand the channel to the next call.
		if barbecue_ring_timer==0 and dialogue_active and hud.speaker_key=="MAYA" and cat_rescued and hud.char_count==hud.full_text.length(): end_dialogue()
		if barbecue_ring_timer==0 and not dialogue_active and not rescue_running and not rewards.playing_reward():
			barbecue_ring_timer=-1
			barbecue_call_sent=true
			talk("DISPATCH  /  INCOMING CALL","Unit 04, we've had a call from Willow Lane. Leo's barbecue has flared up! Head east and lend him a hose.",2)
			hud.auto_close_delay=-1 # Keep the job visible until acknowledged or discovered.

func _unhandled_input(event: InputEvent) -> void:
	if loading or in_main_menu or (travel and travel.active): return
	if event is InputEventKey and event.echo: return
	if intro and intro.active:
		if event.is_action_pressed("jump") or event.is_action_pressed("continue") or (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			intro.finish()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		paused=not paused
		if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckPause(%s)" % ("true" if paused else "false"))
		hud.pause_panel.visible=paused
		truck.enabled=not paused and not rescue_running
		truck.freeze=paused or rescue_running
		truck.set_physics_process(not paused)
		town.set_process(not paused)
		if rescue_tween and rescue_tween.is_valid() and rescue_tween.is_running() and paused: rescue_tween.pause()
		elif rescue_tween and rescue_tween.is_valid() and not paused: rescue_tween.play()
		if cat_cuddle_tween and cat_cuddle_tween.is_valid() and paused: cat_cuddle_tween.pause()
		elif cat_cuddle_tween and cat_cuddle_tween.is_valid() and not paused: cat_cuddle_tween.play()
	if paused: return
	if event.is_action_pressed("map"): hud.map_open=not hud.map_open
	if event.is_action_pressed("music"):
		music_muted=not music_muted
		if music: music.volume_db=-80 if music_muted else -25
	if event.is_action_pressed("recover"):
		end_dialogue()
		if rescue_running: _cancel_cat_rescue()
		truck.reset_truck()
		if travel and travel.in_race:
			travel.race.running=false
			travel.race.checkpoint=0
			travel.race.checkpoint_flag.hide()
		toast("Back at the paddock." if travel and travel.in_race else "Back at the station. Ready when you are.")
	if event.is_action_pressed("interact"):
		if truck.ladder_deployed: truck.retract_ladder()
		else: truck.extend_ladder()
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if _pointer_talk(event.position):
			truck.pointer_spray_blocked=true
			get_viewport().set_input_as_handled()
			return
	# In the basin Space is always a jump, including while Oliver's previous
	# conversation is still visible. The mobile jump control uses this path too.
	if event.is_action_pressed("jump") and not (travel and travel.in_race) and pool_basin.contains_truck():
		if dialogue_actor==town.people[3]: end_dialogue()
		return
	if (event.is_action_pressed("continue") or event.is_action_pressed("jump")) and (dialogue_active or _nearest_npc()>=0):
		if event.is_action_pressed("jump"):
			truck.jump_blocked_until_release=true
			truck.charge=0
		interact()
		get_viewport().set_input_as_handled()

func interact() -> void:
	if paused: return
	if dialogue_active:
		if not hud.advance_text(): return
		end_dialogue()
		return
	var index:=_nearest_npc()
	if index>=0: _talk_to_npc(index,true)

func _nearest_npc() -> int:
	var index:=-1
	var nearest:=9.0
	if pool_basin and pool_basin.contains_truck(): return -1
	var actors:=_npc_actors()
	for i in actors.size():
		if not actors[i].visible: continue
		var distance:=truck.global_position.distance_to(actors[i].global_position)
		if distance<nearest:
			nearest=distance
			index=i
	return index

func _npc_actors() -> Array[Node3D]:
	if travel and travel.in_race: return travel.race.people
	var actors: Array[Node3D]=[]
	actors.append_array(town.people)
	if railway and not railway.boarded: actors.append(railway.driver)
	return actors

func npc_screen_rect(actor: Node3D) -> Rect2:
	var bounds:=Rect2(camera.unproject_position(actor.global_position),Vector2.ZERO)
	for x in [-.7,.7]:
		for y in [0.0,2.7]:
			for z in [-.5,.5]: bounds=bounds.expand(camera.unproject_position(actor.global_position+Vector3(x,y,z)))
	return bounds

func npc_in_view(actor: Node3D) -> bool:
	return actor.is_visible_in_tree() and not camera.is_position_behind(actor.global_position+Vector3.UP) and hud.get_viewport_rect().intersects(npc_screen_rect(actor))

func _pointer_talk(point: Vector2) -> bool:
	if dialogue_active and Rect2(hud.dialogue_panel.position,hud.dialogue_panel.size).has_point(point):
		interact()
		return true
	var actors:=_npc_actors()
	for i in actors.size():
		if not npc_in_view(actors[i]) or not npc_screen_rect(actors[i]).grow(10).has_point(point): continue
		if dialogue_active and dialogue_actor==actors[i]: interact(); return true
		return _talk_to_npc(i,true)
	return false

func _proximity_talk() -> void:
	if pool_basin and pool_basin.contains_truck(): return
	var positions := [TownLayout.MAYA,TownLayout.LEO,TownLayout.JUNE,TownLayout.OLIVER]
	for i in positions.size():
		var distance: float=truck.global_position.distance_to(positions[i])
		if distance>10.5: proximity_latches.erase(i)
		if distance>8.0 or proximity_latches.has(i) or dialogue_active or rescue_running: continue
		_talk_to_npc(i)
	if railway and not railway.boarded and not dialogue_active and not rescue_running and truck.position.distance_to(railway.driver.position)<8:
		railway.talk_to_driver()

func _talk_to_npc(i: int, manual: bool=false) -> bool:
	if travel and travel.in_race: return travel.race.talk_to_person(i)
	if i==4: return railway.talk_to_driver(manual)
	if paused or rescue_running or rewards.waiting_for(["MAYA","LEO","JUNE","OLIVER"][i]): return false
	match i:
		0:
			if cat_rescued:
				if not manual: return false
				talk("MAYA  /  MAPLE GREEN","Thank you again! Pippin's staying on the ground today.",stage)
			elif stage==1 and (not rescued or manual):
				talk("MAYA  /  MAPLE GREEN","Oh, thank goodness! Pippin climbed up there and forgot how to be a cat. "+_ladder_instruction()+". Drive its tip close to Pippin. He'll hop on and climb down. Gently, please!",1)
				rescued=true
				sounds.play("meow",town.cat.global_position,.85,3)
			else: return false
		1:
			if fire_progress>=1:
				if not manual: return false
				talk("LEO  /  WILLOW LANE","Thanks again for saving the afternoon! Sandwiches from now on.",stage)
			elif not barbecue_briefed or manual:
				_discover_barbecue()
				barbecue_briefed=true
				talk("LEO  /  A LITTLE TOO WELL DONE","I was going for smoky flavour, not actual smoke! Aim at the barbecue and hold the hose. {brake} will keep you steady.",3 if cat_rescued or stage in [2,3,5] else stage)
			else: return false
		2:
			talk("JUNE  /  BISCUIT'S BIG DAY", "He's spotless. Thank you!" if dog_done else "Biscuit found every puddle in town. Could you give him a gentle rinse? Aim the hose at him until he's clean.",stage)
		3:
			talk("OLIVER  /  POOL PARTY", "Pool party saved. You're always welcome here!" if pool_done else "The kids are coming over, and the pool is empty! Could you fill it? Spray into the tiled pool and watch the water rise.",stage)
	proximity_latches[i]=true
	return true

func _process(dt: float) -> void:
	if not is_instance_valid(truck): return
	_audio_update(dt)
	if paused or loading or (travel and travel.active): return
	if intro and intro.active:
		intro.update(dt)
		return
	elapsed+=dt
	fire_feedback=maxf(0,fire_feedback-dt*2.2)
	town.water_response=fire_feedback
	var ahead:=Vector3(truck.linear_velocity.x,0,truck.linear_velocity.z)*0.27
	# Follow the same interpolated chassis pose that the renderer displays.
	var rendered_truck_position:=truck.get_global_transform_interpolated().origin
	var focus:=rendered_truck_position+ahead
	camera_transition_time=minf(1.0,camera_transition_time+dt)
	conversation_blend=lerpf(camera_blend_from,camera_blend_to,smoothstep(0.0,1.0,camera_transition_time))
	if is_instance_valid(camera_subject):
		# Release the camera's attention gradually as the truck leaves, so the
		# neighbour can naturally leave the screen instead of being held in view.
		var separation:=rendered_truck_position.distance_to(camera_subject.global_position)
		var attention:=.52*(1-smoothstep(TALK_FULL_RADIUS,TALK_RELEASE_RADIUS,separation))
		var subject:=camera_subject.global_position
		if camera_subject==town.people[0] and not cat_rescued:
			subject=subject.lerp(town.cat.global_position,.38)
		var conversation_focus:=rendered_truck_position.lerp(subject,attention)+Vector3.UP*.25+ahead*.1
		focus=focus.lerp(conversation_focus,conversation_blend)
	camera_focus=camera_focus.lerp(focus,1-exp(-4.5*dt))
	camera_trauma=maxf(0,camera_trauma-dt*1.5)
	var shake:=camera_trauma*camera_trauma
	var offset:=gameplay_camera_offset().lerp(gameplay_camera_offset(true),conversation_blend)
	camera.global_position=camera_focus+offset+Vector3(sin(elapsed*63)*.16,sin(elapsed*79)*.12,cos(elapsed*53)*.08)*shake
	camera.far=500 if travel and travel.in_race else 250
	sun.directional_shadow_max_distance=gameplay_shadow_distance+maxf(0,offset.length()-camera_offset.length())
	camera.look_at(camera_focus)
	camera.rotation.z+=sin(elapsed*47)*0.004*shake
	camera.size=lerpf(25.8,_talk_camera_size(),conversation_blend)
	conversation_pan=lerpf(conversation_pan,_conversation_pan_target(),1-exp(-4*dt))
	camera.v_offset=conversation_pan
	if dialogue_active and is_instance_valid(dialogue_actor):
		if npc_in_view(dialogue_actor):
			dialogue_seen_in_view=true
			dialogue_out_of_view_time=0
		elif dialogue_seen_in_view:
			dialogue_out_of_view_time+=dt
			if dialogue_out_of_view_time>.7: end_dialogue()
	if travel and travel.in_race:
		marker.hide()
		job_label.hide()
		if toast_time>0:
			toast_time-=dt
			if toast_time<=0: hud.toast_label.text=""
		travel.race.proximity_talk()
		hud.set_prompt("")
		return
	_check_barbecue_discovery(dt)
	_update_dispatch(dt)
	if toast_time>0:
		toast_time-=dt
		if toast_time<=0: hud.toast_label.text=""
	marker.visible=navigation_active()
	job_label.visible=false
	marker.position=objective()+Vector3.UP*0.12
	marker.scale=Vector3.ONE*(1+sin(elapsed*3)*0.06)
	job_label.position=objective()+Vector3.UP*(4.3+sin(elapsed*2)*0.15)
	_proximity_talk()
	var refill_source: BreakableProp=null
	var refill_distance:=HYDRANT_REFILL_RADIUS
	# Activation uses the rigid body centre; the rear socket is visual only.
	var refill_center:=truck.global_position
	for i in town.hydrants.size():
		var h:=town.hydrants[i]
		if interactions.hydrant_props[i].loose: continue
		var distance:=refill_center.distance_to(h)
		if truck.water<truck.tank_capacity and distance<refill_distance:
			refill_source=interactions.hydrant_props[i]
			refill_distance=distance
	refill_hose.update(refill_source,dt)
	if refill_hose.active: truck.water=minf(truck.tank_capacity,truck.water+dt*25)
	var prompt:=""
	# The hint is a control reminder after Maya's briefing, not a status feed.
	if stage==1 and rescued and not cat_rescued and not dialogue_active and not rescue_running and not truck.ladder_deployed and truck.global_position.distance_to(TownLayout.MAYA)<12:
		prompt=_ladder_instruction()
	hud.set_prompt(prompt)
	if stage==3:
		var percent:=int(fire_progress*100)
		var on_target:=fire_feedback>.1
		if percent!=fire_hud_percent or on_target!=fire_hud_on_target:
			fire_hud_percent=percent
			fire_hud_on_target=on_target
			hud.heading_label.text="ON TARGET  /  COOLING" if on_target else "02  /  HOSE AT THE READY"
			hud.detail_label.text="Extinguish the barbecue  ·  %d%%\n" % percent + ("Keep it there!" if on_target else ControlPrompts.plain("Aim near the flames · {brake} to brace."))

func _ladder_instruction() -> String:
	return "Press {interact} to extend the ladder"

func gameplay_camera_offset(talking: bool=false) -> Vector3:
	var offset:=TALK_CAMERA_OFFSET if talking else camera_offset
	# Keep the orthographic framing, but place the lens beyond the foreground
	# furniture when following the truck along the southern mat edge.
	return offset.normalized()*160 if travel and travel.in_race else offset

func _talk_camera_size() -> float:
	if not is_instance_valid(camera_subject): return TALK_CAMERA_SIZE
	var distance:=truck.global_position.distance_to(camera_subject.global_position)
	var frame:=hud.truck_screen_rect().merge(hud.conversation_subject_rect())
	var extent:=frame.size.y*camera.size/maxf(1,hud.size.y)
	var available:=maxf(100,hud.size.y-hud.dialogue_panel.size.y-118)
	var close_size:=maxf(TALK_CAMERA_SIZE,extent*hud.size.y/available)
	return lerpf(close_size,25.8,smoothstep(TALK_FULL_RADIUS,TALK_RELEASE_RADIUS,distance))

func _conversation_pan_target() -> float:
	if not is_instance_valid(camera_subject) or conversation_blend<=0: return 0.0
	# Keep the truck below centre, leaving the upper half for the neighbour,
	# the tree pet, and their above-head speech balloon.
	var p:=truck.get_global_transform_interpolated().origin
	var screen:=camera.unproject_position(p)
	var pixels_per_unit:=absf(camera.unproject_position(p+camera.global_basis.y).y-screen.y)
	var unshifted:=screen.y-camera.v_offset*pixels_per_unit
	var truck_rect:=hud.truck_screen_rect()
	var scene_top:=minf(truck_rect.position.y,hud.conversation_subject_rect().position.y)-camera.v_offset*pixels_per_unit
	var below_centre:=hud.size.y*.64-unshifted
	var balloon_space:=76+hud.dialogue_panel.size.y+26-scene_top
	var max_shift:=hud.size.y-22-(truck_rect.end.y-camera.v_offset*pixels_per_unit)
	return minf(max_shift,maxf(below_centre,balloon_space))/maxf(.01,pixels_per_unit)*conversation_blend

func return_to_main_menu() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.firetruckMainMenu()")
		return
	in_main_menu=true
	paused=true
	end_dialogue()
	truck.freeze=true
	truck.enabled=false
	hud.pause_panel.hide()
	hud.main_menu.show()

func _assisted_water_target(origin: Vector3, requested: Vector3) -> Variant:
	if travel and travel.in_race: return travel.race.aim_target(origin,requested)
	var aim:=Vector3(requested.x-origin.x,0,requested.z-origin.z).normalized()
	if aim.length()<.1: return null
	var targets: Array[Dictionary]=[]
	if fire_progress<1 and (stage==3 or barbecue_discovered): targets.append({"point":TownLayout.FIRE+Vector3.UP*1.7,"radius":4.6})
	if not dog_done: targets.append({"point":TownLayout.DOG+Vector3.UP*.7,"radius":4.3})
	if not pool_done:
		# Select safe landing points well inside the basin, rather than the rim.
		# Multiple candidates let the arc clear a nearby wall or the pool ladder.
		var center:=TownLayout.POOL+Vector3.UP*(town.pool_water.position.y+.06)
		var low:=center-Vector3(3.0,0,1.05)
		var high:=center+Vector3(3.0,0,1.05)
		var cursor:=Vector3(requested.x,center.y,requested.z).clamp(low,high)
		var near:=Vector3(origin.x,center.y,origin.z).clamp(low,high)
		for point in [cursor,center,near]: targets.append({"point":point,"radius":5.4})
	if dog_puddle and dog_puddle.clean<1:
		targets.append({"point":TownLayout.DOG+Vector3(1.1,.10,.6),"radius":2.0})
	for car in life.cars:
		if car.recovery>=0 or car.node.position.distance_to(origin)>FireEngine.AIM_RANGE+3: continue
		var point: Vector3=car.node.global_position+Vector3.UP*.95
		# A predicted landing point must not make a hidden car targetable through a wall.
		if not truck.shot_is_clear(origin,point,car.node.get_rid()): continue
		var shot:=truck.solve_shot(origin,point,truck.linear_velocity)
		point+=car.node.linear_velocity*float(shot.get("time",.35))
		targets.append({"point":point,"radius":3.8,"receiver":car.node.get_rid()})
	var best: Variant=null
	var best_score:=INF
	for target in targets:
		var point: Vector3=target.point
		var planar:=Vector3(point.x-origin.x,0,point.z-origin.z)
		var ahead:=planar.dot(aim)
		if planar.length()>FireEngine.AIM_RANGE or ahead<=0 or planar.normalized().dot(aim)<cos(deg_to_rad(42)): continue
		# Compare horizontal aim error over the full hose range. Height differences
		# (especially an empty recessed pool) must not make acquisition harder.
		var error: float=(planar-aim*ahead).length()
		if error>target.radius: continue
		var cursor_error:=Vector2(point.x-requested.x,point.z-requested.z).length()
		var score:=error+cursor_error*.12
		if score>=best_score or not truck.shot_is_clear(origin,point,target.get("receiver",RID())): continue
		best_score=score
		best=point
	return best

func _water_hit(point: Vector3, amount: float) -> bool:
	if paused or (travel and travel.active): return false
	if travel and travel.in_race: return travel.race.water_hit(point,amount)
	var consumed := life.water_hit(point,amount)
	if dog_puddle: consumed=dog_puddle.water_hit(point,amount) or consumed
	if fire_progress<1 and point.distance_to(TownLayout.FIRE+Vector3.UP*1.8)<1.8:
		_discover_barbecue()
		consumed = true
		fire_feedback=1.0
		sounds.fire_hit(amount)
		fire_progress=minf(1,fire_progress+amount*(0.22/0.60))
		town.fire_amount=1-fire_progress
		if fire_progress>=1:
			stage=4 if cat_rescued or stage in [2,3,4] else 1
			_update_mission()
			rewards.celebrate("fire",TownLayout.FIRE+Vector3.UP*1.2,"LEO","You saved the afternoon! Thank you! I think I'll stick to sandwiches for the rest of the party.")
	if not dog_done and point.distance_to(TownLayout.DOG+Vector3.UP*0.7)<1.4:
		consumed = true
		sounds.play("dog_wash",town.dog.global_position,.7,1.2)
		dog_progress=minf(1,dog_progress+amount*0.60)
		if dog_progress>=1:
			dog_done=true
			if stage==4: _update_mission()
			for child in town.dog.get_children():
				if child is MeshInstance3D: child.material_override=TownProps.material(Color("e9c58b"))
			rewards.celebrate("dog",TownLayout.DOG+Vector3.UP*.5,"JUNE","Look at that shiny coat! Thank you — Biscuit's ready for cuddles again.")
	if not pool_done and absf(point.x-TownLayout.POOL.x)<4.4 and absf(point.z-TownLayout.POOL.z)<2.4 and point.y<=town.pool_water.position.y+.12:
		consumed = true
		pool_progress=minf(1,pool_progress+amount*0.32)
		pool_basin.set_fill(pool_progress)
		truck._splash(Vector3(point.x,town.pool_water.position.y,point.z),Vector3.UP,true)
		if pool_progress>=1:
			pool_done=true
			if stage==4: _update_mission()
			rewards.celebrate("pool",TownLayout.POOL+Vector3.UP*.15,"OLIVER","It's perfect! Thank you for saving our pool party. You're always welcome for a swim!")
	return consumed

func _update_mission() -> void:
	fire_hud_percent=-1
	match stage:
		1:
			hud.heading_label.text="01  /  THE FIRST CALL"
			hud.mission_label.text="A cat in a tree"
			hud.detail_label.text=ControlPrompts.plain("{interact} to extend the ladder.\nBring its tip close to Pippin.") if rescued else "Follow the gold arrow to Maya.\nDrive close to say hello."
		2:
			hud.heading_label.text="02  /  WILLOW LANE"
			hud.mission_label.text="A little too well done"
			hud.detail_label.text="Find Leo beside his barbecue.\nDrive close to check in."
			job_label.text="02  /  TALK TO LEO"
		3:
			hud.heading_label.text="02  /  HOSE AT THE READY"
			hud.mission_label.text="Cool things down"
			job_label.text="SPRAY THE FLAMES"
		4:
			hud.heading_label.text="OFF DUTY  /  STILL A HERO"
			hud.mission_label.text="Optional jobs"
			hud.detail_label.text=("✓" if dog_done else "○")+" Rinse Biscuit · west side\n"+("✓" if pool_done else "○")+" Fill the pool · Rose Cottage"
		5:
			hud.heading_label.text="A QUIET MOMENT"
			hud.mission_label.text="Explore the neighbourhood"
			hud.detail_label.text=""

func toast(words: String) -> void:
	hud.toast_label.text=words
	toast_time=5

func _setup_audio() -> void:
	if DisplayServer.get_name()=="headless": return
	audio=AudioStreamPlayer.new()
	audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	var engine_loop:=load("res://assets/audio/town/engine_0.wav") as AudioStreamWAV
	engine_loop.loop_mode=AudioStreamWAV.LOOP_FORWARD
	engine_loop.loop_end=engine_loop.data.size()/2
	audio.stream=engine_loop
	audio.volume_db=-38
	add_child(audio)
	audio.play()
	music=AudioStreamPlayer.new()
	music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	var song: AudioStreamMP3=load("res://assets/audio/song.mp3")
	song.loop=true
	music.stream=song
	music.volume_db=-25
	add_child(music)
	music.play()
	water_audio=AudioStreamPlayer.new()
	# Match the other continuously mixed sounds. Browser Sample playback
	# applies volume changes immediately, making hose starts/stops click.
	water_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	var water_loop: AudioStreamOggVorbis=load("res://assets/audio/water_flow.ogg")
	water_loop.loop=true
	water_audio.stream=water_loop
	water_audio.volume_db=-80
	add_child(water_audio)
	water_audio.play()

func _audio_update(dt: float) -> void:
	# Transitions suspend truck physics, so its last spray flag can outlive
	# the cannon action. Keep the soft audio release running during cinematics.
	var cannon_active: bool=truck.spraying and truck.enabled and truck.is_physics_processing() and not paused and not loading and not (intro and intro.active) and not (travel and travel.active)
	hose_volume=lerpf(hose_volume,1.0 if cannon_active else 0.0,1-exp(-10*dt))
	if water_audio: water_audio.volume_db=linear_to_db(maxf(0.00001,hose_volume*0.063))
	if audio:
		audio.stream_paused=paused
		audio.pitch_scale=lerpf(audio.pitch_scale,1+truck.linear_velocity.length()*.045,1-exp(-3*dt))


func _on_cat_ladder_reached(engine: FireEngine) -> void:
	if rescue_running or cat_rescued: return
	if dialogue_active: end_dialogue()
	rescue_running=true
	sounds.play("meow",town.cat.global_position,1.0,1.0)
	truck.enabled=false
	truck.charge=0
	truck.linear_velocity=Vector3.ZERO
	truck.angular_velocity=Vector3.ZERO
	truck.freeze=true
	truck.ladder_busy=true
	var cat:=town.cat
	var start:=cat.global_position
	var tip:=engine.ladder_tip.global_position+Vector3.UP*.05
	var base:=engine.ladder.global_position+Vector3.UP*.06
	var landing:=engine.global_position+engine.global_basis*Vector3(1.75,0,1.3)
	var other:=engine.global_position+engine.global_basis*Vector3(-1.75,0,1.3)
	if other.distance_to(TownLayout.MAYA)<landing.distance_to(TownLayout.MAYA): landing=other
	var probe:=PhysicsRayQueryParameters3D.create(landing+Vector3.UP*3,landing+Vector3.DOWN*5,1,[engine.get_rid()])
	var ground:=get_world_3d().direct_space_state.intersect_ray(probe)
	landing.y=(ground.position.y if ground else 0.0)+.10
	cat.look_at(base,Vector3.UP)
	rescue_tween=create_tween()
	rescue_tween.tween_method(func(t: float):
		cat.global_position=start.lerp(tip,t)+Vector3.UP*sin(t*PI)*.65,0.0,1.0,.5)
	rescue_tween.tween_method(func(t: float):
		cat.global_position=tip.lerp(base,t)+Vector3.UP*absf(sin(t*TAU*6))*.035
		for i in cat_paws.size(): cat_paws[i].rotation.x=sin(t*TAU*6+(i%2)*PI)*.35,0.0,1.0,1.45)
	rescue_tween.tween_callback(func():
		for paw in cat_paws: paw.rotation.x=0
		cat.look_at(Vector3(landing.x,cat.global_position.y,landing.z)))
	rescue_tween.tween_method(func(t: float):
		cat.global_position=base.lerp(landing,t)+Vector3.UP*sin(t*PI)*.4,0.0,1.0,.6)
	rescue_tween.tween_callback(func():
		cat.rotation.x=0
		cat.rotation.z=0
		cat_rescued=true
		rescue_running=false
		truck.freeze=false
		truck.release_ladder()
		_after_cat_rescue()
		_start_cat_cuddle())

func _after_cat_rescue() -> void:
	var next_stage:=4 if fire_progress>=1 else (3 if barbecue_discovered else 5)
	talk("MAYA  /  THANK YOU","Thank you! Come here, Pippin. That's enough adventuring for one morning.",next_stage)
	if not barbecue_discovered and not barbecue_call_sent and fire_progress<1:
		barbecue_call_delay=BARBECUE_CALL_DELAY
		barbecue_ring_timer=-1

func _start_cat_cuddle() -> void:
	var cat:=town.cat
	var maya: Node3D=town.people[0]
	var start:=cat.global_position
	cat_cuddle_tween=create_tween()
	cat_cuddle_tween.tween_method(func(t: float):
		var feet: Vector3=maya.global_transform*Vector3(0,.10,-1.2)
		cat.global_position=start.lerp(feet,t)+Vector3.UP*absf(sin(t*TAU*5))*.055
		cat.look_at(Vector3(maya.position.x,cat.global_position.y,maya.position.z)),0.0,1.0,.85)
	cat_cuddle_tween.tween_callback(func(): town.cat_cuddling=true)
	cat_cuddle_tween.tween_method(func(t: float):
		var feet: Vector3=maya.global_transform*Vector3(0,.10,-1.2)
		var arms: Vector3=maya.global_transform*Vector3(0,.80,-.55)
		cat.global_position=feet.lerp(arms,t)+Vector3.UP*sin(t*PI)*.5
		cat.scale=Vector3.ONE*lerpf(1,.82,t),0.0,1.0,.55)
	cat_cuddle_tween.tween_callback(func():
		cat.reparent(maya)
		cat.position=Vector3(0,.80,-.55)
		cat.rotation=Vector3(0,-PI/2,0))

func _cancel_cat_rescue() -> void:
	if rescue_tween and rescue_tween.is_valid(): rescue_tween.kill()
	if cat_cuddle_tween and cat_cuddle_tween.is_valid(): cat_cuddle_tween.kill()
	town.cat_cuddling=false
	if town.cat.get_parent()!=town: town.cat.reparent(town)
	town.cat.scale=Vector3.ONE
	town.cat.global_position=cat_home
	town.cat.rotation=cat_home_rotation
	for paw in cat_paws: paw.rotation.x=0
	cat_ladder_event.consumed=false
	rescue_running=false
	truck.freeze=paused
	truck.enabled=not paused
	truck.release_ladder()
	if not cat_rescued:
		barbecue_call_delay=-1
		barbecue_ring_timer=-1

func _exit_tree() -> void:
	if audio: audio.stop()
	playback=null
	TownProps.materials.clear()
	TownProps.toy_materials.clear()
	TownProps.softened_materials.clear()
	TownProps.effect_shaders.clear()
	TownProps.rounded_mesh=null
	TownProps.sphere_mesh=null
	TownProps.cylinder_meshes.clear()
