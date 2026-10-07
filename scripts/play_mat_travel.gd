class_name PlayMatTravel
extends Node

const DURATION:=26.0
const ARRIVAL_START:=6.5
const ARRIVAL_END:=21.5
const EXIT_Z:=-82.0
var game: Node3D
var race: ToyRaceTrack
var mat: RollingMat
var active:=false
var in_race:=false
var destination_race:=false
var swapped:=false
var clock:=0.0
var exit_armed:=false
var north_gate: StaticBody3D
var gate_art: Node3D
var gate_opening:=0.0
var maple_roots: Array[Node3D]=[]
var body_states: Array[Dictionary]=[]
var root_modes: Array[int]=[]
var assembly: Array[Dictionary]=[]
var assembly_origin:=Vector3.ZERO
var assembly_progress:=-1.0
var race_visited:=false
var short_transition:=false
var duration:=DURATION
var title: TownTitle
var cover: ColorRect

func _ready() -> void:
	name="PlayMatTravel"
	maple_roots=[game.town,game.atmosphere,game.life,game.gardens,game.pool_basin,game.ramps,game.interactions,game.railway,game.dog_puddle,game.barbecue,game.playroom]
	mat=RollingMat.new()
	game.add_child(mat)
	race=ToyRaceTrack.new()
	race.game=game
	game.add_child(race)
	_open_north_street()
	cover=ColorRect.new()
	cover.color=Color("eee2cc")
	cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.hud.add_child(cover)
	cover.hide()

	title=TownTitle.new()
	game.hud.add_child(title)
	title.set_race_title()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.hide()

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
	gate_art=Node3D.new()
	game.playroom.add_child(gate_art)
	gate_art.position=Vector3(0,0,-80)
	var block:=TownProps.box(gate_art,Vector3.UP*1.5,Vector3(12,3,2.8),Color.WHITE)
	block.material_override=Playroom.wood_finish(Color("cd795f"),false,true)
	north_gate=StaticBody3D.new()
	north_gate.collision_layer=Playroom.WALL_LAYER
	gate_art.add_child(north_gate)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(12,12,2.8)
	shape.shape=box
	shape.position.y=3
	north_gate.add_child(shape)

func _process(dt: float) -> void:
	if game.paused or game.loading: return
	if active:
		_update_transition(dt)
		return
	if game.intro.active: return
	var target:=1.0 if game.railway.started else 0.0
	if not in_race and gate_opening!=target:
		gate_opening=move_toward(gate_opening,target,dt*.65)
		gate_art.position.x=14*smoothstep(0,1,gate_opening)
		north_gate.collision_layer=0 if gate_opening>=.99 else Playroom.WALL_LAYER
	var local: Vector3=game.truck.global_position-(ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO)
	# Moving away from the arrival clears the latch, so arrival cannot bounce
	# straight back into a second loading sequence.
	if local.z> -76: exit_armed=true
	if exit_armed and local.z<EXIT_Z and absf(local.x)<7.0 and (in_race or gate_opening>=.99): start(not in_race)

func start(to_race: bool) -> void:
	if active or game.rescue_running: return
	finish_assembly()
	active=true
	destination_race=to_race
	short_transition=not to_race or race_visited
	duration=2.8 if short_transition else DURATION
	swapped=false
	clock=0
	exit_armed=false
	game.end_dialogue()
	game.hud.map_open=false
	game.truck.freeze=true
	game.truck.enabled=false
	game.truck.set_physics_process(false)
	game.truck.charge=0
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO
	game.refill_hose.update(null,1)
	game.truck.hide()
	game.marker.hide()
	race.timer_label.hide()
	game.rewards.hide()
	game.rewards.set_process(false)
	if in_race:
		race.suspend_bodies()
		race.process_mode=Node.PROCESS_MODE_DISABLED
	else: suspend_maple()
	set_world_visible(true)
	begin_assembly(in_race)
	grow_assembly(0)
	# Keep only the wooden floor behind the outgoing printed carpet.
	if in_race: race.mat.hide()
	title.visible=to_race and not short_transition
	title.reveal=0
	title.opacity=0
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(true)")
	_update_transition(0)

