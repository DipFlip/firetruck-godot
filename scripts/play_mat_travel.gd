class_name PlayMatTravel
extends Node

const DURATION:=26.0
# Tour clocks retain their authored waypoints; playback is 15% faster.
const INTRO_PACE:=1.15
const DEPARTURE_ZOOM_SECONDS:=1.125
const DEPARTURE_LEAD:=.5625
const ARRIVAL_START:=2.8
const RACE_ARRIVAL_START:=1.85
const ARRIVAL_END:=21.5
const PRINT_FADE_START:=20.9
const PRINT_FADE_END:=22.7
const SCENERY_READY:=22.75
const EXIT_Z:=-82.0
const MAPLE_TOYS:=1<<10
const RACE_TOYS:=1<<11
const WORLD_TOYS:=MAPLE_TOYS|RACE_TOYS
var game: Node3D
var race: ToyRaceTrack
var mat: RollingMat
var outgoing_mat: RollingMat
var source_race:=false
var departure_camera:=Transform3D.IDENTITY
var departure_lens:=25.8
var departure_focus:=Vector3.ZERO
var departure_pan:=0.0
var active:=false
var in_race:=false
var destination_race:=false
var swapped:=false
var clock:=0.0
var sequence_clock:=0.0
var exit_armed:=false
var maple_roots: Array[Node3D]=[]
var body_states: Array[Dictionary]=[]
var root_modes: Array[int]=[]
var assembly: Array[Dictionary]=[]
var assembly_origin:=Vector3.ZERO
var assembly_progress:=-1.0
var assembly_materials: Dictionary={}
var baked_schedules: Dictionary={}
var baked_audio: Dictionary={}
var baked_arrival_meshes: Dictionary={}
static var tour_windows: Array[Dictionary]=[{},{}]
static var tour_samples: Array[Array]=[[],[]]
var assembly_audio: Array[Dictionary]=[]
var assembly_audio_keys: Dictionary={}
var assembly_audio_index:=0
var instance_inverses: Dictionary={}
var assembly_instances: Dictionary={}
var assembly_printed:=false
var race_visited:=false
var short_transition:=false
var duration:=DURATION
var title: TownTitle
var toys_hidden:=false
var saved_camera_mask:=0
var saved_shadow_mask:=0
var bird_finishes: Dictionary={}

func _ready() -> void:
	name="PlayMatTravel"
	maple_roots=[game.town,game.atmosphere,game.life,game.gardens,game.pool_basin,game.ramps,game.interactions,game.railway,game.dog_puddle,game.barbecue,game.playroom]
	mat=RollingMat.new()
	game.add_child(mat)
	outgoing_mat=RollingMat.new()
	game.add_child(outgoing_mat)
	outgoing_mat.name="OutgoingTrafficCarpet"
	race=ToyRaceTrack.new()
	race.game=game
	game.add_child(race)
	_open_north_street()
	for root in maple_roots: _set_toy_layer(root,MAPLE_TOYS)
	_set_toy_layer(race,RACE_TOYS)
	title=TownTitle.new()
	game.hud.add_child(title)
	title.set_race_title()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.hide()

func _set_toy_layer(root: Node3D, layer: int) -> void:
	var visual_nodes:=root.find_children("*","GeometryInstance3D",true,false)
	visual_nodes.append_array(root.find_children("*","Label3D",true,false))
	for node in visual_nodes:
		if node.layers==0 or node==race.mat or node==game.playroom.floor_art or node.name=="RacePlayroomFloor": continue
		var backdrop:=false
		var ancestor: Node=node
		while ancestor!=root and ancestor!=null:
			if ancestor.has_meta("room_backdrop"): backdrop=true; break
			ancestor=ancestor.get_parent()
		if not backdrop: node.layers=(node.layers&~1)|layer

func _hide_toys() -> void:
	if toys_hidden: return
	toys_hidden=true
	saved_camera_mask=game.camera.cull_mask
	saved_shadow_mask=game.sun.shadow_caster_mask
	game.camera.cull_mask=saved_camera_mask&~WORLD_TOYS
	game.sun.shadow_caster_mask=saved_shadow_mask&~WORLD_TOYS
	_set_floor_cut(false)

func _show_toys() -> void:
	if not toys_hidden: return
	game.camera.cull_mask=saved_camera_mask
	game.sun.shadow_caster_mask=saved_shadow_mask
	toys_hidden=false

func _set_floor_cut(value: bool) -> void:
	game.playroom.floor_art.material_override.set_shader_parameter("cut_pool",value)
	if race: race.get_node("RacePlayroomFloor").material_override.set_shader_parameter("cut_pond",value)

func _open_north_street() -> void:
	# Split the continuous wall; every other street remains enclosed by blocks.
	for wall in game.playroom.walls:
		if wall.position.z< -80 and absf(wall.position.x)<1:
			wall.get_child(0).shape.size=Vector3(72,3.6,2.8)
			wall.position.x=-44
			game.playroom._wall(Vector3(44,1.2,-81),Vector3(72,3.6,2.8))
			break
	# The playroom's batched decorative north row also needs a real opening.
	# Shader batches cannot remove individual blocks, so exclude this street in
	# the builder and rebatch at startup (see Playroom's street-gap condition).
	# TownAtmosphere already extends the continuous asphalt and lane paint to
	# the mat edge. A second exit slab here overlapped it and changed its colour.
	# Turn the perimeter inward beside the final road section. The locomotive
	# closes this passage at the track; no separate sliding barrier is needed.
	var passage:=Node3D.new()
	passage.name="MotorwayPassage"
	passage.set_meta("boundary_blocks",true)
	game.playroom.add_child(passage)
	var end:=NorthlineRailway.TRACK_Z-2.8
	var length: float=end+81.0
	for side in [-1,1]:
		game.playroom._wall(Vector3(side*6.4,1.5,-81+length*.5),Vector3(3.2,3.0,length))
		for piece in 3:
			var span: float=length/3
			var height: float=[3.0,2.8,3.2][piece]
			var block:=TownProps.box(passage,Vector3(side*6.4,height*.5,-81+(piece+.5)*span),Vector3(span-.10,height,3.2),Color.WHITE)
			block.rotation.y=PI/2
			block.material_override=Playroom.wood_finish(Color(["d0aa76","e3c79d","b98a5c"][(piece+(1 if side>0 else 0))%3]))
			block.set_meta("batch_static",true)
	TownProps.batch_decorations(passage)

func north_exit_clear() -> bool:
	if in_race: return true
	var engine: RigidBody3D=game.railway.engine
	# The collision remains on the train. This also describes a returning
	# locomotive honestly instead of opening an invisible gate on a timer.
	return engine.collision_layer==0 or absf(engine.position.x)>NorthlineRailway.ENGINE_HALF_LENGTH+4.3

