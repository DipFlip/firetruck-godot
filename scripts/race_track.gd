class_name ToyRaceTrack
extends Node3D

const ORIGIN:=Vector3(400,0,0)
const SPAWN:=Vector3(0,1,-73)
const SAVE_PATH:="user://race_record_v2.cfg"
static var GATES: Array[Vector2]:
	get:
		var result: Array[Vector2]=[]
		for i in 4:
			var p:=RaceCourse.gate_position(i)
			result.append(Vector2(p.x,p.z))
		return result
var game: Node3D
var mat: RollingMat
var active:=false
var running:=false
var lap_time:=0.0
var last_time:=0.0
var best_time:=0.0
var checkpoint:=0
var previous:=Vector2.ZERO
var billboard: Label3D
var timer_label: Label
var checkpoint_flag: Node3D
var jobs: Array[Dictionary]=[]
var hydrant: BreakableProp
var status_clock:=0.0
var previous_height:=.82
var props: Array[BreakableProp]=[]
var suspended_bodies: Array[Dictionary]=[]
var gates: Array[Node3D]=[]
var people: Array[Node3D]=[]
var spectators: Array[Node3D]=[]
var walkers: Array[Dictionary]=[]
var chatter_latches: Dictionary={}
var animation_clock:=0.0
var ducks: Array[Node3D]=[]
const NAMES: Array[String]=["KIT","SAMI","NORA"]
const HYDRANT_POINT:=Vector3(-12,0,-68)

func _ready() -> void:
	name="ToyRaceTrack"
	position=ORIGIN
	var saved:=ConfigFile.new()
	if saved.load(SAVE_PATH)==OK:
		var record: Variant=saved.get_value("race","best_seconds",0.0)
		if record is float or record is int:
			if is_finite(float(record)) and float(record)>0: best_time=float(record)
	var room_floor:=MeshInstance3D.new()
	room_floor.name="RacePlayroomFloor"
	var floor_plane:=PlaneMesh.new()
	floor_plane.size=Vector2(800,800)
	room_floor.mesh=floor_plane
	room_floor.material_override=Playroom.wood_finish(Color("c6a47e"),true)
	room_floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(room_floor)
	room_floor.position.y=-1.03
	Playroom.make_room_props(self)
	mat=RollingMat.new()
	add_child(mat)
	mat.show_mat(true,0)
	mat.position=Vector3(0,.03,0)
	mat.finish.set_shader_parameter("printed_toys",false)
	TownProps.collider(self,Vector3(0,-.5,0),Vector3(160,1,160))
	_build_course()
	_build_boundary()
	var buildings:=Node3D.new()
	buildings.name="ToyBuildings"
	add_child(buildings)
	_build_paddock(buildings)
	_make_breakable_scenery(buildings)
	for i in 4: _make_gate(buildings,i)
	var board:=TownProps.toy_group(buildings,Vector3(18,0,-68),"drop","RecordBoard")
	TownProps.box(board,Vector3(0,3.4,0),Vector3(14,5,.65),Color("426674"),true)
	for x in [-5,5]: TownProps.box(board,Vector3(x,1.4,0),Vector3(.4,2.8,.4),Color("c9a978"))
	billboard=TownProps.label(board,Vector3(0,3.7,.4),"",40)
	billboard.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	billboard.pixel_size=.025
	billboard.font=preload("res://assets/fonts/Nunito.ttf")
	_update_billboard()
	# Optional hose jobs share the truck's existing hit and aiming paths.
	var spill:=TownProps.box(self,Vector3(58,.045,7),Vector3(7,.025,5),Color("765d4b"))
	jobs.append({"title":"Rinse the pit-lane spill","point":Vector3(58,.06,7),"radius":4.5,"progress":0.0,"mesh":spill,"done":false})
	var heat:=TownProps.ball(self,Vector3(62,1.9,16),Vector3(1.8,2.3,1.8),Color("f3a653"))
	heat.material_override=TownProps.effect_material(preload("res://shaders/flame.gdshader"))
	jobs.append({"title":"Cool the food-stand flare-up","point":Vector3(62,1.9,16),"radius":2.6,"progress":0.0,"mesh":heat,"done":false})
	var dirt:=TownProps.box(self,Vector3(43,1.8,50.97),Vector3(5.6,1.8,.03),Color("8d765d"))
	jobs.append({"title":"Wash the dusty camper","point":Vector3(43,1.8,51),"radius":3.8,"progress":0.0,"mesh":dirt,"done":false})
	_make_hydrant(HYDRANT_POINT)
	checkpoint_flag=Node3D.new()
	add_child(checkpoint_flag)
	checkpoint_flag.hide()
	# Batch only fixed decoration; mission overlays and record text stay separate.
	var fixed: Array[Node]=buildings.find_children("*","MeshInstance3D",true,false)
	for mesh_node in fixed:
		if mesh_node is MeshInstance3D and mesh_node.get_child_count()==0: mesh_node.set_meta("batch_static",true)
	# Nested building meshes are already combined by the imported toy assets.
	TownProps.merge_fixed_geometry(buildings,[],"race_paddock")
	timer_label=Label.new()
	timer_label.add_theme_font_override("font",preload("res://assets/fonts/Nunito.ttf"))
	timer_label.add_theme_font_size_override("font_size",23)
	timer_label.add_theme_color_override("font_color",Color("fff3d4"))
	timer_label.add_theme_color_override("font_outline_color",Color("294653"))
	timer_label.add_theme_constant_override("outline_size",7)
	timer_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	timer_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(timer_label)
	timer_label.hide()
	hide()
	process_mode=Node.PROCESS_MODE_DISABLED