func _update_transition(dt: float) -> void:
	clock+=dt
	if clock>=duration: finish(); return
	if short_transition:
		_update_short_transition()
		return
	var centre:=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
	if clock<2.0:
		mat.show_mat(in_race,smoothstep(.1,1.9,clock),centre)
	elif not swapped:
		swapped=true
		in_race=destination_race
		centre=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
		finish_assembly()
		# Hide the old mat and its toys before revealing the destination floor.
		if in_race:
			for root in maple_roots: root.hide()
		else: race.hide()
		set_world_visible(true)
		begin_assembly(in_race)
	if swapped:
		centre=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
		var elapsed:=clock-2
		mat.show_mat(in_race,1-smoothstep(.15,4.3,elapsed),centre)
		grow_assembly(arrival_progress(elapsed))
		# Keep the actual flat printed houses under the rising toys throughout the
		# close shots; lower the poster back into the felt once assembly is complete.
		mat.visible=elapsed<22.3
		if elapsed>=4.3: mat.position.y=centre.y+lerpf(.14,-.08,smoothstep(21.5,22.3,elapsed))
		if in_race:
			race.mat.visible=elapsed>=4.3
			race.mat.finish.set_shader_parameter("printed_toys",false)
		assembly_camera(elapsed,in_race)
		title.reveal=smoothstep(2,19,elapsed)
		title.opacity=smoothstep(1.4,2.2,elapsed)*(1-smoothstep(22,23.7,elapsed))
		title.queue_redraw()
	else:
		mat_camera(centre,1-clock/2)
	if clock>=23.5:
		var entry:=smoothstep(23.5,DURATION,clock)
		game.truck.global_position=centre+Vector3(0,.82,lerpf(-83,-73,entry))
		game.truck.heading=PI
		game.truck.rotation.y=PI
		game.truck.reset_physics_interpolation()
		game.truck.show()
		var focus: Vector3=(centre+tour_focus(clock-2,in_race)).lerp(game.truck.global_position,entry)
		game.camera.position=focus+cinematic_offset(Vector3(19,15,22).lerp(game.camera_offset,entry))
		game.camera.look_at(focus)
		game.camera.size=lerpf(tour_lens(clock-2,in_race),25.8,entry)
	cover.visible=clock>1.8 and clock<2.3
	cover.color.a=sin(clampf((clock-1.8)/.5,0,1)*PI)

func _update_short_transition() -> void:
	var centre:=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
	if clock<1.4:
		mat.show_mat(in_race,smoothstep(0,1.05,clock),centre)
		var put_aside:=smoothstep(1.05,1.4,clock)
		mat.position.x+=put_aside*190
		mat.position.y+=sin(put_aside*PI)*9
	elif not swapped:
		swapped=true
		finish_assembly()
		if in_race: race.hide()
		else:
			for root in maple_roots: root.hide()
		in_race=destination_race
		set_world_visible(true)
		begin_assembly(in_race)
		grow_assembly(0)
		if in_race: race.mat.hide()
	if swapped:
		centre=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
		mat.show_mat(in_race,1-smoothstep(1.4,2.65,clock),centre)
	mat_camera(centre,clampf(clock/duration,0,1))
	cover.visible=clock>1.33 and clock<1.48
	cover.color.a=sin(clampf((clock-1.33)/.15,0,1)*PI)

func mat_camera(centre: Vector3, progress: float) -> void:
	var aspect: float=game.hud.size.x/maxf(1,game.hud.size.y)
	var focus:=centre+Vector3(0,4,45).lerp(Vector3(0,0,-12),progress)
	game.camera.position=focus+Vector3(90,95,110).lerp(Vector3(96,116,124),progress)*2.4
	game.camera.look_at(focus)
	game.camera.size=maxf(lerpf(175,185,progress),185/maxf(.6,aspect))
	game.camera.far=900
	game.camera.near=.05
	game.camera.v_offset=0

static func arrival_progress(elapsed: float) -> float:
	return clampf((elapsed-ARRIVAL_START)/(ARRIVAL_END-ARRIVAL_START),0,1)

static func first_house(is_race: bool) -> Vector3:
	return Vector3(-26,0,-67) if is_race else Vector3(-49,0,-22)