func _process(dt: float) -> void:
	if game.paused or game.loading: return
	if active:
		_update_transition(dt)
		return
	if game.intro.active: return
	var local: Vector3=game.truck.global_position-(ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO)
	# Moving away from the arrival clears the latch, so arrival cannot bounce
	# straight back into a second loading sequence.
	if local.z> -76: exit_armed=true
	if exit_armed and local.z<EXIT_Z and absf(local.x)<7.0: start(not in_race)

func start(to_race: bool) -> void:
	if active or game.rescue_running: return
	if in_race: race.challenge.cancel()
	finish_assembly()
	active=true
	mat.set_arrival_progress(-1)
	game.hud.reset_water_entrance()
	source_race=in_race
	departure_camera=game.camera.global_transform
	departure_focus=game.camera_focus
	departure_pan=game.camera.v_offset
	# Moving an orthographic lens along its view axis preserves every screen
	# position while keeping the camera clear of the room during the pull-out.
	departure_camera.origin+=departure_camera.basis.z*maxf(0,330-game.camera.global_position.distance_to(game.camera_focus))
	departure_lens=game.camera.size
	destination_race=to_race
	short_transition=not to_race or race_visited
	duration=(4.2 if short_transition else DURATION/INTRO_PACE)+DEPARTURE_LEAD
	swapped=false
	clock=0
	sequence_clock=0
	exit_armed=false
	game.end_dialogue()
	for fire in game.get_tree().get_nodes_in_group("toy_fires"): fire.hide()
	game.camera_trauma=0
	game.conversation_pan=0
	game.hud.toast_label.text=""
	game.toast_time=0
	game.hud.map_open=false
	game.truck.freeze=true
	game.truck.enabled=false
	game.truck.spraying=false
	game.truck.spray_requested=false
	game.truck.set_physics_process(false)
	game.truck.charge=0
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO
	game.refill_hose.update(null,1)
	game.truck.hide()
	game.truck.reset_truck()
	game.marker.hide()
	race.timer_label.hide()
	game.rewards.hide()
	game.rewards.set_process(false)
	if in_race:
		race.suspend_bodies()
		race.process_mode=Node.PROCESS_MODE_DISABLED
	else: suspend_maple()
	set_world_visible(true)
	# The outgoing print rolls away as a whole. Hiding toys/shadows by layer
	# avoids constructing and moving thousands of assembly pieces on exit.
	_hide_toys()
	# Keep only the wooden floor behind the outgoing printed carpet.
	if in_race: race.mat.hide()
	title.visible=to_race and not short_transition
	title.reveal=0
	title.opacity=0
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(true)")
	_update_transition(0)

func _update_transition(dt: float) -> void:
	clock+=dt
	# Give the longer pull-out a head start before gathering the carpet.
	sequence_clock=maxf(0,clock-DEPARTURE_LEAD)*(1.0 if short_transition else INTRO_PACE)
	if clock>=duration: finish(); return
	if short_transition:
		_update_short_transition()
		return
	_exchange_mats(1.3,2.2,1.6,2.4,2.0)
	var centre:=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
	if swapped:
		var elapsed:=sequence_clock-2
		grow_assembly(arrival_progress(elapsed,in_race))
		# Fade the settled print gradually before the truck enters. Moving a
		# still-opaque poster beneath the ground made a hard visual cut.
		mat.fade_print(1-smoothstep(PRINT_FADE_START,PRINT_FADE_END,elapsed))
		if in_race:
			race.mat.visible=sequence_clock>=2.4+RollingMat.ROLLOUT_SECONDS
			race.mat.finish.set_shader_parameter("printed_toys",false)
		if elapsed>=fly_in_start(in_race): assembly_camera(elapsed,in_race)
		else: _exchange_camera(centre)
		title.reveal=smoothstep(4,19,elapsed)
		title.opacity=smoothstep(3.4,4.2,elapsed)*(1-smoothstep(22,23.7,elapsed))
		title.queue_redraw()
	else:
		_exchange_camera(centre)
	if sequence_clock>=23.5:
		var entry:=smoothstep(23.5,DURATION,sequence_clock)
		var drive:=entrance_progress((sequence_clock-24.0)/2.0)
		game.truck.arrival_pose(centre+Vector3(0,ToyRaceTrack.SPAWN.y,lerpf(-83,-73,drive)),PI,-10*drive,sequence_clock-23.5)
		var focus: Vector3=(centre+tour_focus(sequence_clock-2,in_race)).lerp(game.truck.global_position,entry)
		game.camera.position=focus+handover_offset(Vector3(19,15,22).lerp(game.gameplay_camera_offset(),entry),entry)
		game.camera.look_at(focus)
		game.camera.size=lerpf(tour_lens(sequence_clock-2,in_race),25.8,entry)
		cinematic_shadows(focus)
		prepare_handover_view(game.truck.global_position,entry,in_race)
	if swapped and sequence_clock-2>=SCENERY_READY and not assembly.is_empty(): finish_assembly()

func _update_short_transition() -> void:
	_exchange_mats(1.05,2.1,1.425,2.175,1.8,1.2)
	var phase:=sequence_clock/1.5
	var centre:=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
	_exchange_camera(centre)
	if not swapped: return
	if phase>=2.25:
		_show_toys()
		_set_floor_cut(true)
		if in_race: race.mat.show()
		mat.fade_print(1-smoothstep(2.25,2.7,phase))
		var drive:=entrance_progress((sequence_clock-3.375)/.825)
		game.truck.arrival_pose(centre+Vector3(0,ToyRaceTrack.SPAWN.y,lerpf(-79,-73,drive)),PI,-6*drive,1.0)
	var zoom:=smoothstep(1.6,2.4,phase)
	var focus:=centre+Vector3(0,0,-12).lerp(ToyRaceTrack.SPAWN,zoom)
	# Complete the framing before bringing the lens through the town's airborne
	# birds. A wide lens descending through them could clip a wing on return.
	var offset: Vector3=(Vector3(96,116,124)*2.4).lerp(game.gameplay_camera_offset(),zoom)
	game.camera.position=focus+offset.normalized()*lerpf(maxf(330,offset.length()),game.gameplay_camera_offset().length(),smoothstep(2.4,2.8,phase))
	game.camera.look_at(focus)
	game.camera.size=lerpf(game.camera.size,25.8,zoom)
	cinematic_shadows(focus)
	if phase>=2.25: prepare_handover_view(focus,smoothstep(3.375,4.2,sequence_clock),in_race)