func _food_stand(parent: Node3D, at: Vector3) -> void:
	parent=TownProps.toy_group(parent,at,"grow","SnackShack")
	at=Vector3.ZERO
	TownProps.box(parent,at+Vector3.UP*1.3,Vector3(7,2.6,5),Color("edb472"),true)
	TownProps.box(parent,at+Vector3.UP*3.5,Vector3(8,.4,7),Color("cd7058"))
	for side in [-1,1]:
		TownProps.box(parent,at+Vector3(0,2.25,side*2.55),Vector3(5.7,1.1,.10),Color("526a6b"))
		TownProps.box(parent,at+Vector3(0,1.75,side*3),Vector3(6,.25,1.2),Color("eee0bb"))
		for x in [-3,3]: TownProps.cylinder(parent,at+Vector3(x,2.4,side*3),.10,3.4,Color("ead2a3"))
		for x in [-1.6,0,1.6]:
			TownProps.cylinder(parent,at+Vector3(x,2.1,side*3),.18,.4,Color("e0a162"))
			TownProps.ball(parent,at+Vector3(x,2.33,side*3),Vector3(.4,.12,.4),Color("9faa78"))
	for i in 8:
		TownProps.box(parent,at+Vector3(-3.5+i,3.72,0),Vector3(.5,.06,6.8),Color("efdab0"))
	TownProps.box(parent,at+Vector3(-3.6,1.6,.3),Vector3(.12,2,1.7),Color("6198a4"))

func _camper(parent: Node3D, at: Vector3, colour: Color) -> void:
	parent=TownProps.toy_group(parent,at,"drop","Camper")
	parent.set_meta("bake_variant",colour.to_html(false))
	at=Vector3.ZERO
	TownProps.box(parent,at+Vector3.UP*1.8,Vector3(7,3.0,6),colour,true)
	TownProps.box(parent,at+Vector3.UP*3.4,Vector3(7.2,.3,6.2),Color("eee3c8"))
	for side in [-1,1]:
		TownProps.box(parent,at+Vector3(0,1.05,side*3.06),Vector3(6.6,.28,.08),Color("f3dfb9"))
		for x in [-2,2]:
			TownProps.box(parent,at+Vector3(x,2.3,side*3.07),Vector3(1.6,1.05,.10),Color("e5d9bd"))
			TownProps.box(parent,at+Vector3(x,2.3,side*3.14),Vector3(1.35,.8,.04),Color("91bdc3"))
			TownProps.box(parent,at+Vector3(x,2.3,side*3.18),Vector3(.06,.8,.04),Color("eee3c8"))
		TownProps.box(parent,at+Vector3(side*3.55,2.4,-1.5),Vector3(.08,1,1.8),Color("a4c7c9"))
		for z in [-1.8,1.8]:
			var wheel:=TownProps.cylinder(parent,at+Vector3(side*3.6,.65,z),.65,.4,Color("3b5159"))
			wheel.rotation.z=PI/2
			var hub:=TownProps.cylinder(parent,at+Vector3(side*3.83,.65,z),.28,.08,Color("d9ccb0"))
			hub.rotation.z=PI/2
	TownProps.box(parent,at+Vector3(0,1.65,3.08),Vector3(1.2,2.35,.12),Color("eee3c8"))
	TownProps.box(parent,at+Vector3(0,2.15,3.17),Vector3(.8,.8,.06),Color("91bdc3"))
	TownProps.ball(parent,at+Vector3(.4,1.5,3.21),Vector3.ONE*.14,Color("97775a"))
	TownProps.box(parent,at+Vector3(0,.28,3.7),Vector3(1.8,.5,1),Color("d6bd95"))
	TownProps.box(parent,at+Vector3(0,3.0,4.7),Vector3(7,.15,3),colour.lightened(.2))
	for x in [-3,3]: TownProps.cylinder(parent,at+Vector3(x,1.5,6),.07,3,Color("e6d2a9"))
	TownProps.box(parent,at+Vector3(.7,3.85,-.5),Vector3(2.5,.65,2.2),Color("ad8f6a"))
	for x in [-1.8,1.8]: TownProps.box(parent,at+Vector3(x,3.7,0),Vector3(.09,.16,5),Color("927556"))

func _make_hydrant(at: Vector3) -> void:
	hydrant=BreakableProp.new()
	hydrant.game=game
	hydrant.kind="hydrant"
	hydrant.impact_speed=8.0
	hydrant.mass=.85
	hydrant.radius=.3
	add_child(hydrant)
	hydrant.position=at
	var shape:=CollisionShape3D.new()
	var bounds:=BoxShape3D.new()
	bounds.size=Vector3(.6,1.1,.6)
	shape.shape=bounds
	shape.position.y=.55
	hydrant.add_child(shape)
	hydrant.spawn_shape=bounds
	hydrant.spawn_offset=shape.position
	TownProps.cylinder(hydrant,Vector3.UP*.5,.25,1,Color("dd6950"))
	TownProps.ball(hydrant,Vector3.UP,Vector3(.6,.4,.6),Color("f0bd69"))
	TownProps.box(hydrant,Vector3(0,.65,0),Vector3(.9,.23,.25),Color("dd6950"))
	hydrant.finish_setup()
	props.append(hydrant)

func driving_surface(at: Vector3) -> Dictionary:
	return RaceCourse.surface_at(at-ORIGIN)

func activate() -> void:
	game.truck.drive_surface=driving_surface
	game.truck.surface_sample.clear()
	resume_bodies()
	active=true
	process_mode=Node.PROCESS_MODE_INHERIT
	show()
	previous=Vector2(SPAWN.x,SPAWN.z)
	status_clock=0

func deactivate() -> void:
	game.truck.drive_surface=Callable()
	game.truck.surface_sample.clear()
	suspend_bodies()
	active=false
	running=false
	checkpoint=0
	checkpoint_flag.hide()
	timer_label.hide()
	hide()
	process_mode=Node.PROCESS_MODE_DISABLED

