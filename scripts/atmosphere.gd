class_name TownAtmosphere
extends Node3D

var steam: Array[Dictionary]=[]
var steam_pool: Array[MeshInstance3D]=[]
var smoke: Array[MeshInstance3D]=[]
var embers: Array[MeshInstance3D]=[]
var time:=0.0
var game: Node3D
var fire_light: OmniLight3D
var fire: ToyFire
var fountain_drops: Array[MeshInstance3D]=[]
var fountain: Node3D

const ROAD_REACH:=79.6
var road_material: Material

# Centre-line dashes stop before the zebra crossings at each junction.
func _dash_in_crossing(node: MeshInstance3D) -> bool:
	if node.scale.y>.03 or maxf(node.scale.x,node.scale.z)>1.6 or minf(node.scale.x,node.scale.z)>.2: return false
	for line in [-36.0,0.0,36.0]:
		var along:=node.position.z if is_equal_approx(node.position.x,line) else node.position.x if is_equal_approx(node.position.z,line) else INF
		for junction in [-36.0,0.0,36.0]:
			if absf(along-junction)<TownSidewalks.ROAD_HALF+TownSidewalks.RADIUS+TownSidewalks.WIDTH+1.0: return true
	return false

func _ready() -> void:
	seed(421)
	var town: LittleTown=game.town
	# Quiet material variation gives surfaces scale without distracting texture.
	for child in town.get_children():
		if child is MeshInstance3D:
			var material: ShaderMaterial
			if child.scale.x>150 and child.scale.z>150:
				material=ShaderMaterial.new()
				material.shader=preload("res://shaders/ground.gdshader")
				material.set_shader_parameter("base_color",Color("609958"))
				material.set_shader_parameter("variation",0.13)
				material.set_shader_parameter("meadow",true)
				child.material_override=material
			elif (child.scale.y<.2 and child.scale.y>.1 and maxf(child.scale.x,child.scale.z)>120) or (is_equal_approx(child.scale.x,.7) and is_equal_approx(child.scale.z,2.0) and child.position.y<.12) or _dash_in_crossing(child):
				# Square-ended pavement strips and offset crossings are rebuilt by
				# TownSidewalks with rounded corners and aligned zebras.
				town.remove_child(child)
				child.queue_free()
			elif child.scale.y<.2 and child.scale.x*child.scale.z>20 and child.material_override is StandardMaterial3D and child.material_override.albedo_color.g>child.material_override.albedo_color.r and child.material_override.albedo_color.g>child.material_override.albedo_color.b*1.12:
				# Garden slabs introduced sharp raised seams in the continuous felt.
				town.remove_child(child)
				child.queue_free()
			elif child.scale.y<0.06 and child.scale.x+child.scale.z>100:
				# Run every street right up to the toy-block wall at the mat's edge.
				if child.scale.z>100: child.scale.z=ROAD_REACH*2
				else: child.scale.x=ROAD_REACH*2
				material=ShaderMaterial.new()
				material.shader=preload("res://shaders/ground.gdshader")
				material.set_shader_parameter("base_color",Color("50636d"))
				material.set_shader_parameter("grain_scale",18.0)
				material.set_shader_parameter("variation",0.045)
				# Rounded toy cubes pull the asphalt back from its nominal edge,
				# leaving green seams beside the exact sidewalk corner fills.
				var slab:=BoxMesh.new()
				slab.size=Vector3.ONE
				child.mesh=slab
				child.scale.y=.055
				child.position.y=.0275
				child.material_override=material
				road_material=material
	var pavements:=TownSidewalks.new()
	pavements.road_material=road_material
	add_child(pavements)
	pavements.build()
	var water:=ShaderMaterial.new()
	water.shader=preload("res://shaders/pool.gdshader")
	town.pool_water.material_override=water
	# Straight footpaths from every front door to the sidewalk, or crisp
	# 90-degree turns with a tight rounded corner where the sidewalk runs along the side.
	var walks: Dictionary={
		Vector3(18,0,19):[Vector3(18,0,23.0),Vector3(18,0,30.0)],
		Vector3(-19,0,-20):[Vector3(-19,0,-16.1),Vector3(-19,0,-6.0)],
		Vector3(19,0,-20):[Vector3(19,0,-16.1),Vector3(19,0,-6.0)],
		Vector3(-48,0,18):[Vector3(-48,0,21.9),Vector3(-48,0,30.0)],
		Vector3(49,0,18):[Vector3(49,0,21.9),Vector3(49,0,30.0)],
		Vector3(49,0,-25):[Vector3(49,0,-21.1),Vector3(49,0,-6.0)],
		Vector3(-49,0,-22):[Vector3(-49,0,-18.1),Vector3(-49,0,-6.0)],
		Vector3(18,0,49):[Vector3(18,0,52.9),Vector3(18,0,58.0),Vector3(6.0,0,58.0)],
		Vector3(-19,0,49):[Vector3(-19,0,52.9),Vector3(-19,0,58.0),Vector3(-6.0,0,58.0)],
	}
	for garden in walks:
		_garden_walk(walks[garden])
		for side in [-1,1]:
			for n in range(5):
				var p: Vector3=garden+Vector3(side*(2.7+n*.65),0,5.8)
				TownProps.ball(self,p+Vector3.UP*.44,Vector3(.9,.92,.8),Color("769266") if n%2 else Color("829d6b"))
			for n in range(5):
				var p: Vector3=garden+Vector3(side*3+randf_range(-1,1),0,4+randf_range(0,1))
				_flower(p,Color("e65d9a") if n%2 else Color("a479df"))
	# Pocket park: a little fountain makes the neighbourhood feel inhabited.
	var center:=Vector3(-23.8,0,-10)
	fountain=TownProps.toy_group(self,center,"grow","ParkFountain")
	TownProps.cylinder(fountain,Vector3.UP*.06,3.0,.12,Color("c8bca1"))
	TownProps.cylinder(fountain,Vector3.UP*.36,2.1,.6,Color("bcaf92"))
	var basin:=TownProps.cylinder(fountain,Vector3.UP*.68,1.88,.08,Color("62a5a6"))
	basin.material_override=water
	TownProps.cylinder(fountain,Vector3.UP*.9,.32,1.5,Color("dacbad"))
	TownProps.cylinder(fountain,Vector3.UP*1.64,.84,.22,Color("d3c4a4"))
	# Match the solid stone tiers rather than blocking an invisible square.
	var fountain_body:=StaticBody3D.new()
	fountain_body.name="FountainStone"
	fountain.add_child(fountain_body)
	for tier in [Vector3(3.0,.12,.06),Vector3(2.1,.6,.36),Vector3(.32,1.5,.9),Vector3(.84,.22,1.64)]:
		var collision:=CollisionShape3D.new()
		var stone:=CylinderShape3D.new()
		stone.radius=tier.x
		stone.height=tier.y
		collision.shape=stone
		collision.position.y=tier.z
		fountain_body.add_child(collision)
	for i in range(36):
		var d:=TownProps.ball(fountain,Vector3.UP*1.72,Vector3.ONE*.09,Color("bce0d2"))
		d.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fountain_drops.append(d)
	var moving: Array[Node3D]=[]
	moving.append_array(fountain_drops)
	TownProps.merge_fixed_geometry(fountain,moving,"park_fountain")
	# A station forecourt apron and centered straight path out to the south sidewalk.
	for n in [-1,0,1]:
		TownProps.box(self,Vector3(-15.0+n*1.75,.075,17.7),Vector3(1.65,.1,2.3),Color("bcb6a0")).set_meta("batch_static",true)
	_garden_walk([Vector3(-15.0,0,18.85),Vector3(-15.0,0,30.0)])
	for p in [Vector3(8,0,10),Vector3(-8,0,-15),Vector3(29,0,23),Vector3(9,0,-26)]:
		TownProps.cylinder(self,p+Vector3.UP*.42,.46,.84,Color("b48868"))
		TownProps.ball(self,p+Vector3.UP*.99,Vector3(1.1,1.1,1.1),Color("779569"))
		for i in range(4): _flower(p+Vector3(randf_range(-.4,.4),.9,randf_range(-.4,.4)),Color("d59886"))
	# Centre-line dashes continue over the new road ends.
	for line in [-36,0,36]:
		for n in range(15,20):
			for side in [-1,1]:
				var p: float=side*n*4.0
				if absf(p)+.75>ROAD_REACH-.5: continue
				if absf(p-NorthlineRailway.TRACK_Z)>2.8:
					TownProps.box(self,Vector3(line,0.075,p),Vector3(0.13,0.02,1.5),Color("f4d898")).set_meta("batch_static",true)
				TownProps.box(self,Vector3(p,0.08,line),Vector3(1.5,0.02,0.13),Color("f4d898")).set_meta("batch_static",true)
	fire=ToyFire.new()
	fire.name="BarbecueFire"
	fire.game=game
	fire.position=TownLayout.FIRE
	fire.flames=town.flames
	add_child(fire)
	town.fire=fire
	game.maple_fire=fire
	# Existing warmup and intro code refers to these pools; all behaviour now
	# lives in ToyFire, shared with the Motorway and future emergencies.
	steam=fire.steam
	steam_pool=fire.steam_pool
	smoke=fire.smoke
	embers=fire.embers
	fire_light=fire.fire_light