func _swap_world() -> void:
	swapped=true
	finish_assembly()
	if in_race: race.hide()
	else:
		for root in maple_roots: root.hide()
	in_race=destination_race
	set_world_visible(true)
	if short_transition:
		# Preserve all moved props and actor poses. The complete town can be
		# revealed in one operation after its new carpet has settled.
		_set_floor_cut(false)
	else:
		begin_assembly(in_race)
		_show_toys()
	if in_race: race.mat.hide()

func _exchange_mats(roll_end: float, lift_end: float, incoming_start: float, land_end: float, switch_at: float, rollout_seconds: float=RollingMat.ROLLOUT_SECONDS) -> void:
	if not swapped and sequence_clock>=switch_at: _swap_world()
	var centre:=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
	# Both independent sheets remain in the same room composition across the
	# world-coordinate change. The outgoing roll rises and is carried away.
	outgoing_mat.show_mat(source_race,motion_ease(sequence_clock/roll_end),centre,false)
	var lift:=smoothstep(roll_end,lift_end,sequence_clock)
	var carry:=motion_ease(clampf((lift-.55)/.45,0,1))
	# Carry it out through the open side of the room, clear of the west wall.
	outgoing_mat.position+=Vector3(-20*carry,92*motion_ease(minf(1,lift/.55))+8*sin(carry*PI),230*carry)
	outgoing_mat.rotation=Vector3(-.2*lift,0,.12*lift)
	outgoing_mat.visible=sequence_clock<lift_end
	if sequence_clock<incoming_start:
		mat.hide()
		return
	var land:=smoothstep(incoming_start,land_end,sequence_clock)
	var amount:=1-motion_ease((sequence_clock-land_end)/rollout_seconds) if short_transition else RollingMat.rollout_amount(sequence_clock-land_end,rollout_seconds)
	mat.show_mat(destination_race,amount,centre)
	var approach:=motion_ease(minf(1,land/.55))
	var lower:=motion_ease(clampf((land-.55)/.45,0,1))
	mat.position+=Vector3(150*(1-approach),100*(1-lower),-50*(1-approach))
	mat.rotation=Vector3(.10*(1-land),0,-.08*(1-land))

static func motion_ease(t: float) -> float:
	# Zero velocity and acceleration at either end of the gathering motion.
	t=clampf(t,0,1)
	return t*t*t*(t*(t*6-15)+10)

static func entrance_progress(t: float) -> float:
	# Start at rest, finish with forward velocity to carry into player physics.
	t=clampf(t,0,1)
	return t*t*(2-t)

func _exchange_camera(centre: Vector3) -> void:
	mat_camera(centre,1)
	# Pull out of the player's view continuously, then keep the same lens and
	# floor framing while one carpet replaces the other.
	var blend:=motion_ease(clock/DEPARTURE_ZOOM_SECONDS)
	game.camera.global_transform=departure_camera.interpolate_with(game.camera.global_transform,blend)
	# Blend the subject as well as the camera position. Interpolating rotation
	# alone can aim past the town while the close lens is still opening.
	var focus:=departure_focus.lerp(centre+Vector3(0,0,-12),blend)
	game.camera.look_at(focus)
	game.camera.v_offset=lerpf(departure_pan,0,blend)
	# Ease proportional magnification, so the close view opens gently instead
	# of losing most of its apparent scale in the first half of the pull-out.
	game.camera.size=departure_lens*pow(game.camera.size/departure_lens,blend)
	cinematic_shadows(focus)

func mat_camera(centre: Vector3, progress: float) -> void:
	var aspect: float=game.hud.size.x/maxf(1,game.hud.size.y)
	var focus:=centre+Vector3(0,4,45).lerp(Vector3(0,0,-12),progress)
	game.camera.position=focus+Vector3(90,95,110).lerp(Vector3(96,116,124),progress)*2.4
	game.camera.look_at(focus)
	game.camera.size=maxf(lerpf(175,185,progress),185/maxf(.6,aspect))
	game.camera.far=900
	game.camera.near=.02
	game.camera.v_offset=0
	cinematic_shadows(focus)

static func arrival_progress(elapsed: float, is_race: bool=false) -> float:
	var start:=RACE_ARRIVAL_START if is_race else ARRIVAL_START
	return clampf((elapsed-start)/(ARRIVAL_END-start),0,1)

static func fly_in_start(is_race: bool) -> float:
	# The incoming race mat lands .4s into its tour clock. Begin framing the
	# toys while the last half-second of fabric is still settling.
	return RollingMat.ROLLOUT_SECONDS+(.4 if is_race else 0.0)-.5

static func first_house(is_race: bool) -> Vector3:
	return Vector3(65,0,24) if is_race else Vector3(-49,0,-22)

# Quantized seeds keep individual toys staggered inside each camera window.
static func arrival_seed(at: Vector3, kind: int) -> float:
	var h:=posmod(int(floor(at.x*8+.5))*73+int(floor(at.z*8+.5))*151,997)
	return float(posmod(h*h*13+h*71+kind*83,997))/997.0

static func tour_window(at: Vector3, is_race: bool) -> Vector2:
	# Resolve the closest part of the camera tour once during loading, never
	# by scanning the scene or projecting every toy during the live animation.
	var world:=1 if is_race else 0
	var key:=Vector2i(roundi(at.x*8),roundi(at.z*8))
	if tour_windows[world].has(key): return tour_windows[world][key]
	if tour_samples[world].is_empty():
		for i in 89:
			var elapsed:=3.9+i*.2
			var focus:=tour_focus(elapsed,is_race)
			tour_samples[world].append(Vector3(focus.x,elapsed,focus.z))
	var nearest:=Vector2(0,INF)
	for sample: Vector3 in tour_samples[world]:
		var distance:=Vector2(sample.x-at.x,sample.z-at.z).length()
		if distance<nearest.y: nearest=Vector2(sample.y,distance)
	tour_windows[world][key]=nearest
	return nearest

static func arrival_delay(at: Vector3, kind: int, is_race: bool=false) -> float:
	var seed:=arrival_seed(at,kind)
	var start:=RACE_ARRIVAL_START if is_race else ARRIVAL_START
	var length:=ARRIVAL_END-start
	if is_race:
		var p:=Vector2(at.x,at.z)
		if p.distance_to(Vector2(0,-54))<12: return .08+seed*.01
		if p.distance_to(Vector2(18,-68))<9: return (3.6+seed*.35-start)/length
		if race_food_court(at): return ((10.0 if kind==2 else 10.25+seed*.65)-start)/length
		if p.distance_to(Vector2(73,-22))<12: return (7.2+seed*.55-start)/length
		if p.distance_to(Vector2(ToyRaceTrack.WEST_STAND.x,ToyRaceTrack.WEST_STAND.z))<15: return (16.4+seed*.65-start)/length
	else:
		var distance:=Vector2(at.x,at.z).distance_to(Vector2(first_house(false).x,first_house(false).z))
		if kind==2 and distance<8: return .015
		if kind==3 and distance<20: return .045+seed*.015
		# The whole southwest grove lands during the turn into that corner.
		if at.x< -40 and at.z>28: return (9.8+seed*1.0-start)/length
	var window:=tour_window(at,is_race)
	if window.y<35:
		var span:=arrival_span(at,kind,is_race)
		var birth:=window.x-span*length*.68-.1+seed*.35
		return clampf((birth-start)/length,.025,1-span-.005)
	# Toys beyond the close-up tour still assemble continuously in the distance.
	return .14+sqrt(seed)*.68 if is_race else .28+sqrt(seed)*.54