static func track_distance(point: Vector2) -> float:
	return RaceCourse.distance_to_track(point)

static func crosses(from: Vector2, to: Vector2, index: int) -> bool:
	var gate:=GATES[index]
	var direction:=RaceCourse.gate_direction(index)
	var a:=(from-gate).dot(direction)
	var b:=(to-gate).dot(direction)
	if a>=0 or b<0: return false
	var crossing:=from.lerp(to,-a/maxf(.00001,b-a))
	return absf((crossing-gate).dot(Vector2(-direction.y,direction.x)))<RaceCourse.HALF_WIDTH

static func crosses_pose(from: Vector3, to: Vector3, index: int) -> bool:
	if not crosses(Vector2(from.x,from.z),Vector2(to.x,to.z),index): return false
	var direction:=RaceCourse.gate_direction(index)
	var a:=(Vector2(from.x,from.z)-GATES[index]).dot(direction)
	var b:=(Vector2(to.x,to.z)-GATES[index]).dot(direction)
	var height:=lerpf(from.y,to.y,-a/maxf(.00001,b-a))
	return absf(height-(RaceCourse.gate_position(index).y+.82))<2.5

func _physics_process(dt: float) -> void:
	if not active or game.paused or game.travel.active: return
	var p:=Vector2(game.truck.global_position.x-ORIGIN.x,game.truck.global_position.z)
	if running and track_distance(p)>9.5:
		running=false
		checkpoint=0
		checkpoint_flag.hide()
		game.toast("Lap cancelled — stay on the track.")
	if running: lap_time+=dt
	var next:=checkpoint if running else 0
	if crosses_pose(Vector3(previous.x,previous_height,previous.y),game.truck.global_position-ORIGIN,next):
		if not running:
			running=true
			lap_time=0
			checkpoint=1
		elif checkpoint==0:
			_complete_lap()
		else:
			checkpoint=(checkpoint+1)%4
		checkpoint_flag.position=RaceCourse.gate_position(checkpoint)
		checkpoint_flag.visible=running
	previous=p
	previous_height=game.truck.global_position.y
	var source: BreakableProp=hydrant if not hydrant.loose and game.truck.global_position.distance_to(hydrant.global_position)<6.75 and game.truck.water<game.truck.tank_capacity else null
	game.refill_hose.update(source,dt)
	if game.refill_hose.active: game.truck.water=minf(game.truck.tank_capacity,game.truck.water+25*dt)
	status_clock+=dt
	if status_clock>.1:
		status_clock=0
		timer_label.text="LAP  "+format_time(lap_time) if running else ""
		timer_label.add_theme_font_size_override("font_size",17 if game.hud.touch_mode else 23)
		timer_label.position=Vector2(12,83)
		timer_label.size=Vector2(game.hud.size.x-24,36)
		timer_label.visible=running and not game.dialogue_active

func _complete_lap() -> void:
	last_time=lap_time
	if best_time<=0 or lap_time<best_time:
		best_time=lap_time
		var saved:=ConfigFile.new()
		saved.set_value("race","best_seconds",best_time)
		var error:=saved.save(SAVE_PATH)
		if error!=OK: game.toast("Lap complete: "+format_time(last_time)+" · record could not be saved")
		else: game.toast("Lap complete: "+format_time(last_time))
	else: game.toast("Lap complete: "+format_time(last_time))
	_update_billboard()
	# The finish line starts the next lap immediately; racing is unlimited.
	lap_time=0
	checkpoint=1

static func format_time(seconds: float) -> String:
	var centiseconds:=int(round(seconds*100))
	return "%d:%02d.%02d" % [centiseconds/6000,(centiseconds/100)%60,centiseconds%100]

func _update_billboard() -> void:
	billboard.text="PERSONAL BEST\n"+(format_time(best_time) if best_time>0 else "SET YOUR FIRST LAP!")

func water_hit(point: Vector3, amount: float) -> bool:
	var local:=point-ORIGIN
	for job in jobs:
		if job.done or local.distance_to(job.point)>job.radius: continue
		job.progress=minf(1,job.progress+amount*.35)
		if not job.has("original_scale"): job.original_scale=job.mesh.scale
		job.mesh.scale=job.original_scale*Vector3(1,maxf(.015,1-job.progress),1)
		if job.progress>=1:
			job.done=true
			job.mesh.hide()
			if DisplayServer.get_name()!="headless": game.rewards.sound.play()
			game.rewards.sparkle_burst(point,20)
			game.toast("✓ "+job.title)
		return true
	return false

func aim_target(origin: Vector3, requested: Vector3) -> Variant:
	var aim:=Vector3(requested.x-origin.x,0,requested.z-origin.z).normalized()
	var best: Variant=null
	var score:=INF
	for job in jobs:
		if job.done: continue
		var target: Vector3=ORIGIN+job.point
		var planar:=Vector3(target.x-origin.x,0,target.z-origin.z)
		var ahead:=planar.dot(aim)
		if ahead<=0 or planar.length()>FireEngine.AIM_RANGE or planar.normalized().dot(aim)<.75: continue
		var error:=(planar-aim*ahead).length()
		if error>job.radius+1.2 or error>=score or not game.truck.shot_is_clear(origin,target): continue
		score=error
		best=target
	return best

