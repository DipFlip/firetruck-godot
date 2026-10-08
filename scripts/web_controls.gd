class_name WebControls
extends Node

var game: Node3D
var state: JavaScriptObject
var jump_down:=false
var sequences: Dictionary={}
var last_view:=Vector2.ZERO
var last_talking:=false
var qa: JavaScriptObject
var qa_sequence:=0
var qa_lap_target:=RaceCourse.STEPS+1
var qa_driving:=false
var qa_drive_frames:=0
var qa_surface_error:=0.0
var qa_flat_step:=0.0
var qa_previous_height:=.85
var qa_previous_surface:=.055
var telemetry_clock:=0.0
var map_clock:=0.0
var map_initialized:=false
var frame_budget:=BrowserFrameBudget.new()
var qa_render_histogram: Array[int]=[0,0,0,0,0]
var qa_max_render_ms:=0.0
var previous_render_usec:=0

func _process(_dt: float) -> void:
	if state==null: return
	var foreground: bool=bool(state.focused) and bool(state.visible) and not game.loading and not game.paused
	var now:=Time.get_ticks_usec()
	# Use actual callback intervals; Godot's gameplay delta is smoothed by its
	# physics timer and can hide a missed browser frame in a performance sample.
	var seconds: float=(now-previous_render_usec)/1000000.0 if previous_render_usec>0 else 0.0
	previous_render_usec=now if foreground else 0
	if bool(state.testing) and foreground and seconds>0:
		var ms:=seconds*1000
		var bucket:=0 if ms<=18 else 1 if ms<=25 else 2 if ms<=35 else 3 if ms<=50 else 4
		qa_render_histogram[bucket]+=1
		qa_max_render_ms=maxf(qa_max_render_ms,ms)
	if frame_budget.sample(seconds,foreground):
		game.get_viewport().scaling_3d_scale=frame_budget.scale

func _ready() -> void:
	process_physics_priority=-100
	process_mode=Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		state=JavaScriptBridge.get_interface("firetruckTouch")
		if bool(state.testing): qa=JavaScriptBridge.get_interface("firetruckQA")
	else: set_physics_process(false)