static func race_food_court(at: Vector3) -> bool:
	return at.x>=40 and at.x<=78 and at.z>=10 and at.z<=70

static func arrival_span(at: Vector3, kind: int, is_race: bool=false) -> float:
	if kind==1: return 0.0
	var length:=ARRIVAL_END-(RACE_ARRIVAL_START if is_race else ARRIVAL_START)
	if is_race:
		if race_food_court(at): return (1.6 if kind==2 else 1.15)/length
		if Vector2(at.x,at.z).distance_to(Vector2(73,-22))<12: return 1.35/length
		if Vector2(at.x,at.z).distance_to(Vector2(18,-68))<9: return 1.15/length
	elif kind==2 and at.distance_to(first_house(false))<8 or kind==3 and at.distance_to(first_house(false))<20:
		return .07
	if not is_race and at.x< -40 and at.z>28 or tour_window(at,is_race).y<35:
		return (1.6 if kind==2 else 1.3 if kind==3 else 1.0)/length
	return .155 if kind==2 or kind==4 else .12

static func perimeter_delay(at: Vector3, is_race: bool=false) -> float:
	# Keep the cascade beside the perimeter camera sweep even though the first
	# house now starts earlier to accompany the faster flight into the mat.
	var delay: float
	if absf(at.x)>=absf(at.z):
		delay=.27+.20*clampf((at.z+81)/162,0,1) if at.x<0 else .47+.37*(162+clampf(81-at.z,0,162))/486.0
	elif at.z>0: delay=.47+.37*clampf(at.x+81,0,162)/486.0
	else: delay=.47+.37*(324+clampf(81-at.x,0,162))/486.0
	var start:=RACE_ARRIVAL_START if is_race else ARRIVAL_START
	return ((6.5 if is_race else 2.9)+15*delay-start)/(ARRIVAL_END-start)

static func tour_focus(elapsed: float, is_race: bool) -> Vector3:
	var times: Array[float]=[4.1,6.25,8.25,9.55,11.2,13.15,15.05,17.65,20.1,21.5]
	var points: Array[Vector3]=[
		Vector3(-49,1,-22),Vector3(-46,1,-19),Vector3(-80,1,-54),Vector3(-80,1,3),
		Vector3(-67,1,42),Vector3(-32,1,26),Vector3(-15,1,13),Vector3(18,1,-10),Vector3(47,1,-23),Vector3(48,1,-20)]
	if is_race:
		times=[3.25,5.2,8.0,8.8,9.7,11.0,12.3,13.8,15.0,16.0,17.5,19.0,20.3,21.5]
		points=[Vector3(-8,3,-54),Vector3(6,3,-54),Vector3(55,2,-39),Vector3(70,6,-22),Vector3(56,2,5),
			Vector3(60,4,32),Vector3(58,4,34),Vector3(23,5,17),Vector3(0,6,4),
			Vector3(-42,2,23),ToyRaceTrack.WEST_STAND+Vector3(0,5,0),ToyRaceTrack.BROADCAST_POINT+Vector3(0,4,0),
			Vector3(-31,2,-54),Vector3(0,1,-73)]
	if elapsed<=times[0]: return points[0]
	if elapsed>=times[-1]: return points[-1]
	for i in times.size()-1:
		if elapsed>times[i+1]: continue
		var before:=maxi(0,i-1)
		var after:=mini(times.size()-1,i+2)
		var duration:=times[i+1]-times[i]
		var t:=(elapsed-times[i])/duration
		var v0:=(points[i+1]-points[before])/(times[i+1]-times[before])
		var v1:=(points[after]-points[i])/(times[after]-times[i])
		if is_race and i==0: v0=Vector3.ZERO
		if is_race and i==times.size()-2: v1=Vector3.ZERO
		# Time-aware Hermite tangents keep velocity continuous through turns.
		return (2*t*t*t-3*t*t+1)*points[i]+(t*t*t-2*t*t+t)*duration*v0+(-2*t*t*t+3*t*t)*points[i+1]+(t*t*t-t*t)*duration*v1
	return points[-1]

func tour_lens(elapsed: float, is_race: bool) -> float:
	var portrait_lens: float=32/maxf(.65,game.hud.size.x/maxf(1,game.hud.size.y))
	if is_race:
		var food:=smoothstep(9.8,11.0,elapsed)*(1-smoothstep(12.3,13.8,elapsed))
		var audience:=smoothstep(16.0,17.5,elapsed)*(1-smoothstep(19.0,20.3,elapsed))
		var bridge:=smoothstep(13.8,15.0,elapsed)*(1-smoothstep(15.0,16.0,elapsed))
		var lens:=lerpf(36,38,smoothstep(8.2,9.2,elapsed))+bridge*7-food*4-audience*4
		return maxf(lerpf(lens,28,smoothstep(20.3,21.5,elapsed)),portrait_lens)
	var pullback:=smoothstep(6.45,8.25,elapsed)
	var turn:=smoothstep(9.55,13.15,elapsed)
	return maxf(lerpf(lerpf(32,56,pullback),34,turn),portrait_lens)

static func cinematic_offset(direction: Vector3) -> Vector3:
	# Orthographic size controls framing independently of physical distance.
	# Keep the lens outside the entire mat/falling-toy envelope even during close
	# shots, rather than letting foreground objects cross the camera's near plane.
	return direction.normalized()*maxf(330,direction.length())

func handover_offset(direction: Vector3, progress: float) -> Vector3:
	return direction.normalized()*lerpf(maxf(330,direction.length()),game.gameplay_camera_offset().length(),smoothstep(.45,1,progress))

func cinematic_shadows(focus: Vector3) -> void:
	# The shadow volume follows the subject rather than ending before the
	# distant orthographic lens reaches it. Finish with the gameplay range.
	game.sun.directional_shadow_max_distance=game.gameplay_shadow_distance+maxf(0,game.camera.global_position.distance_to(focus)-game.camera_offset.length())