func _build_course() -> void:
	RaceCourse.points()
	var paint:=ShaderMaterial.new()
	paint.shader=preload("res://shaders/race_road.gdshader")
	paint.set_shader_parameter("start_distance",RaceCourse.distances[RaceCourse.GATE_INDICES[0]*RaceCourse.STEPS])
	var road:=RaceCourse.ribbon(-RaceCourse.HALF_WIDTH,RaceCourse.HALF_WIDTH,0,paint)
	road.name="RibbonRoadAndBridge"
	road.set_meta("assembly_group",2)
	add_child(road)
	var body:=StaticBody3D.new()
	body.collision_layer=8
	road.add_child(body)
	var collision:=CollisionShape3D.new()
	collision.shape=road.mesh.create_trimesh_shape()
	body.add_child(collision)
	var curb:=paint.duplicate() as ShaderMaterial
	curb.set_shader_parameter("curb",true)
	for side in [-1,1]:
		var edge:=RaceCourse.ribbon(-7.1 if side<0 else 6.5,-6.5 if side<0 else 7.1,.025,curb)
		edge.name="StripedRaisedCurb"
		edge.set_meta("assembly_group",2)
		add_child(edge)
		var edge_body:=StaticBody3D.new()
		edge_body.collision_layer=8
		edge.add_child(edge_body)
		var edge_shape:=CollisionShape3D.new()
		edge_shape.shape=edge.mesh.create_trimesh_shape()
		edge_body.add_child(edge_shape)
	# One continuous deck and rail ribbon follows the same curve as the road.
	# The arch posts stand on its widened shoulders, not on empty air.
	_build_bridge()
	# The road, deck, supports and rails rise together from the printed bridge.
	for piece in get_children():
		if piece.has_meta("assembly_group"): piece.set_meta("toy_pivot",Vector3(0,0,4))
	TownProps.box(self,Vector3(0,.025,-69),Vector3(10,.05,30),Color("738888"))
	for z in range(-80,-56,4): TownProps.box(self,Vector3(0,.07,z),Vector3(.13,.02,1.5),Color("f1dcaa"))
	TownProps.box(self,Vector3(-28,.035,-67),Vector3(43,.06,8),Color("899793"))
	TownProps.box(self,Vector3(57,.035,22),Vector3(10,.06,45),Color("899793"))

func _build_boundary() -> void:
	var blocks:=Node3D.new()
	blocks.name="BoundaryBlocks"
	add_child(blocks)
	var rng:=RandomNumberGenerator.new()
	rng.seed=7314
	var finishes: Array[ShaderMaterial]=[]
	for tone in ["dcbd8c","c79b67","d8b07c","c96959","598eab","699b86"]:
		finishes.append(Playroom.wood_finish(Color(tone),false,finishes.size()>2))
	for side in [-1,1]:
		for axis in 2:
			var at:=-82.0
			while at<82:
				if axis==1 and side==-1 and at>=-8 and at<8: at=8
				var end:=-8.0 if axis==1 and side==-1 and at< -8 else 82.0
				var length:=minf(rng.randf_range(5,11),end-at)
				var height:=rng.randf_range(2.6,4.2)
				var p:=Vector3(side*81,height*.5,at+length*.5) if axis==0 else Vector3(at+length*.5,height*.5,side*81)
				var dimensions:=Vector3(3,height,length-.1) if axis==0 else Vector3(length-.1,height,3)
				var block:=TownProps.box(blocks,p,dimensions,Color.WHITE)
				block.material_override=finishes[rng.randi_range(0,finishes.size()-1)]
				block.rotation.y=rng.randf_range(-.025,.025)
				block.set_meta("batch_static",true)
				at+=length
			if axis==0: _boundary_collider(Vector3(side*81,3,0),Vector3(3,6,164))
			elif side==1: _boundary_collider(Vector3(0,3,81),Vector3(164,6,3))
			else:
				for x in [-44,44]: _boundary_collider(Vector3(x,3,-81),Vector3(72,6,3))
	TownProps.batch_decorations(blocks)