# Arrival timing is independent of the camera. Quantized integer arithmetic
# also gives the CPU toys and baked vertex shader the same deterministic hash.
static func arrival_seed(at: Vector3, kind: int) -> float:
	var h:=posmod(int(floor(at.x*8+.5))*73+int(floor(at.z*8+.5))*151,997)
	return float(posmod(h*h*13+h*71+kind*83,997))/997.0

static func arrival_delay(at: Vector3, kind: int, is_race: bool=false) -> float:
	var seed:=arrival_seed(at,kind)
	var distance:=Vector2(at.x,at.z).distance_to(Vector2(first_house(is_race).x,first_house(is_race).z))
	if kind==2 and distance<8: return .015
	if kind==3 and distance<20: return .095+seed*.045
	# Density increases toward the end, while births remain scattered globally.
	return .28+sqrt(seed)*.54

static func perimeter_delay(at: Vector3) -> float:
	# The cascade starts after the first house, trees and neighbour have arrived.
	if absf(at.x)>=absf(at.z):
		if at.x<0: return .27+.20*clampf((at.z+81)/162,0,1)
		return .47+.37*(162+clampf(81-at.z,0,162))/486.0
	if at.z>0: return .47+.37*clampf(at.x+81,0,162)/486.0
	return .47+.37*(324+clampf(81-at.x,0,162))/486.0

static func tour_focus(elapsed: float, is_race: bool) -> Vector3:
	var times: Array[float]=[6.8,9.8,11.8,13.1,14.5,15.8,17.0,18.5,20.1,21.5]
	var points: Array[Vector3]=[
		Vector3(-49,1,-22),Vector3(-46,1,-19),Vector3(-80,1,-54),Vector3(-80,1,3),
		Vector3(-67,1,42),Vector3(-32,1,26),Vector3(-15,1,13),Vector3(18,1,-10),Vector3(47,1,-23),Vector3(48,1,-20)]
	if is_race:
		points=[Vector3(-26,1,-67),Vector3(-23,1,-65),Vector3(-80,1,-54),Vector3(-80,1,3),
			Vector3(-68,1,34),Vector3(-36,2,10),Vector3(0,6,4),Vector3(26,3,22),Vector3(51,1,38),Vector3(53,1,38)]
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
		# Time-aware Hermite tangents keep velocity continuous through turns.
		return (2*t*t*t-3*t*t+1)*points[i]+(t*t*t-2*t*t+t)*duration*v0+(-2*t*t*t+3*t*t)*points[i+1]+(t*t*t-t*t)*duration*v1
	return points[-1]

func tour_lens(elapsed: float, is_race: bool) -> float:
	var pullback:=smoothstep(10.0,11.8,elapsed)
	var turn:=smoothstep(13.1,16.0,elapsed)
	var portrait_lens: float=32/maxf(.65,game.hud.size.x/maxf(1,game.hud.size.y))
	var lens:=lerpf(lerpf(32,56,pullback),34,turn)
	return maxf(maxf(38,lens) if is_race else lens,portrait_lens)

static func cinematic_offset(direction: Vector3) -> Vector3:
	# Orthographic size controls framing independently of physical distance.
	# Keep the lens outside the entire mat/falling-toy envelope even during close
	# shots, rather than letting foreground objects cross the camera's near plane.
	return direction.normalized()*maxf(330,direction.length())

func assembly_camera(elapsed: float, is_race: bool) -> void:
	var centre:=ToyRaceTrack.ORIGIN if is_race else Vector3.ZERO
	if elapsed<5.6:
		mat_camera(centre,clampf(elapsed/4.8,0,1))
		return
	var focus:=tour_focus(elapsed,is_race)+centre
	var pullback:=smoothstep(10.0,11.8,elapsed)
	var turn:=smoothstep(13.1,16.0,elapsed)
	var offset:=Vector3(19,15,22).lerp(Vector3(30,24,24),pullback).lerp(Vector3(19,15,22),turn)
	var sweep:=smoothstep(5.6,6.8,elapsed)
	var overview_focus:=centre+Vector3(0,0,-12)
	var camera_focus:=overview_focus.lerp(focus,sweep)
	game.camera.position=camera_focus+cinematic_offset((Vector3(96,116,124)*2.4).lerp(offset,sweep))
	game.camera.look_at(camera_focus)
	var overview_lens:=maxf(185,185/maxf(.6,game.hud.size.x/maxf(1,game.hud.size.y)))
	game.camera.size=lerpf(overview_lens,tour_lens(elapsed,is_race),sweep)
	game.camera.v_offset=0
	game.camera.far=900
	game.camera.near=.05