func prepare_handover_view(focus: Vector3, progress: float, is_race: bool) -> void:
	# The Compatibility shadow projection also depends on the camera's far
	# plane. Ease it into place while panning, leaving the last half-second
	# with the same depth range used after control is released.
	var gameplay_far:=500.0 if is_race else 250.0
	var safe_far:=maxf(gameplay_far,game.camera.global_position.distance_to(focus)+100)
	game.camera.far=lerpf(900,safe_far,smoothstep(0,.72,progress))

func assembly_camera(elapsed: float, is_race: bool) -> void:
	var centre:=ToyRaceTrack.ORIGIN if is_race else Vector3.ZERO
	var overview_progress:=1.0 if is_race else clampf(elapsed/RollingMat.ROLLOUT_SECONDS,0,1)
	var fly_start:=fly_in_start(is_race)
	if elapsed<fly_start:
		mat_camera(centre,overview_progress)
		return
	var focus:=tour_focus(elapsed,is_race)+centre
	var pullback:=smoothstep(6.45,8.25,elapsed) if not is_race else 0.0
	var turn:=smoothstep(9.55,13.15,elapsed) if not is_race else 0.0
	var offset:=Vector3(19,15,22).lerp(Vector3(30,24,24),pullback).lerp(Vector3(19,15,22),turn)
	var sweep:=motion_ease((elapsed-fly_start)/(3.8/(3.5 if is_race else 1.5)))
	# Continue the rollout's moving overview as we blend into the close shot.
	# Starting from its final pose early would introduce a camera jump.
	var overview_focus:=centre+Vector3(0,4,45).lerp(Vector3(0,0,-12),overview_progress)
	var overview_offset:=Vector3(90,95,110).lerp(Vector3(96,116,124),overview_progress)*2.4
	var camera_focus:=overview_focus.lerp(focus,sweep)
	# Interpolate the orbit direction on the unit sphere. Normalizing a blend
	# of a huge overview offset and tiny close-up offset bunched its turn at
	# the very end of the zoom, producing the opening hitch.
	var direction:=overview_offset.normalized().slerp(offset.normalized(),sweep)
	game.camera.position=camera_focus+direction*lerpf(overview_offset.length(),330,sweep)
	game.camera.look_at(camera_focus)
	var overview_lens:=maxf(lerpf(175,185,overview_progress),185/maxf(.6,game.hud.size.x/maxf(1,game.hud.size.y)))
	game.camera.size=overview_lens*pow(tour_lens(elapsed,is_race)/overview_lens,sweep)
	game.camera.v_offset=0
	game.camera.far=900
	game.camera.near=.02
	cinematic_shadows(camera_focus)

func finish() -> void:
	if not active: return
	if not swapped:
		in_race=destination_race
		if in_race: race.show()
		else: set_world_visible(true)
	active=false
	_show_toys()
	finish_assembly()
	mat.hide()
	outgoing_mat.hide()
	title.hide()
	if in_race:
		race_visited=true
		for root in maple_roots: root.hide()
		race.mat.show()
		race.mat.finish.set_shader_parameter("printed_toys",false)
		race.activate()
	else:
		race.deactivate()
		set_world_visible(true)
		resume_maple()
	game.rewards.show()
	for fire in game.get_tree().get_nodes_in_group("toy_fires"): fire.show()
	game.rewards.set_process(true)
	game.truck.world_origin=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
	game.truck.recovery_spawn=ToyRaceTrack.SPAWN if in_race else Vector3(0,1,12)
	var wheel_angle: float=game.truck.wheel_travel
	# Keep the entrance pose and suspension; a full recovery reset caused a
	# visible stop and chassis snap at the moment control became available.
	game.truck.wheel_travel=wheel_angle
	game.truck.global_position=(ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO)+ToyRaceTrack.SPAWN
	# Both mats meet at their north street; arrivals drive inward, heading south.
	game.truck.heading=PI
	game.truck.rotation.y=PI
	game.truck.linear_velocity=Vector3(0,0,6/.825 if short_transition else 5.0*INTRO_PACE)
	game.truck.angular_velocity=Vector3.ZERO
	game.truck.previous_velocity=game.truck.linear_velocity
	game.truck.reset_physics_interpolation()
	game.truck.show()
	game.truck.freeze=false
	game.truck.enabled=true
	game.truck.set_physics_process(true)
	game.truck.pointer_spray_blocked=true
	game.truck.jump_blocked_until_release=true
	game.truck.touch_drive=Vector2.ZERO
	game.truck.touch_aim=Vector2.ZERO
	game.camera_subject=null
	game.camera_requested_subject=null
	game.camera_framing.reset()
	game.camera_trauma=0
	game.conversation_pan=0
	game.conversation_blend=0
	game.camera_focus=game.truck.global_position
	game.camera.global_position=game.camera_focus+game.gameplay_camera_offset()
	game.camera.look_at(game.camera_focus)
	game.camera.size=25.8
	game.camera.v_offset=0
	game.camera.far=500 if in_race else 250
	game.sun.directional_shadow_max_distance=game.gameplay_shadow_distance+maxf(0,game.gameplay_camera_offset().length()-game.camera_offset.length())
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(false)")

func set_world_visible(value: bool) -> void:
	if in_race: race.visible=value
	else:
		for root in maple_roots:
			root.visible=value

func suspend_maple() -> void:
	if not root_modes.is_empty(): return
	for root in maple_roots:
		root_modes.append(root.process_mode)
		root.process_mode=Node.PROCESS_MODE_DISABLED
		for body in root.find_children("*","RigidBody3D",true,false):
			body_states.append({"body":body,"freeze":body.freeze,"velocity":body.linear_velocity,"angular":body.angular_velocity})
			body.freeze=true

func resume_maple() -> void:
	for i in root_modes.size(): maple_roots[i].process_mode=root_modes[i]
	root_modes.clear()
	for saved in body_states:
		if not is_instance_valid(saved.body): continue
		saved.body.freeze=saved.freeze
		saved.body.linear_velocity=saved.velocity
		saved.body.angular_velocity=saved.angular
	body_states.clear()