func _boundary_collider(at: Vector3, dimensions: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.collision_layer=Playroom.WALL_LAYER
	add_child(body)
	body.position=at
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=dimensions
	collision.shape=box
	body.add_child(collision)

func _make_gate(parent: Node3D, index: int) -> void:
	var gate:=Node3D.new()
	gate.set_meta("toy_arrival","drop")
	gate.name="StartFinishArch" if index==0 else "CheckpointArch%d" % index
	parent.add_child(gate)
	gate.position=RaceCourse.gate_position(index)+Vector3.UP*(.055 if index==3 else 0)
	var forward:=RaceCourse.gate_direction(index)
	gate.rotation.y=atan2(-forward.x,-forward.y)
	var color: Color=[Color("cd7058"),Color("6c9eaf"),Color("dcab54"),Color("79a994")][index]
	for x in [-7.6,7.6]:
		TownProps.box(gate,Vector3(x,3.1,0),Vector3(.55,6.2,.65),Color("e2c398"),true)
		TownProps.box(gate,Vector3(x,.25,0),Vector3(1.1,.5,1.1),color)
	TownProps.box(gate,Vector3(0,6.2,0),Vector3(15.8,1,.7),color)
	for i in 16:
		TownProps.box(gate,Vector3(-7.5+i,6.25,.38),Vector3(.55,.55,.06),Color("f4e5be") if i%2==0 else Color("405b67"))
	# Numbers are printed on the crossbar, with no camera-facing scene labels.
	if index>0:
		var number:=TownProps.label(gate,Vector3(0,6.25,.39),str(index),44)
		number.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		number.pixel_size=.014
	gates.append(gate)

func _build_paddock(parent: Node3D) -> void:
	# Three distinct little neighbourhoods, built from the same toys as Maple Bay.
	TownProps.house(parent,Vector3(-27,0,-71),Color("bd6252"),"PIT STATION",5)
	_food_stand(parent,Vector3(65,0,24))
	var grill:=TownProps.toy_group(parent,Vector3(62,0,16),"drop","RaceGrill")
	TownProps.cylinder(grill,Vector3(0,.7,0),.6,1.2,Color("465763"))
	TownProps.cylinder(grill,Vector3(0,1.4,0),1,.35,Color("a65043"))
	# A small infield garden gives the campsite a place to gather between laps.
	TownProps.ball(parent,Vector3(-31,.06,36),Vector3(17,.13,12),Color("d8c7a0"))
	TownProps.ball(parent,Vector3(-31,.14,36),Vector3(15.5,.10,10.3),Color("74adb5"))
	for j in 16:
		var a:=j*TAU/16
		TownProps.ball(parent,Vector3(-31+cos(a)*8,.20,36+sin(a)*5.5),Vector3(.65,.45,.55),Color("b3ad92"))
	for i in 3:
		var duck:=TownProps.toy_group(self,Vector3(-31+i,.28,36),"drop","SwimmingDuck")
		TownProps.ball(duck,Vector3.ZERO,Vector3(.85,.55,.6),Color("edc876"))
		TownProps.ball(duck,Vector3(0,.33,-.26),Vector3(.44,.48,.44),Color("edc876"))
		TownProps.box(duck,Vector3(0,.29,-.55),Vector3(.27,.10,.25),Color("d9894f"))
		for side in [-1,1]: TownProps.ball(duck,Vector3(side*.2,.38,-.37),Vector3.ONE*.065,Color("454744"))
		TownProps.merge_fixed_geometry(duck,[],"race_swimming_duck")
		ducks.append(duck)

	_camper(parent,Vector3(43,0,54),Color("d2a774"))
	_camper(parent,Vector3(60,0,51),Color("7facab"))
	_camper(parent,Vector3(60,0,65),Color("cb8a87"))
	_prize_podium(parent,Vector3(-43,0,-4))
	TownProps.box(parent,Vector3(58,.031,49),Vector3(27,.002,36),Color("c4cd9b"))
	for at in [Vector3(61,0,39),Vector3(71,0,41),Vector3(35,0,67),Vector3(-55,0,5)]:
		_picnic_table(parent,at)
	for at in [Vector3(-43,0,41),Vector3(-23,0,48),Vector3(-15,0,31)]:
		_tent(parent,at,Color("d5a969") if at.x< -30 else Color("81aca6"))
	# Low awnings, flower pots, parked toy cars and equipment make the pit lane legible.
	for x in [-35,-20]:
		var car:=TownProps.toy_group(parent,Vector3(x,0,-63),"drop","ParkedRacer")
		car.set_meta("bake_variant","gold" if x< -30 else "blue")
		TownProps.box(car,Vector3(0,.9,0),Vector3(4,1.3,2.2),Color("d49a5c") if x< -30 else Color("79a6b8"))
		TownProps.box(car,Vector3(0,1.7,0),Vector3(2,1.0,2),Color("c5d9d8"))
		for dx in [-1.25,1.25]:
			for z in [-64,-62]:
				var wheel:=TownProps.cylinder(car,Vector3(dx,.55,z+63),.45,.35,Color("3d5058"))
				wheel.rotation.x=PI/2
	for p in [Vector3(-44,0,-61),Vector3(-14,0,-63),Vector3(67,0,18),Vector3(68,0,26),Vector3(37,0,48)]:
		var tires:=TownProps.toy_group(parent,p,"drop","TireStack")
		for n in 3: TownProps.cylinder(tires,Vector3.UP*(.25+n*.45),.8,.4,Color("42515b"))
	for p in [Vector3(48,0,11),Vector3(65,0,11),Vector3(-13,0,-61),Vector3(-41,0,-62)]:
		var cone:=TownProps.toy_group(parent,p,"drop","TrafficCone")
		TownProps.cylinder(cone,Vector3.UP*.5,.5,1,Color("ed9560"),.1)
		TownProps.box(cone,Vector3.UP*.05,Vector3(1.1,.1,1.1),Color("ed9560"))
	for p in [Vector3(-47,0,-10),Vector3(-38,0,-10),Vector3(60,0,28),Vector3(71,0,28),Vector3(37,0,50),Vector3(47,0,50)]:
		var planter:=TownProps.toy_group(parent,p,"drop","FlowerPot")
		TownProps.cylinder(planter,Vector3.UP*.4,.65,.8,Color("c98b65"),.8)
		for j in 5: TownProps.ball(planter,Vector3(sin(j*2.4)*.6,1.1,cos(j*2.4)*.6),Vector3(.45,.7,.45),Color("ecbc73") if j%2 else Color("bc809b"))
	# Woodland follows empty grass; it never obstructs the driving ribbon.
	var rng:=RandomNumberGenerator.new()
	rng.seed=731
	var tree_count:=0
	for i in 150:
		var p:=Vector3(rng.randf_range(-73,73),0,rng.randf_range(-73,73))
		if RaceCourse.distance_to_track(Vector2(p.x,p.z))<12 or absf(p.x)<8 and p.z< -52: continue
		if p.distance_to(Vector3(53,0,46))<29 or p.distance_to(Vector3(-26,0,-67))<23 or p.distance_to(Vector3(-43,0,-4))<16: continue
		if p.x< -58 and p.z>27 and p.z<55 or p.x>58 and p.z> -37 and p.z< -8: continue
		if Vector2((p.x+31)/10.5,(p.z-36)/7.5).length()<1: continue
		var clear_site:=true
		for toy in parent.get_children():
			if not toy is Node3D or not toy.has_meta("toy_arrival"): continue
			if toy.get_meta("toy_kind","")=="GardenTree": continue
			if p.distance_to(toy.position)<6.5: clear_site=false; break
		if not clear_site: continue
		TownProps.tree(parent,p,rng.randf_range(.9,1.5))
		tree_count+=1
		if tree_count>=38: break
	for side in [-1,1]:
		var stands:=Node3D.new()
		parent.add_child(stands)
		stands.position=Vector3(-71,0,42) if side<0 else Vector3(73,0,-22)
		stands.rotation.y=side*PI/2
		for row in 3:
			TownProps.box(stands,Vector3(0,.45+row*.7,row*1.4),Vector3(12,.5,1.8),Color("cfa77b"),true)
			TownProps.box(stands,Vector3(0,1.3+row*.7,row*1.4+.6),Vector3(12,.6,.16),Color("b37f59"))
			for seat in 3:
				var person:=_person(self,stands.position+stands.basis*Vector3(-4+seat*4,.7+row*.7,row*1.4),Color("dcaa60") if (row+seat)%2 else Color("8daeb5"))
				person.rotation.y=stands.rotation.y
				spectators.append(person)
	_bunting(parent,Vector3(56,0,33),Vector3(74,0,33))
	_bunting(parent,Vector3(-48,0,-61),Vector3(-12,0,-61))
	people.append(_person(self,Vector3(-17,0,-71),Color("ecb354")))
	people.append(_person(self,Vector3(65,0,29),Color("6d9cb2")))
	people.append(_person(self,Vector3(38,0,55),Color("b88ca1")))
	for i in people.size(): people[i].name=NAMES[i]
	for i in 4:
		var start:=Vector3(50+i*2,0,41+i*2)
		var actor:=_person(self,start,Color("81a99c") if i%2 else Color("ca8c80"))
		walkers.append({"actor":actor,"start":start,"phase":i*1.7})

func _picnic_table(parent: Node3D, at: Vector3) -> void:
	parent=TownProps.toy_group(parent,at,"drop","PicnicTable")
	at=Vector3.ZERO
	TownProps.box(parent,at+Vector3.UP*1.3,Vector3(4,.25,2),Color("d9b682"),true)
	for side in [-1,1]:
		TownProps.box(parent,at+Vector3(0,.7,side*1.6),Vector3(4,.2,.7),Color("bb8c62"))
		for x in [-1.3,1.3]: TownProps.box(parent,at+Vector3(x,.5,side*.6),Vector3(.2,1,.2),Color("bb8c62"))
	for x in [-.7,.7]: TownProps.cylinder(parent,at+Vector3(x,1.6,0),.14,.35,Color("f0cf8c"))

func _tent(parent: Node3D, at: Vector3, color: Color) -> void:
	parent=TownProps.toy_group(parent,at,"drop","Tent")
	parent.set_meta("bake_variant",color.to_html(false))
	at=Vector3.ZERO
	TownProps.box(parent,Vector3.UP*.09,Vector3(6,.18,5),Color("ddbc86"))
	var canvas:=SurfaceTool.new()
	canvas.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a:=Vector3(-3,.15,-2.5)
	var b:=Vector3(3,.15,-2.5)
	var c:=Vector3(0,3.2,-2.5)
	var d:=Vector3(-3,.15,2.5)
	var e:=Vector3(3,.15,2.5)
	var f:=Vector3(0,3.2,2.5)
	for point in [a,b,c,d,f,e,a,c,d,c,f,d,b,e,c,c,e,f]: canvas.add_vertex(point)
	canvas.generate_normals()
	var shell:=MeshInstance3D.new()
	shell.mesh=canvas.commit()
	shell.material_override=TownProps.material(color)
	parent.add_child(shell)
	# A dark, triangular doorway and parted canvas make these readable tents.
	var door:=SurfaceTool.new()
	door.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-1.1,.18,2.53),Vector3(0,2.5,2.53),Vector3(1.1,.18,2.53)]: door.add_vertex(point)
	door.generate_normals()
	var opening:=MeshInstance3D.new()
	opening.mesh=door.commit()
	opening.material_override=TownProps.material(Color("43575d"))
	parent.add_child(opening)
	for side in [-1,1]:
		var flap:=TownProps.box(parent,Vector3(side*1.0,1.22,2.63),Vector3(.32,2.5,.14),color.lightened(.18))
		flap.rotation.z=side*.42
		for z in [-2.4,2.4]:
			var start:=Vector3(side*2.6,.65,z)
			var end:=Vector3(side*3.7,.08,z)
			var cord:=TownProps.cylinder(parent,(start+end)*.5,.025,start.distance_to(end),Color("eee0b8"))
			cord.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
			TownProps.cylinder(parent,end,.07,.3,Color("916e4c"))