func finish() -> void:
	if not active: return
	if not swapped:
		in_race=destination_race
		if in_race: race.show()
		else: set_world_visible(true)
	active=false
	finish_assembly()
	mat.hide()
	cover.hide()
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
	game.rewards.set_process(true)
	game.truck.world_origin=ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO
	game.truck.recovery_spawn=ToyRaceTrack.SPAWN if in_race else Vector3(0,1,12)
	game.truck.reset_truck()
	game.truck.global_position=(ToyRaceTrack.ORIGIN if in_race else Vector3.ZERO)+ToyRaceTrack.SPAWN
	# Both mats meet at their north street; arrivals drive inward, heading south.
	game.truck.heading=PI
	game.truck.rotation.y=PI
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
	game.conversation_blend=0
	game.camera_blend_from=0
	game.camera_blend_to=0
	game.camera_focus=game.truck.global_position
	game.camera.global_position=game.camera_focus+game.camera_offset
	game.camera.look_at(game.camera_focus)
	game.camera.size=25.8
	game.camera.far=250
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(false)")
	game.toast("Follow the numbered arches · north road to Maple Bay" if in_race else "Back in Maple Bay. Your jobs are right where you left them.")

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
	game.playroom.floor_art.material_override.set_shader_parameter("cut_pool",false)
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
				if ancestor.has_meta("room_backdrop"): backdrop=true
				if ancestor.name=="BoundaryBlocks" or ancestor==gate_art: boundary=true
				ancestor=ancestor.get_parent()
			if backdrop: continue
			# Animated actors keep their complete hierarchy, including faces and wheels.
			var toy:=TownProps.assembly_owner(node,root)
			if toy:
				if whole_toys.has(toy): continue
				whole_toys[toy]=true
				_append_piece(toy,toy.global_transform,AABB(Vector3.ZERO,Vector3(1,1,1)),boundary,is_race)
			elif node.get_meta("assembly_vertices",false):
				_append_baked(node,is_race)
			elif node is MultiMeshInstance3D:
				for i in node.multimesh.instance_count:
					var pose: Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
					_append_piece(node,pose,node.multimesh.mesh.get_aabb(),boundary,is_race,i)
			else:
				if node is MeshInstance3D: TownProps.lock_wood_grain(node)
				_append_piece(node,node.global_transform,node.get_aabb(),boundary,is_race)
	grow_assembly(0)

func _append_baked(node: MeshInstance3D, is_race: bool) -> void:
	var original:=node.get_active_material(0) as StandardMaterial3D
	if not original or original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
		_append_piece(node,node.global_transform,node.get_aabb(),false,is_race)
		return
	var finish:=ShaderMaterial.new()
	finish.shader=preload("res://shaders/toy_arrival.gdshader")
	finish.set_shader_parameter("paint",original.albedo_color)
	finish.set_shader_parameter("vertex_paint",original.vertex_color_use_as_albedo)
	finish.set_shader_parameter("vertex_srgb",original.vertex_color_is_srgb)
	finish.set_shader_parameter("hero",Vector2(first_house(is_race).x,first_house(is_race).z))
	finish.set_shader_parameter("roughness",original.roughness)
	finish.set_shader_parameter("metal",original.metallic)
	finish.set_shader_parameter("specular",original.metallic_specular)
	finish.set_shader_parameter("clearcoat",original.clearcoat if original.clearcoat_enabled else 0.0)
	assembly.append({"node":node,"transform":node.global_transform,"visible":node.visible,"delay":0.0,"drop":false,"flat":false,"instance":-1,"settled":false,"gpu":true,"material":finish,"original_material":node.material_override,"bounds":node.custom_aabb})
	node.material_override=finish
	# The shader's flying toys must remain inside the batch's culling bounds.
	node.custom_aabb=node.mesh.get_aabb().grow(25)

