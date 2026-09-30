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

func _ready() -> void:
	seed(421)
	var town: LittleTown=game.town
	# Quiet material variation gives surfaces scale without distracting texture.
	for child in town.get_children():
		if child is MeshInstance3D:
			var material: ShaderMaterial
			if child.scale.x>150:
				material=ShaderMaterial.new()
				material.shader=preload("res://shaders/ground.gdshader")
				material.set_shader_parameter("base_color",Color("6eac67"))
				material.set_shader_parameter("variation",0.20)
				material.set_shader_parameter("meadow",true)
				child.material_override=material
			elif child.scale.y<0.06 and child.scale.x+child.scale.z>100:
				material=ShaderMaterial.new()
				material.shader=preload("res://shaders/ground.gdshader")
				material.set_shader_parameter("base_color",Color("788780"))
				material.set_shader_parameter("grain_scale",18.0)
				material.set_shader_parameter("variation",0.045)
				child.material_override=material
	var water:=ShaderMaterial.new()
	water.shader=preload("res://shaders/pool.gdshader")
	town.pool_water.material_override=water
	# Footpaths and hedges lead the eye through each front garden.
	for garden in [Vector3(18,0,19),Vector3(-19,0,-20),Vector3(19,0,-20),Vector3(-48,0,18),Vector3(49,0,18),Vector3(49,0,-29),Vector3(-49,0,-22),Vector3(18,0,49),Vector3(-19,0,49)]:
		for row in range(5):
			for col in range(2):
				# Bend Rose Cottage's path beside Oliver instead of over the pool.
				var bend: float=-maxf(0,row-1)*.75 if garden==Vector3(18,0,49) else 0.0
				TownProps.box(self,garden+Vector3(-0.56+col*1.12+bend,0.105,4.3+row*.88),Vector3(1.06,.1,.81),Color("c9c8bb"))
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
		var d:=TownProps.ball(self,Vector3.ZERO,Vector3.ONE*.09,Color("bce0d2"))
		d.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fountain_drops.append(d)
	# A station forecourt, hose practice markings, and little street props.
	for n in range(5):
		TownProps.box(self,Vector3(-14+n*1.7,.11,19.0),Vector3(1.55,.1,2.4),Color("bcb6a0"))
	for p in [Vector3(8,0,10),Vector3(-8,0,-15),Vector3(29,0,23),Vector3(9,0,-26)]:
		TownProps.cylinder(self,p+Vector3.UP*.42,.46,.84,Color("b48868"))
		TownProps.ball(self,p+Vector3.UP*.99,Vector3(1.1,1.1,1.1),Color("779569"))
		for i in range(4): _flower(p+Vector3(randf_range(-.4,.4),.9,randf_range(-.4,.4)),Color("d59886"))
	# Curbstone joins are visual only, so the drive surface remains smooth.
	for street in [-36,0,36]:
		for n in range(-27,28):
			if absf(n*2.2)<8 or absf(absf(n*2.2)-36)<8: continue
			for side in [-1,1]:
				TownProps.box(self,Vector3(street+side*4.1,.13,n*2.2),Vector3(.18,.18,2.12),Color("c5bca7"))
				TownProps.box(self,Vector3(n*2.2,.13,street+side*4.1),Vector3(2.12,.18,.18),Color("c5bca7"))
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
	TownProps.cylinder(self,p+Vector3.UP*.22,.025,.44,Color("718d60"))
	for i in range(5):
		var a:=i*TAU/5
		TownProps.ball(self,p+Vector3(cos(a)*.09,.47,sin(a)*.09),Vector3(.15,.09,.15),color)
	TownProps.ball(self,p+Vector3.UP*.49,Vector3(.10,.07,.10),Color("f0d493"))

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
	for i in fountain_drops.size():
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