func _prize_podium(parent: Node3D, at: Vector3) -> void:
	var podium:=TownProps.toy_group(parent,at,"drop","PrizePodium")
	for i in 3:
		var height: float=[1.2,1.9,.8][i]
		var x:=float(i-1)*2.4
		TownProps.box(podium,Vector3(x,height*.5,0),Vector3(2.35,height,3),Color("6f9aab") if i!=1 else Color("d0a259"),true)
		var number:=TownProps.label(podium,Vector3(x,height*.5,1.54),str([2,1,3][i]),32)
		number.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		number.pixel_size=.017
	TownProps.box(podium,Vector3(0,2.05,-.3),Vector3(.8,.3,.8),Color("745c44"))
	TownProps.cylinder(podium,Vector3(0,2.45,-.3),.16,.6,Color("dfb65f"))
	TownProps.cylinder(podium,Vector3(0,3,-.3),.3,.6,Color("dfb65f"),.65)
	for sign in [-1,1]:
		var handle:=TownProps.ball(podium,Vector3(sign*.58,3,-.3),Vector3(.35,.6,.18),Color("dfb65f"))
		handle.rotation.z=sign*.3
	# A toy broadcast camera on its tripod watches the prizes and the track.
	var camera:=TownProps.toy_group(parent,at+Vector3(7,0,1),"drop","BroadcastCamera")
	for i in 3:
		var end:=Vector3(sin(i*TAU/3)*.85,.05,cos(i*TAU/3)*.85)
		var start:=Vector3(0,1.9,0)
		var leg:=TownProps.cylinder(camera,(start+end)*.5,.055,start.distance_to(end),Color("536872"))
		leg.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
	TownProps.box(camera,Vector3(0,2.2,0),Vector3(1.2,.65,.7),Color("5b727b"))
	var lens:=TownProps.cylinder(camera,Vector3(.8,2.2,0),.23,.5,Color("364c58"))
	lens.rotation.z=PI/2
	var reporter:=_person(self,at+Vector3(8,0,2.8),Color("6d9cb2"))
	reporter.rotation.y=-PI/2
	spectators.append(reporter)