func _physics_process(_dt: float) -> void:
	if state==null: return
	if bool(state.testing):
		_qa_update()
		if qa_driving:
			var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
			var surface:=RaceCourse.surface_at(local)
			qa_drive_frames+=1
			if qa_drive_frames>30:
				qa_surface_error=maxf(qa_surface_error,absf(local.y-surface.height-.8))
				if surface.height<.06 and absf(surface.height-qa_previous_surface)<.001 and surface.gradient.length()<.001:
					qa_flat_step=maxf(qa_flat_step,absf(local.y-qa_previous_height))
			qa_previous_height=local.y
			qa_previous_surface=surface.height
		telemetry_clock+=_dt
		if telemetry_clock>.2:
			telemetry_clock=0
			var neighbours: Array=[]
			for actor in game._npc_actors():
				var screen: Vector2=game.camera.unproject_position(actor.global_position+Vector3.UP*1.3)
				neighbours.append({"x":screen.x,"y":screen.y,"visible":game.npc_in_view(actor)})
			var race_gates: Array=[]
			for i in 4:
				var point:=RaceCourse.gate_position(i)
				var direction:=RaceCourse.gate_direction(i)
				race_gates.append({"x":point.x,"y":point.y+.85,"z":point.z,"dx":direction.x,"dz":direction.y})
			state.telemetry=JSON.stringify({"render_histogram":qa_render_histogram,"max_render_ms":qa_max_render_ms,"render_frames":Engine.get_frames_drawn(),"process_frames":Engine.get_process_frames(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"render_scale":game.get_viewport().scaling_3d_scale,"focused":bool(state.focused),"world":"race_track" if game.travel.in_race else "maple_bay","transition":game.travel.active,"transition_clock":game.travel.clock,"lap_running":game.travel.race.running,"lap_time":game.travel.race.lap_time,"race_checkpoint":game.travel.race.checkpoint,"race_gates":race_gates,"loose_race_props":game.travel.race.props.filter(func(prop): return prop.loose).size(),"last_lap":game.travel.race.last_time,"surface_error":qa_surface_error,"flat_height_step":qa_flat_step,"race_drive_frames":qa_drive_frames,"best_lap":game.travel.race.best_time,"north_exit_open":game.travel.gate_opening>=.99,"warmup_pool":game.pool_shader_warmed,"neighbours":neighbours,"speaker":game.hud.speaker_key,"truck_position":[game.truck.position.x,game.truck.position.z],"dialogue_revealed":game.hud.char_count,"dialogue_font":game.hud.dialogue_font_size,"dialogue_rect":[game.hud.dialogue_panel.position.x,game.hud.dialogue_panel.position.y,game.hud.dialogue_panel.size.x,game.hud.dialogue_panel.size.y],"logical_view":[game.hud.size.x,game.hud.size.y],"speed":game.truck.linear_velocity.length(),"water":game.truck.water,"fire_progress":game.fire_progress,"audio_counts":game.sounds.counts,"cannon_spraying":game.truck.spraying,"hose_gain":game.hose_volume,"conversation_blend":game.conversation_blend,"ladder":game.truck.ladder_deployed,"charge":game.truck.charge,"height":game.truck.position.y,"paused":game.paused,"talking":game.dialogue_active,"fps":Engine.get_frames_per_second(),"loading":game.loading,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"dialogue_lines":game.hud.dialogue_label.get_line_count(),"dialogue_text":game.hud.full_text,"pages":game.hud.dialogue_pages.size(),"batched":game.batched_decorations,"merged_scenery":game.merged_scenery,"scenery_cached":game.town.has_node("BakedScenery"),"camera_size":game.camera.size,"cat_carried":game.town.cat_cuddling,"train_push_locked":game.railway.push_locked,"intro":game.intro.active,"intro_shot":game.intro.shot,"intro_clock":game.intro.clock,"game_clock":game.elapsed,"train_started":game.railway.started,"train_boarded":game.railway.boarded,"train_position":[game.railway.engine.position.x,game.railway.engine.position.z]})
	game.hud.touch_mode=bool(state.enabled)
	game.hud.touch_portrait=bool(state.portrait)
	var view:=Vector2(float(state.width),float(state.height))
	if view!=last_view and view.x>0 and view.y>0:
		last_view=view
		game.dialogue_out_of_view_time=-.5
		get_window().content_scale_size=logical_size(view)
		get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	if game.loading: return
	if not map_initialized:
		map_initialized=true
		var hydrants: Array=[]
		for h in game.town.hydrants: hydrants.append([h.x,h.z])
		var jobs: Array=[[TownLayout.DOG.x,TownLayout.DOG.z],[TownLayout.POOL.x,TownLayout.POOL.z]]
		JavaScriptBridge.eval("window.firetruckMapSetup(%s)" % JSON.stringify({"hydrants":hydrants,"jobs":jobs}))
	map_clock+=_dt
	if false and map_clock>=.1: # The portrait deck minimap is retired.
		map_clock=0
		var p: Vector3=game.truck.position
		var objective: Vector3=game.objective()
		JavaScriptBridge.eval("window.firetruckMap(%f,%f,%f,%d,%f,%f,%f,%f,%s)" % [p.x,p.z,game.truck.heading,game.stage,objective.x,objective.z,game.railway.engine.position.x,game.railway.engine.position.z,"true" if game.navigation_active() else "false"])
	if int(state.cancel)!=int(sequences.get("cancel",0)):
		sequences.cancel=int(state.cancel)
		game.truck.charge=0
		Input.action_release("jump")
		jump_down=false
	game.truck.touch_drive=Vector2(float(state.driveX),float(state.driveY)).limit_length(1)
	game.truck.touch_aim=Vector2(float(state.aimX),float(state.aimY)).limit_length(1)
	for action in ["ladder","pause","map","recover"]:
		var sequence:=int(state[action])
		if sequence!=int(sequences.get(action,0)):
			sequences[action]=sequence
			_send("interact" if action=="ladder" else action)
	var pressed:=bool(state.jump)
	if pressed!=jump_down:
		jump_down=pressed
		if pressed:
			Input.action_press("jump")
			_send("jump")
		else: Input.action_release("jump")
	var talking: bool=game.dialogue_active and not game.pool_basin.contains_truck()
	if talking!=last_talking:
		last_talking=talking
		JavaScriptBridge.eval("window.firetruckDialogue(%s)" % ("true" if last_talking else "false"))

func _send(action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=true
	game._unhandled_input(event)

# CSS pixels (not the high-DPI backing buffer) determine readable HUD sizes.
# Both dimensions contribute; extra height no longer makes a narrow screen tiny.
static func logical_size(view: Vector2) -> Vector2i:
	var ui_scale:=clampf(minf(view.x/1000.0,view.y/700.0),.85,1.5)
	return Vector2i((view/ui_scale).round())

# Opt-in local gameplay probes for repeatable browser rendering checks.
# The normal shell has no command object; ?qa=travel explicitly enables it.
func _qa_update() -> void:
	if qa==null or game.loading or int(qa.sequence)==qa_sequence: return
	qa_sequence=int(qa.sequence)
	match str(qa.action):
		"pose":
			if game.intro.active: game.intro.finish()
			if game.travel.active: return
			game.end_dialogue()
			var x:=float(qa.x)
			var z:=float(qa.z)
			if not is_finite(x) or not is_finite(z) or absf(x)>84 or absf(z)>84: return
			game.truck.global_position=game.truck.world_origin+Vector3(x,float(qa.value) if float(qa.value)>0 else .82,z)
			game.truck.linear_velocity=Vector3.ZERO
			game.truck.angular_velocity=Vector3.ZERO
			game.truck.reset_physics_interpolation()
			game.camera_focus=game.truck.global_position
			game.camera.global_position=game.camera_focus+game.gameplay_camera_offset()
			game.camera.look_at(game.camera_focus)
		"start_train":
			game.railway.started=true
			game.railway.boarded=true
		"drive_race":
			if not game.travel.in_race or game.travel.active: return
			qa_driving=true
			qa_lap_target=RaceCourse.STEPS+1
			qa_drive_frames=0
			qa_surface_error=0
			qa_flat_step=0
			game.travel.race.last_time=0
			game.travel.race.previous=Vector2(-4,-54)
			game.truck.heading=-PI/2
			game.truck.rotation.y=-PI/2
			game.truck.top_speed=15
			game.truck.drive_guide=_qa_race_guide
		"stop_race_drive":
			qa_driving=false
			game.truck.drive_guide=game.railway.guide_push
			game.truck.top_speed=16.875

		"fill_pool":
			if game.travel.in_race: return
			game.pool_progress=clampf(float(qa.value),0,1)
			game.pool_basin.set_fill(game.pool_progress)
		"spray_fire":
			if game.travel.in_race: return
			game.stage=3
			game.fire_progress=0
			game.town.fire_amount=1
			game.truck.water=game.truck.tank_capacity
			game.truck.use_automation=true
			game.truck.automated_aim=TownLayout.FIRE+Vector3.UP*1.8
			game.truck.automated_spray=true
		"stop_spray":
			game.truck.automated_spray=false
			game.truck.use_automation=false

# QA-only steering follows the real course using ordinary acceleration, grip,
# recoil and collision code. It never changes the truck pose during the lap.
func _qa_race_guide(_desired: Vector3, _dt: float) -> Vector3:
	if game.travel.race.last_time>0: return Vector3.ZERO
	var local: Vector3=game.truck.global_position-ToyRaceTrack.ORIGIN
	var path:=RaceCourse.points()
	var target: Vector3=path[qa_lap_target]
	if Vector2(local.x-target.x,local.z-target.z).length()<4:
		qa_lap_target=(qa_lap_target+3)%(path.size()-1)
		target=path[qa_lap_target]
	return Vector3(target.x-local.x,0,target.z-local.z).normalized()