func _garden_walk(waypoints: Array, corner_radius: float = 2.2) -> void:
	# Build straight segments with crisp 90-degree rounded corners (fillet arcs)
	# rather than meandering splines, so stones stay square to doors and sidewalks.
	var samples := PackedVector3Array()
	var tangents := PackedVector3Array()
	var turn_signs := PackedFloat32Array() # 0 on straight, +1/-1 on corner arc
	if waypoints.size() == 2:
		var p0: Vector3 = waypoints[0]
		var p1: Vector3 = waypoints[1]
		var dir := (p1 - p0).normalized()
		samples.append(p0); tangents.append(dir); turn_signs.append(0.0)
		samples.append(p1); tangents.append(dir); turn_signs.append(0.0)
	else:
		var p0: Vector3 = waypoints[0]
		var p1: Vector3 = waypoints[1]
		var p2: Vector3 = waypoints[2]
		var d0 := (p1 - p0).normalized()
		var d1 := (p2 - p1).normalized()
		var r := minf(corner_radius, minf(p0.distance_to(p1) * 0.48, p1.distance_to(p2) * 0.48))
		var t0 := p1 - d0 * r
		var t1 := p1 + d1 * r
		var arc_center := t0 + d1 * r
		# Right-hand perpendicular of d0 is (d0.z, 0, -d0.x); sign > 0 means turning right.
		var right0 := Vector3(d0.z, 0.0, -d0.x)
		var turn_sign := signf(right0.dot(d1))
		# Straight leg 1: door -> corner tangent start.
		samples.append(p0); tangents.append(d0); turn_signs.append(0.0)
		samples.append(t0); tangents.append(d0); turn_signs.append(0.0)
		# Small tight circular fillet arc through the 90-degree corner.
		var arc_steps := 16
		for k in range(1, arc_steps):
			var theta := (PI * 0.5) * float(k) / float(arc_steps)
			var pt := arc_center - d1 * (r * cos(theta)) + d0 * (r * sin(theta))
			var tan_dir := (d1 * sin(theta) + d0 * cos(theta)).normalized()
			samples.append(pt); tangents.append(tan_dir); turn_signs.append(turn_sign)
		# Straight leg 2: corner tangent end -> sidewalk.
		samples.append(t1); tangents.append(d1); turn_signs.append(0.0)
		samples.append(p2); tangents.append(d1); turn_signs.append(0.0)

	var lengths := PackedFloat32Array([0.0])
	for i in range(1, samples.size()):
		lengths.append(lengths[i - 1] + samples[i].distance_to(samples[i - 1]))
	var total := lengths[lengths.size() - 1]
	var start_s := 0.41
	var end_s := total - 0.39
	var steps := maxi(2, roundi((end_s - start_s) / 0.86))
	for row in steps + 1:
		var target_s := lerpf(start_s, end_s, float(row) / float(steps))
		var seg := 0
		while seg < lengths.size() - 2 and lengths[seg + 1] < target_s:
			seg += 1
		var u := (target_s - lengths[seg]) / maxf(0.0001, lengths[seg + 1] - lengths[seg])
		var center := samples[seg].lerp(samples[seg + 1], u)
		var tangent := tangents[seg].lerp(tangents[seg + 1], u).normalized()
		var right := Vector3(tangent.z, 0.0, -tangent.x)
		var yaw := atan2(tangent.x, tangent.z)
		var on_curve := absf(turn_signs[seg]) > 0.5 or absf(turn_signs[seg + 1]) > 0.5
		var curve_sign := turn_signs[seg] if absf(turn_signs[seg]) > 0.5 else turn_signs[seg + 1]
		for side in [-1, 1]:
			var is_inner := on_curve and (float(side) * curve_sign > 0.0)
			var stone_len := 0.66 if is_inner else 0.80
			var stone := TownProps.box(self, center + right * (side * 0.54) + Vector3.UP * 0.075, Vector3(1.02, 0.1, stone_len), Color("c9c8bb"))
			stone.rotation.y = yaw
			stone.set_meta("batch_static", true)

func _flower(p: Vector3, color: Color) -> void:
	var parts: Array[MeshInstance3D]=[]
	parts.append(TownProps.cylinder(self,p+Vector3.UP*.22,.025,.44,Color("718d60")))
	for i in range(5):
		var a:=i*TAU/5
		parts.append(TownProps.ball(self,p+Vector3(cos(a)*.09,.47,sin(a)*.09),Vector3(.15,.09,.15),color))
	parts.append(TownProps.ball(self,p+Vector3.UP*.49,Vector3(.10,.07,.10),Color("f0d493")))
	for part in parts:
		part.set_meta("batch_static",true)
		part.set_meta("toy_pivot",p)

func _process(dt: float) -> void:
	if game.paused: return
	time+=dt
	for i in (fountain_drops.size() if TownProps.near_view(game.camera,Vector3(-23,1,-10),4) else 0):
		var t:=fmod(time*.8+float(i%6)/6,1.0)
		var a:=float(i/6)*TAU/6
		fountain_drops[i].position=Vector3(cos(a)*t*1.6,1.72+1.2*t-2.2*t*t,sin(a)*t*1.6)