func begin_assembly(is_race: bool) -> void:
	finish_assembly()
	assembly_progress=-1
	assembly_printed=false
	_set_floor_cut(false)
	assembly_origin=ToyRaceTrack.ORIGIN if is_race else Vector3.ZERO
	var roots: Array[Node3D]=[]
	if is_race: roots.append(race)
	else: roots.assign(maple_roots)
	var whole_toys: Dictionary={}
	for root in roots:
		for node in root.find_children("*","GeometryInstance3D",true,false):
			if not node.is_visible_in_tree() or node.layers==0 or node==race.mat or node==game.playroom.floor_art or node.name=="RacePlayroomFloor": continue
			var boundary:=false
			var backdrop:=false
			var ancestor: Node=node
			while ancestor!=root and ancestor!=null:
				if ancestor.has_meta("room_backdrop") or ancestor.has_meta("assembly_ignore"): backdrop=true
				if ancestor.name=="BoundaryBlocks" or ancestor.get_meta("boundary_blocks",false): boundary=true
				ancestor=ancestor.get_parent()
			if backdrop: continue
			# Animated actors keep their complete hierarchy, including faces and wheels.
			var toy:=TownProps.assembly_owner(node,root)
			if toy:
				if whole_toys.has(toy): continue
				whole_toys[toy]=true
				_append_piece(toy,toy.global_transform,TownProps.visual_bounds(toy),boundary,is_race)
			elif node.get_meta("assembly_vertices",false):
				_append_baked(node,is_race)
			elif node is MultiMeshInstance3D:
				# These batches contain fixed flowers and boundary blocks. Cache
				# their rest records during warmup, rather than rebuilding thousands
				# of bounds, pivots and arrival schedules on a visible town swap.
				var cached: Dictionary=assembly_instances.get(node,{})
				if not cached.is_empty() and cached.transform.is_equal_approx(node.global_transform) and cached.count==node.multimesh.instance_count and cached.mesh==node.multimesh.mesh:
					instance_inverses[node]=cached.inverse
					# Rest transforms/pivots stay immutable; only these animation
					# flags need resetting. Reuse the records instead of allocating
					# thousands of replacement dictionaries during the swap.
					for template in cached.pieces:
						template.settled=false
						template.last_t=-1.0
						template.last_visible=false
						assembly.append(template)
						_queue_piece_audio(template)
				else:
					var first:=assembly.size()
					var bounds: AABB=node.multimesh.mesh.get_aabb()
					var transform: Transform3D=node.global_transform
					for i in node.multimesh.instance_count:
						var pose: Transform3D=transform*node.multimesh.get_instance_transform(i)
						_append_piece(node,pose,bounds,boundary,is_race,i)
					var templates: Array[Dictionary]=[]
					for i in range(first,assembly.size()): templates.append(assembly[i].duplicate())
					assembly_instances[node]={"transform":transform,"inverse":transform.affine_inverse(),"count":node.multimesh.instance_count,"mesh":node.multimesh.mesh,"pieces":templates}
			else:
				if node is MeshInstance3D: TownProps.lock_wood_grain(node)
				_append_piece(node,node.global_transform,node.get_aabb(),boundary,is_race)
	assembly_audio.sort_custom(func(a,b): return a.progress<b.progress)
	grow_assembly(0)

func _append_baked(node: MeshInstance3D, is_race: bool) -> void:
	var original:=node.get_active_material(0) as StandardMaterial3D
	if not original or original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
		_append_piece(node,node.global_transform,node.get_aabb(),false,is_race)
		return
	# Keep the material warmed behind the loading screen. Recreating it at
	# Start or a town swap used to throw that preparation away.
	var finish: ShaderMaterial=assembly_materials.get(node)
	if not finish:
		finish=ShaderMaterial.new()
		finish.shader=preload("res://shaders/toy_arrival.gdshader")
		finish.set_shader_parameter("paint",original.albedo_color)
		finish.set_shader_parameter("vertex_paint",original.vertex_color_use_as_albedo)
		finish.set_shader_parameter("vertex_srgb",original.vertex_color_is_srgb)
		finish.set_shader_parameter("roughness",original.roughness)
		finish.set_shader_parameter("metal",original.metallic)
		finish.set_shader_parameter("specular",original.metallic_specular)
		finish.set_shader_parameter("clearcoat",original.clearcoat if original.clearcoat_enabled else 0.0)
		assembly_materials[node]=finish
	finish.set_shader_parameter("print_mode",false)
	if not baked_schedules.has(node):
		var arrays:=node.mesh.surface_get_arrays(0)
		var pivots: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
		var colours: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		var arrivals:=PackedVector2Array()
		arrivals.resize(pivots.size())
		var toys: Dictionary={}
		var cues: Array[Dictionary]=[]
		var first:=1.0
		var last:=0.0
		for i in pivots.size():
			var kind:=roundi(colours[i].a*4)
			var key:=Vector3i(roundi(pivots[i].x*8),kind,roundi(pivots[i].y*8))
			if toys.has(key):
				arrivals[i]=toys[key]
				continue
			var at:=Vector3(pivots[i].x,0,pivots[i].y)
			var delay:=0.0 if kind==1 else arrival_delay(at,kind,is_race)
			var span:=arrival_span(at,kind,is_race)
			arrivals[i]=Vector2(delay,span)
			toys[key]=arrivals[i]
			first=minf(first,delay)
			last=maxf(last,delay+span)
			if kind==2 or kind==3:
				cues.append({"at":at,"kind":kind,"delay":delay,"span":span,"seed":arrival_seed(at,kind)})
		# These opaque batches have no texture UV requirements in the arrival
		# shader. Store the exact CPU schedule per vertex in its unused UV lane,
		# so batching, audio and animated actors share one timing implementation.
		arrays[Mesh.ARRAY_TEX_UV]=arrivals
		var arrival_mesh:=ArrayMesh.new()
		arrival_mesh.add_surface_from_arrays(node.mesh.surface_get_primitive_type(0),arrays,[],_arrival_lods(node.mesh))
		arrival_mesh.surface_set_material(0,node.mesh.surface_get_material(0))
		baked_arrival_meshes[node]=arrival_mesh
		baked_schedules[node]=Vector2(first,last)
		baked_audio[node]=cues
	for cue in baked_audio.get(node,[]):
		_queue_assembly_audio(node.global_transform*cue.at,cue.kind,cue.delay,cue.span,cue.seed,false)
	var timing: Vector2=baked_schedules[node]
	assembly.append({"node":node,"transform":node.global_transform,"visible":node.visible,"delay":timing.x,"end":timing.y,"drop":false,"flat":false,"instance":-1,"settled":false,"gpu":true,"material":finish,"original_material":node.material_override,"original_mesh":node.mesh,"bounds":node.custom_aabb})
	node.mesh=baked_arrival_meshes[node]
	node.material_override=finish
	# The shader's flying toys must remain inside the batch's culling bounds.
	node.custom_aabb=node.mesh.get_aabb().grow(25)