func _bunting(parent: Node3D, a: Vector3, b: Vector3) -> void:
	parent=TownProps.toy_group(parent,(a+b)*.5,"drop","Bunting")
	a-=parent.position
	b-=parent.position
	for p in [a,b]: TownProps.cylinder(parent,p+Vector3.UP*4,.1,8,Color("d3b184"))
	var line:=TownProps.box(parent,(a+b)*.5+Vector3.UP*7.7,Vector3(a.distance_to(b),.06,.06),Color("ead6af"))
	line.rotation.y=-atan2(b.z-a.z,b.x-a.x)
	for i in 13:
		var p:=a.lerp(b,float(i)/12)+Vector3.UP*(7.3-sin(float(i)/12*PI)*.8)
		var flag:=TownProps.box(parent,p,Vector3(.65,.8,.08),Color("c97560") if i%3==0 else Color("72a9b0") if i%3==1 else Color("e5ba6d"))
		flag.rotation.z=.15*sin(i*2.1)

func _process(dt: float) -> void:
	if not active or game.paused or game.travel.active: return
	animation_clock+=dt
	for i in ducks.size():
		var t:=animation_clock*.18+i*TAU/3
		ducks[i].position=Vector3(-31+cos(t)*5,.29+sin(t*7)*.025,36+sin(t)*3)
		ducks[i].rotation.y=atan2(sin(t)*5,-cos(t)*3)
		ducks[i].rotation.z=sin(t*9)*.035
	for i in people.size()+spectators.size():
		var actor: Node3D=people[i] if i<people.size() else spectators[i-people.size()]
		if not TownProps.near_view(game.camera,actor.global_position,3): continue
		actor.get_node("ArmRight").rotation.z=-.4+sin(animation_clock*3+i)*.35
		actor.get_node("Eyes").scale.y=.08 if fmod(animation_clock+i*.73,4.3)<.1 else 1.0
		if i<people.size():
			var toward: Vector3=game.truck.global_position-actor.global_position
			if toward.length()<12: actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-toward.x,-toward.z),1-exp(-3*dt))
	for walker in walkers:
		var t:=animation_clock*.25+float(walker.phase)
		walker.actor.position=walker.start+Vector3(sin(t)*3,absf(sin(t*9))*.045,cos(t)*2)
		walker.actor.rotation.y=atan2(-cos(t)*3,sin(t)*2)

func proximity_talk() -> void:
	if running or game.dialogue_active: return
	for i in people.size():
		var d: float=game.truck.global_position.distance_to(people[i].global_position)
		if d>11: chatter_latches.erase(i)
		if d<7.5 and not chatter_latches.has(i) and game.truck.linear_velocity.length()<5:
			talk_to_person(i)
			break

func talk_to_person(index: int) -> bool:
	if index<0 or index>=people.size() or game.paused: return false
	var words: String
	match index:
		0:
			words="Welcome to Maple Motor Park! Cross the chequered START arch heading right, then follow the numbered gates. Snake Bend, Camp Corner, and up over Sky Bridge! Each finish starts another lap. Your best time stays on that blue board. Need a top-up? The red hydrant is beside the entrance."
		1:
			words="Snack Shack's open again! That was a very enthusiastic grill. Thank you for cooling it down. A victory sandwich is on me!" if jobs[1].done else "Race-day sandwiches! Except my grill has got a little carried away. Could you hose down that flare-up? There's a slippery spill in the pit lane too. We ought to tidy it before the next racer comes through."
		2:
			words="Look at that shine! Now our little camper's ready for the next adventure. We camp here for every race weekend. Come back any time." if jobs[2].done else "Hello! We drove down a very dusty lane to get here. Could you give our golden camper a wash? Afterwards, try the bridge! I like watching the trucks go underneath and over the top."
	game.talk(NAMES[index]+"  /  "+["PIT CREW","SNACK SHACK","RACER'S CAMP"][index],words,game.stage)
	chatter_latches[index]=true
	return true

func _person(parent: Node3D, at: Vector3, shirt: Color) -> Node3D:
	var person:=TownProps.person(parent,at,shirt)
	# Keep only the waving hand and eyes separate; the rest shares one body batch.
	TownProps.merge_fixed_geometry(person,[person.get_node("ArmRight"),person.get_node("Eyes")],"race_person_"+shirt.to_html(false))
	return person

func _make_breakable_scenery(parent: Node3D) -> void:
	for toy in parent.get_children():
		if not toy is Node3D or not toy.has_meta("toy_arrival"): continue
		var kind: String=toy.get_meta("toy_kind",str(toy.name))
		var size:=Vector3.ZERO
		var center:=Vector3.ZERO
		var threshold:=4.0
		var weight:=.6
		match kind:
			"GardenTree":
				var tree_size: float=toy.get_child(0).scale.x
				size=Vector3(.5,4.5,.5)*tree_size
				center=Vector3.UP*2.25*tree_size
				threshold=15
				weight=1.5
			"Camper": size=Vector3(7,3.4,6); center=Vector3.UP*1.9; threshold=9; weight=1.8
			"PicnicTable": size=Vector3(4,1.6,3.9); center=Vector3.UP*.8
			"Tent": size=Vector3(6,2.7,5); center=Vector3.UP*1.35; threshold=3; weight=.35
			"ParkedRacer": size=Vector3(4,2.2,2.8); center=Vector3.UP*1.1; threshold=3; weight=.8
			"RaceGrill": size=Vector3(2,1.6,2); center=Vector3.UP*.8; threshold=3
			"FlowerPot": size=Vector3(1.3,1.5,1.3); center=Vector3.UP*.75; threshold=2; weight=.3
			"TrafficCone": size=Vector3(1,1,1); center=Vector3.UP*.5; threshold=1.5; weight=.16
			"TireStack": size=Vector3(1.6,1.4,1.6); center=Vector3.UP*.7; threshold=2; weight=.4
			_: continue # Houses and tall flag strings stay anchored.
		if kind!="GardenTree": TownProps.merge_fixed_geometry(toy,[],"race_toy_"+kind.to_snake_case()+str(toy.get_meta("bake_variant","")))
		var prop:=BreakableProp.from_parts(self,game,kind.to_snake_case(),toy.global_position,[toy],size,center,threshold,weight,maxf(size.x,size.z)*.5)
		props.append(prop)
		if kind=="GardenTree":
			prop.kind="tree"
			var crown:=CollisionShape3D.new()
			var sphere:=SphereShape3D.new()
			sphere.radius=size.y*.3
			crown.shape=sphere
			crown.position.y=size.y*.9
			prop.add_child(crown)