func _append_piece(node: Node3D, pose: Transform3D, bounds: AABB, boundary: bool, is_race: bool, instance: int=-1) -> void:
	var center: Vector3=pose*bounds.get_center()-assembly_origin
	if node.has_meta("toy_arrival") or node is RigidBody3D or node.name=="Neighbour": center=pose.origin-assembly_origin
	var pivot: Vector3=pose*bounds.get_center() if instance>=0 else pose.origin
	var shared_pivot: Vector3=node.get_meta("toy_pivot",Vector3.INF)
	if instance>=0 and node.has_meta("toy_pivots"): shared_pivot=node.get_meta("toy_pivots")[instance]
	if shared_pivot.is_finite():
		pivot=node.global_transform*shared_pivot if instance>=0 else node.get_parent().global_transform*shared_pivot
		center=pivot-assembly_origin
	var dimensions: Vector3=pose.basis*bounds.size
	var flat:=not shared_pivot.is_finite() and (absf(dimensions.y)<.35 or absf(dimensions.x)>140 and absf(dimensions.z)>140 and absf(dimensions.y)<2)
	var drop: bool=boundary or node.get_meta("toy_arrival","")!="grow" and not node.has_meta("assembly_group")
	var kind:=3 if drop else 2
	var seed:=arrival_seed(center,kind)
	var delay:=perimeter_delay(center) if boundary else arrival_delay(center,kind,is_race)
	if node is BreakableProp and node.kind=="tree" and center.distance_to(first_house(is_race))<32:
		delay=.08+seed*.03
	if node in (race.people if is_race else game.town.people) and center.distance_to(first_house(is_race))<25:
		delay=.18+seed*.015
	# Upper stacked blocks land after the beam beneath them.
	if boundary: delay+=minf(.010,maxf(0,center.y-3)*.004)
	assembly.append({"node":node,"transform":pose,"visible":node.visible,"delay":delay,"drop":drop,"flat":flat,"instance":instance,"settled":false,"gpu":false,"seed":seed,"pivot":pivot,"boundary":boundary})

func grow_assembly(progress: float) -> void:
	for item in assembly:
		if not is_instance_valid(item.node): continue
		if item.gpu:
			item.material.set_shader_parameter("print_mode",false)
			item.material.set_shader_parameter("progress",progress)
			continue
		if item.settled and progress>=assembly_progress: continue
		var t:=clampf((progress-item.delay)/(.12 if item.drop else .155),0,1)
		var pose: Transform3D=item.transform
		var visible: bool=item.visible and (progress>0 if item.flat else t>0)
		item.settled=t>=1 or item.flat and progress>0
		if item.flat: pass
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
			item.node.multimesh.set_instance_transform(item.instance,item.node.global_transform.affine_inverse()*pose)
		else:
			item.node.global_transform=pose
			item.node.visible=visible
			item.node.reset_physics_interpolation()
	assembly_progress=progress

func flatten_for_print() -> void:
	for item in assembly:
		if item.gpu:
			item.material.set_shader_parameter("print_mode",true)
			continue
		var pose: Transform3D=item.transform
		pose.origin.y=assembly_origin.y+(pose.origin.y-assembly_origin.y)*.001
		pose.basis=Basis.from_scale(Vector3(1,.001,1))*pose.basis
		if item.instance>=0: item.node.multimesh.set_instance_transform(item.instance,item.node.global_transform.affine_inverse()*pose)
		else: item.node.global_transform=pose; item.node.visible=item.visible

func finish_assembly() -> void:
	game.playroom.floor_art.material_override.set_shader_parameter("cut_pool",true)
	for item in assembly:
		if is_instance_valid(item.node):
			if item.gpu:
				item.node.material_override=item.original_material
				item.node.custom_aabb=item.bounds
				continue
			if item.instance>=0:
				item.node.multimesh.set_instance_transform(item.instance,item.node.global_transform.affine_inverse()*item.transform)
			else:
				item.node.global_transform=item.transform
				item.node.visible=item.visible
				item.node.reset_physics_interpolation()
	assembly.clear()