static func _arrival_lods(source: ArrayMesh) -> Dictionary:
	# Reuse the exported simplifications instead of rebuilding LODs in Web or
	# drawing every distant triangle while an arrival material is active.
	var surfaces: Array=source.get("_surfaces")
	var surface: Dictionary=surfaces[0]
	var packed: Array=surface.get("lods",[])
	var lods: Dictionary={}
	var stride: int=surface.index_data.size()/maxi(1,surface.index_count)
	for i in range(0,packed.size(),2):
		var data: PackedByteArray=packed[i+1]
		var indices: PackedInt32Array
		if stride==4: indices=data.to_int32_array()
		else:
			indices.resize(data.size()/2)
			for j in indices.size(): indices[j]=data.decode_u16(j*2)
		lods[packed[i]]=indices
	return lods

func _append_piece(node: Node3D, pose: Transform3D, bounds: AABB, boundary: bool, is_race: bool, instance: int=-1) -> void:
	var center: Vector3=pose*bounds.get_center()-assembly_origin
	if node.has_meta("toy_arrival") or node is RigidBody3D or node.name=="Neighbour": center=pose.origin-assembly_origin
	var pivot: Vector3=pose*bounds.get_center() if instance>=0 else pose.origin
	var shared_pivot: Vector3=node.get_meta("toy_pivot",Vector3.INF)
	if instance>=0 and node.has_meta("toy_pivots"): shared_pivot=node.get_meta("toy_pivots")[instance]
	if shared_pivot.is_finite():
		pivot=node.global_transform*shared_pivot if instance>=0 else node.get_parent().global_transform*shared_pivot
		center=pivot-assembly_origin
	var dimensions: Vector3=(pose.basis*bounds.size).abs()
	var flat:=not shared_pivot.is_finite() and (absf(dimensions.y)<.35 or absf(dimensions.x)>140 and absf(dimensions.z)>140 and absf(dimensions.y)<2)
	var sprout:=not boundary and TownProps.small_arrival(node,dimensions)
	var fade: bool=node.get_meta("toy_arrival","")=="fade"
	if fade: sprout=false; flat=false
	# Small flowers/leaves share the sprout path even when their height is flat.
	if sprout: flat=false; pivot.y=assembly_origin.y
	var drop: bool=not fade and not sprout and (boundary or node.get_meta("toy_arrival","")!="grow" and not node.has_meta("assembly_group"))
	var kind:=4 if sprout else 3 if drop else 2
	var seed:=arrival_seed(center,kind)
	var delay:=perimeter_delay(center,is_race) if boundary else arrival_delay(center,kind,is_race)
	var span:=arrival_span(center,kind,is_race)
	# Counter the faster tour clock for perimeter toys only. Their individual
	# falls stay the same length while successive blocks start closer together.
	if boundary: span*=INTRO_PACE
	var featured:=not is_race and (kind==2 and center.distance_to(first_house(false))<8 or kind==3 and center.distance_to(first_house(false))<20)
	if not is_race and node is BreakableProp and node.kind=="tree" and center.distance_to(first_house(false))<32:
		delay=.045+seed*.015
		featured=true
	if not is_race and node in game.town.people and center.distance_to(first_house(false))<25:
		delay=.10+seed*.01
		featured=true
	if not is_race and node==game.town.dog:
		delay=(5.05-ARRIVAL_START)/(ARRIVAL_END-ARRIVAL_START)
		span=.9/(ARRIVAL_END-ARRIVAL_START)
		featured=false
	if is_race and node.has_meta("toy_pivot") and node.has_meta("assembly_group"):
		# Finish lifting the complete driving ribbon before any arch can land.
		delay=.003
		span=1.15/(ARRIVAL_END-RACE_ARRIVAL_START)
	if is_race and node in race.spectators and Vector2(center.x,center.z).distance_to(Vector2(ToyRaceTrack.WEST_STAND.x,ToyRaceTrack.WEST_STAND.z))<15:
		delay=(16.9+seed*.55-RACE_ARRIVAL_START)/(ARRIVAL_END-RACE_ARRIVAL_START)
		span=1.1/(ARRIVAL_END-RACE_ARRIVAL_START)
	if is_race and node in race.spectators and Vector2(center.x,center.z).distance_to(Vector2(73,-22))<12:
		delay=(7.85+seed*.35-RACE_ARRIVAL_START)/(ARRIVAL_END-RACE_ARRIVAL_START)
		span=1.1/(ARRIVAL_END-RACE_ARRIVAL_START)
	# Upper stacked blocks land after the beam beneath them.
	if boundary: delay+=minf(.010,maxf(0,center.y-3)*.004)
	if instance>=0 and not instance_inverses.has(node): instance_inverses[node]=node.global_transform.affine_inverse()
	var fade_parts: Array=[]
	if fade:
		if not bird_finishes.has(node):
			for mesh in node.find_children("*","MeshInstance3D",true,false):
				var original:=mesh.get_active_material(0) as StandardMaterial3D
				if not original: continue
				var finish:=original.duplicate() as StandardMaterial3D
				finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				fade_parts.append({"mesh":mesh,"original":mesh.material_override,"finish":finish})
			bird_finishes[node]=fade_parts
		fade_parts=bird_finishes[node]
	assembly.append({"node":node,"transform":pose,"visible":node.visible,"delay":delay,"span":.07 if featured else span,"drop":drop,"fade":fade,"fade_parts":fade_parts,"sprout":sprout,"flat":flat,"instance":instance,"inverse":instance_inverses.get(node,Transform3D.IDENTITY),"settled":false,"gpu":false,"seed":seed,"pivot":pivot,"boundary":boundary,"last_t":-1.0,"last_visible":false})
	_queue_piece_audio(assembly[-1])

func _queue_piece_audio(item: Dictionary) -> void:
	if item.flat or item.sprout or item.fade or not item.visible: return
	_queue_assembly_audio(item.pivot,3 if item.drop else 2,item.delay,item.span,item.seed,item.boundary)

func _queue_assembly_audio(at: Vector3, kind: int, delay: float, span: float, seed: float, boundary: bool) -> void:
	# Opaque art can split one house into several material batches. One toy
	# still gets one cue, with small details and birds left out of the chorus.
	var key:=Vector4i(roundi(at.x*8),roundi(at.y*8),roundi(at.z*8),kind)
	if assembly_audio_keys.has(key): return
	assembly_audio_keys[key]=true
	if kind==3 and not boundary and seed<.4: return
	assembly_audio.append({"at":at,"kind":"block_land" if boundary else "house_grow" if kind==2 else "plastic","progress":delay+span*(.08 if kind==2 else .68),"strength":.85 if boundary else .65 if kind==2 else .55,"pitch":.92+seed*.16,"contact":"impact"})
	if boundary:
		# The first bounce returns to the mat at .84 of the drop animation.
		# A quieter second contact carries the cascade through its last blocks.
		assembly_audio.append({"at":at,"kind":"block_land","progress":delay+span*.84,"strength":.38,"pitch":1.02+seed*.12,"contact":"rebound"})