func suspend_bodies() -> void:
	if not suspended_bodies.is_empty(): return
	for body in props:
		suspended_bodies.append({"body":body,"freeze":body.freeze,"velocity":body.linear_velocity,"angular":body.angular_velocity})
		body.freeze=true

func resume_bodies() -> void:
	for saved in suspended_bodies:
		saved.body.freeze=saved.freeze
		saved.body.linear_velocity=saved.velocity
		saved.body.angular_velocity=saved.angular
	suspended_bodies.clear()

func _build_bridge() -> void:
	var path:=RaceCourse.points()
	var deck_tool:=SurfaceTool.new()
	deck_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rails: Array[SurfaceTool]=[SurfaceTool.new(),SurfaceTool.new()]
	for rail in rails: rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last_post:=-10.0
	for i in range(16*RaceCourse.STEPS,22*RaceCourse.STEPS):
		var p:=path[i]
		var q:=path[i+1]
		var side_p:=_road_side(path,i)
		var side_q:=_road_side(path,i+1)
		# Flat approach boards taper into the mat; the road collider alone bears
		# the truck, so deck seams and rail posts cannot jolt its suspension.
		for lift in [-.18,-.65]:
			_bridge_quad(deck_tool,p-side_p*8.3+Vector3.UP*lift,q-side_q*8.3+Vector3.UP*lift,q+side_q*8.3+Vector3.UP*lift,p+side_p*8.3+Vector3.UP*lift)
		for sign in [-1,1]:
			# The raised timber shoulder supports each arch foot. Its surface
			# stops beside the asphalt, avoiding coplanar overlapping faces.
			_bridge_quad(deck_tool,p+side_p*sign*6.5+Vector3.UP*.055,q+side_q*sign*6.5+Vector3.UP*.055,q+side_q*sign*8.3+Vector3.UP*.055,p+side_p*sign*8.3+Vector3.UP*.055)
		for sign in [-1,1]:
			var a: Vector3=p+side_p*sign*8.3
			var b: Vector3=q+side_q*sign*8.3
			_bridge_quad(deck_tool,a+Vector3.DOWN*.65,b+Vector3.DOWN*.65,b+Vector3.UP*.055,a+Vector3.UP*.055)
			var tool: SurfaceTool=rails[0 if sign<0 else 1]
			for lift in [.62,.82]:
				_bridge_quad(tool,p+side_p*sign*8.15-side_p*.12+Vector3.UP*lift,q+side_q*sign*8.15-side_q*.12+Vector3.UP*lift,q+side_q*sign*8.15+side_q*.12+Vector3.UP*lift,p+side_p*sign*8.15+side_p*.12+Vector3.UP*lift)
			for offset in [-.12,.12]:
				var a_rail: Vector3=p+side_p*(sign*8.15+offset)
				var b_rail: Vector3=q+side_q*(sign*8.15+offset)
				_bridge_quad(tool,a_rail+Vector3.UP*.62,b_rail+Vector3.UP*.62,b_rail+Vector3.UP*.82,a_rail+Vector3.UP*.82)
		if p.y>.25 and RaceCourse.distances[i]-last_post>4:
			last_post=RaceCourse.distances[i]
			for sign in [-1,1]: TownProps.cylinder(self,p+side_p*sign*8.15+Vector3.UP*.31,.09,.85,Color("bc8b58")).set_meta("assembly_group",2)
	var timber:=TownProps.material(Color("cead7d"))
	timber=timber.duplicate()
	timber.cull_mode=BaseMaterial3D.CULL_DISABLED
	for tool in [deck_tool,rails[0],rails[1]]:
		tool.generate_normals()
		tool.index()
		var art:=MeshInstance3D.new()
		art.name="ContinuousBridgeDeck" if tool==deck_tool else "ContinuousBridgeRail"
		art.mesh=tool.commit()
		art.material_override=timber
		art.set_meta("assembly_group",2)
		add_child(art)
	# Piers leave the full lower road clear and meet the underside exactly.
	var centre:=path[20*RaceCourse.STEPS]
	var side:=_road_side(path,20*RaceCourse.STEPS)
	for sign in [-1,1]:
		var base: Vector3=centre+side*sign*7.7
		var height:=centre.y-.65
		var pier:=TownProps.box(self,Vector3(base.x,height*.5,base.z),Vector3(1.0,height,1.0),Color("c89d6f"),true)
		pier.name="NorthBridgePier"+str(sign)
		pier.set_meta("assembly_group",2)

func _road_side(path: PackedVector3Array, index: int) -> Vector3:
	var tangent:=path[index+1]-path[index-1]
	return Vector3(-tangent.z,0,tangent.x).normalized()

func _bridge_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a,b,c,a,c,d]: tool.add_vertex(p)
