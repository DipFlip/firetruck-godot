class_name TownAtmosphere
extends Node3D

var steam: Array[Dictionary]=[]
var steam_pool: Array[MeshInstance3D]=[]
var steam_clock:=0.0
var smoke: Array[MeshInstance3D]=[]
var embers: Array[MeshInstance3D]=[]
var time:=0.0
var game: Node3D
var fire_light: OmniLight3D
var fountain_drops: Array[MeshInstance3D]=[]

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
	# Footpaths and hedges lead the eye through each front garden.
	for garden in [Vector3(18,0,19),Vector3(-19,0,-20),Vector3(19,0,-20),Vector3(-48,0,18),Vector3(49,0,18),Vector3(49,0,-25),Vector3(-49,0,-22),Vector3(18,0,49),Vector3(-19,0,49)]:
		for row in range(5):
			for col in range(2):
				# Bend Rose Cottage's path beside Oliver instead of over the pool.
				var bend: float=-maxf(0,row-1)*.75 if garden==Vector3(18,0,49) else 0.0
				TownProps.box(self,garden+Vector3(-0.56+col*1.12+bend,0.105,4.3+row*.88),Vector3(1.06,.1,.81),Color("c9c8bb")).set_meta("batch_static",true)
		for side in [-1,1]:
			for n in range(5):
				var p: Vector3=garden+Vector3(side*(2.7+n*.65),0,5.8)
				TownProps.ball(self,p+Vector3.UP*.44,Vector3(.9,.92,.8),Color("769266") if n%2 else Color("829d6b"))
			for n in range(5):
				var p: Vector3=garden+Vector3(side*3+randf_range(-1,1),0,4+randf_range(0,1))
				_flower(p,Color("e65d9a") if n%2 else Color("a479df"))
	# Pocket park: a little fountain makes the neighbourhood feel inhabited.
	var center:=Vector3(-23,0,-10)
	TownProps.cylinder(self,center+Vector3.UP*.06,3.0,.12,Color("c8bca1"))
	TownProps.cylinder(self,center+Vector3.UP*.36,2.1,.6,Color("bcaf92"))
	var basin:=TownProps.cylinder(self,center+Vector3.UP*.68,1.88,.08,Color("62a5a6"))
	basin.material_override=water
	TownProps.cylinder(self,center+Vector3.UP*.9,.32,1.5,Color("dacbad"))
	TownProps.cylinder(self,center+Vector3.UP*1.64,.84,.22,Color("d3c4a4"))
	for i in range(36):
		var d:=TownProps.ball(self,center+Vector3.UP*1.72,Vector3.ONE*.09,Color("bce0d2"))
		d.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fountain_drops.append(d)
	# A station forecourt, hose practice markings, and little street props.
	for n in range(5):
		TownProps.box(self,Vector3(-14+n*1.7,.11,19.0),Vector3(1.55,.1,2.4),Color("bcb6a0"))
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
				TownProps.box(self,Vector3(line,0.075,p),Vector3(0.13,0.02,1.5),Color("f4d898")).set_meta("batch_static",true)
				TownProps.box(self,Vector3(p,0.08,line),Vector3(1.5,0.02,0.13),Color("f4d898")).set_meta("batch_static",true)
	var smoke_material:=TownProps.effect_material(preload("res://shaders/smoke.gdshader"))
	for i in range(12):
		var puff:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2.ONE
		puff.mesh=quad
		puff.material_override=TownProps.effect_instance(smoke_material)
		add_child(puff)
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.append(puff)
	var steam_material:=TownProps.effect_material(preload("res://shaders/steam.gdshader"))
	for i in 24:
		var puff:=MeshInstance3D.new()
		puff.mesh=QuadMesh.new()
		puff.material_override=TownProps.effect_instance(steam_material)
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.visible=false
		add_child(puff)
		steam_pool.append(puff)
	var flame_material:=ShaderMaterial.new()
	flame_material.shader=preload("res://shaders/flame.gdshader")
	for flame in town.flames: flame.material_override=flame_material
	for i in range(9):
		var ember:=TownProps.ball(self,Vector3.ZERO,Vector3.ONE*.07,Color("ffc377"))
		ember.material_override=TownProps.material(Color("ffc377"),true)
		embers.append(ember)
	fire_light=OmniLight3D.new()
	add_child(fire_light)
	fire_light.position=TownLayout.FIRE+Vector3.UP*2.0
	fire_light.light_color=Color("ffb660")
	fire_light.omni_range=5.0
	fire_light.light_energy=0.5

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
	steam_clock-=dt
	if game.fire_feedback>.1 and steam_clock<=0:
		steam_clock=.09
		for mesh in steam_pool:
			if mesh.visible: continue
			mesh.visible=true
			mesh.position=TownLayout.FIRE+Vector3(randf_range(-.65,.65),1.6,randf_range(-.65,.65))
			steam.append({"mesh":mesh,"life":1.15,"velocity":Vector3(randf_range(-.3,.3),1.7,randf_range(-.3,.3))})
			break
	for i in range(steam.size()-1,-1,-1):
		var puff:=steam[i]
		puff.life-=dt
		puff.mesh.position+=puff.velocity*dt
		puff.mesh.scale=Vector3.ONE*(.75+(1.15-puff.life)*1.5)
		puff.mesh.look_at(game.camera.global_position)
		TownProps.effect_opacity(puff.mesh,minf(1,(1.15-puff.life)*8)*maxf(0,puff.life)*.58)
		if puff.life<=0: puff.mesh.visible=false; steam.remove_at(i)
	for i in (fountain_drops.size() if TownProps.near_view(game.camera,Vector3(-23,1,-10),4) else 0):
		var t:=fmod(time*.8+float(i%6)/6,1.0)
		var a:=float(i/6)*TAU/6
		fountain_drops[i].position=Vector3(-23+cos(a)*t*1.6,1.72+1.2*t-2.2*t*t,-10+sin(a)*t*1.6)
	for i in smoke.size():
		var t:=fmod(time*.27+i/12.0,1.0)
		smoke[i].position=TownLayout.FIRE+Vector3(t*1.2+sin(time+i)*.18,2.2+t*4.5,t*.5)
		smoke[i].scale=Vector3.ONE*(.9+t*2.6)*maxf(.01,game.town.fire_amount)
		TownProps.effect_opacity(smoke[i],(1-t)*0.48)
		smoke[i].look_at(game.camera.global_position)
		smoke[i].visible=game.town.fire_amount>0
	for i in embers.size():
		var t:=fmod(time*.55+i/9.0,1.0)
		embers[i].position=TownLayout.FIRE+Vector3(sin(i*3.7)*t,1.8+t*2.8,cos(i*4.2)*t)
		embers[i].visible=game.town.fire_amount>0
	fire_light.light_energy=(0.5+sin(time*14)*.1)*game.town.fire_amount