func _play_assembly_audio(progress: float) -> void:
	if progress<assembly_progress:
		assembly_audio_index=0
		while assembly_audio_index<assembly_audio.size() and assembly_audio[assembly_audio_index].progress<=progress: assembly_audio_index+=1
		return
	var nearby: Dictionary={}
	while assembly_audio_index<assembly_audio.size() and assembly_audio[assembly_audio_index].progress<=progress:
		var cue:=assembly_audio[assembly_audio_index]
		assembly_audio_index+=1
		# Scrubbing/skipping a tour must not play a burst of overdue impacts.
		if game.loading or not game.sounds or progress-cue.progress>.018: continue
		if cue.kind=="block_land" and not _perimeter_sound_in_view(cue.at,progress): continue
		game.sounds._update_listener()
		var distance: float=game.sounds.listener.global_position.distance_squared_to(cue.at)
		if not nearby.has(cue.kind) or distance<nearby[cue.kind].distance:
			nearby[cue.kind]={"cue":cue,"distance":distance}
	for entry in nearby.values():
		var cue: Dictionary=entry.cue
		game.sounds.play(cue.kind,cue.at,cue.strength,.065 if cue.kind=="block_land" else .18 if cue.kind=="house_grow" else .10,cue.pitch)

func _perimeter_sound_in_view(at: Vector3, progress: float) -> bool:
	if in_race: return true
	if not in_race:
		# Only the west/south reveal gets a wooden cascade. The camera then
		# turns north into town; distant remaining edges assemble quietly.
		var elapsed:=ARRIVAL_START+progress*(ARRIVAL_END-ARRIVAL_START)
		var local:=at-assembly_origin
		if elapsed>11.2 or not (local.x< -75 or local.z>75): return false
	return Rect2(Vector2(-24,-24),game.hud.size+Vector2(48,48)).has_point(game.camera.unproject_position(at))

func grow_assembly(progress: float) -> void:
	mat.set_arrival_progress(progress)
	if progress==assembly_progress: return
	if assembly_printed:
		for item in assembly:
			if item.gpu: item.material.set_shader_parameter("print_mode",false); item.settled=false
		assembly_printed=false
	for item in assembly:
		if not is_instance_valid(item.node): continue
		if item.gpu:
			item.node.visible=item.visible and progress>item.delay
			if item.settled and progress>=assembly_progress: continue
			if not item.node.visible: continue
			item.material.set_shader_parameter("progress",progress)
			item.settled=progress>=item.end
			item.node.custom_aabb=item.bounds if item.settled else item.node.mesh.get_aabb().grow(25)
			continue
		if item.settled and progress>=assembly_progress: continue
		var t:=clampf((progress-item.delay)/item.span,0,1)
		var pose: Transform3D=item.transform
		var visible: bool=item.visible and (progress>0 if item.flat else t>0)
		# Pending toys already have their hidden pose. Only animate a toy whose
		# state changed, rather than rewriting thousands of identical transforms.
		if t==item.last_t and visible==item.last_visible: continue
		item.last_t=t
		item.last_visible=visible
		item.settled=t>=1 or item.flat and progress>0
		if item.fade:
			for part in item.fade_parts:
				part.finish.albedo_color.a=smoothstep(0,1,t)
				part.mesh.material_override=part.original if t>=1 else part.finish
		elif item.flat: pass
		elif item.sprout:
			var size:=maxf(.001,smoothstep(0,1,t))
			pose.origin=item.pivot+(pose.origin-item.pivot)*size
			pose.basis=Basis.from_scale(Vector3.ONE*size)*pose.basis
		elif item.drop:
			# Deterministic ballistic fall, rebound and damped tumble; no live simulation.
			var impact:=clampf((t-.68)/.32,0,1)
			var fall:=maxf(0,1-pow(t/.68,2))
			var bounce:=absf(sin(impact*TAU)*exp(-impact*3)*.7)
			var tilt: float=(1-smoothstep(0,.68,t))*.65+sin(impact*PI*3)*(1-impact)*.16
			var rotation:=Basis.from_euler(Vector3(tilt*(item.seed-.5),0,tilt*(1 if item.seed>.5 else -1)))
			pose.origin=item.pivot+rotation*(pose.origin-item.pivot)+Vector3.UP*(19*fall+bounce)
			pose.basis=rotation*pose.basis
		else:
			var height:=maxf(.001,smoothstep(0,.88,t)+sin(t*PI)*.065)
			pose.origin.y=assembly_origin.y+(pose.origin.y-assembly_origin.y)*height
			pose.basis=Basis.from_scale(Vector3(1,height,1))*pose.basis
		if item.instance>=0:
			if not visible: pose.basis=Basis.from_scale(Vector3.ONE*.00001)*pose.basis
			item.node.multimesh.set_instance_transform(item.instance,item.inverse*pose)
		else:
			item.node.global_transform=pose
			item.node.visible=visible
			item.node.reset_physics_interpolation()
	_play_assembly_audio(progress)
	assembly_progress=progress

func flatten_for_print() -> void:
	assembly_progress=-1
	assembly_printed=true
	for item in assembly:
		if item.gpu:
			item.material.set_shader_parameter("print_mode",true)
			item.node.visible=item.visible
			continue
		item.last_t=-1.0
		item.settled=false
		var pose: Transform3D=item.transform
		pose.origin.y=assembly_origin.y+(pose.origin.y-assembly_origin.y)*.001
		pose.basis=Basis.from_scale(Vector3(1,.001,1))*pose.basis
		if item.instance>=0: item.node.multimesh.set_instance_transform(item.instance,item.inverse*pose)
		else: item.node.global_transform=pose; item.node.visible=item.visible

func finish_assembly() -> void:
	_set_floor_cut(true)
	for item in assembly:
		if is_instance_valid(item.node):
			if item.gpu:
				item.node.material_override=item.original_material
				item.node.mesh=item.original_mesh
				item.node.custom_aabb=item.bounds
				item.node.visible=item.visible
				continue
			# Settled toys already have their final pose. Avoid rewriting every
			# flower, block and tree at the exact frame control is handed back.
			if item.settled: continue
			if item.instance>=0:
				item.node.multimesh.set_instance_transform(item.instance,item.node.global_transform.affine_inverse()*item.transform)
			else:
				item.node.global_transform=item.transform
				item.node.visible=item.visible
				for part in item.fade_parts: part.mesh.material_override=part.original
				item.node.reset_physics_interpolation()
	assembly.clear()
	assembly_audio.clear()
	assembly_audio_keys.clear()
	assembly_audio_index=0
	instance_inverses.clear()
