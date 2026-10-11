class_name ToyFire
extends Node3D

# One fire effect and water response for every map. Water amounts are the
# existing droplet budget; only water_required varies between emergencies.
@export var water_required:=.60/.22
var game: Node3D
var flames: Array[MeshInstance3D]=[]
var smoke: Array[MeshInstance3D]=[]
var embers: Array[MeshInstance3D]=[]
var steam_pool: Array[MeshInstance3D]=[]
var steam: Array[Dictionary]=[]
var fire_light: OmniLight3D
var time:=0.0
var feedback:=0.0
var steam_clock:=0.0
var intensity:=1.0
var progress:=0.0:
	set(value):
		progress=clampf(value,0,1)
		intensity=1-progress

func _ready() -> void:
	set_meta("assembly_ignore",true)
	add_to_group("toy_fires")
	var flame_material:=ShaderMaterial.new()
	flame_material.shader=preload("res://shaders/flame.gdshader")
	if flames.is_empty():
		var rng:=RandomNumberGenerator.new()
		rng.seed=421
		for i in 9:
			var flame:=TownProps.ball(self,Vector3(rng.randf_range(-.7,.7),1.7,rng.randf_range(-.6,.6)),Vector3(.6,1.8,.6),Color("ffb447"))
			flames.append(flame)
	else:
		# Preserve Maple Bay's authored flame placement when adopting its art.
		for flame in flames: flame.reparent(self)
	for flame in flames: flame.material_override=flame_material
	for i in 12: smoke.append(_puff(preload("res://shaders/smoke.gdshader")))
	for i in 24:
		var puff:=_puff(preload("res://shaders/steam.gdshader"))
		puff.hide()
		steam_pool.append(puff)
	for i in 9:
		var ember:=TownProps.ball(self,Vector3.ZERO,Vector3.ONE*.07,Color("ffc377"))
		ember.material_override=TownProps.material(Color("ffc377"),true)
		embers.append(ember)
	fire_light=OmniLight3D.new()
	add_child(fire_light)
	fire_light.position=Vector3.UP*2
	fire_light.light_color=Color("ffb660")
	fire_light.omni_range=5
	fire_light.light_energy=.5

func _puff(shader: Shader) -> MeshInstance3D:
	var puff:=MeshInstance3D.new()
	puff.mesh=QuadMesh.new()
	puff.material_override=TownProps.effect_instance(TownProps.effect_material(shader))
	puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	return puff

func apply_water(amount: float) -> bool:
	if amount<=0 or progress>=1 or game.paused: return false
	feedback=1
	progress+=amount/maxf(.001,water_required)
	game.sounds.fire_hit(amount,global_position+Vector3.UP*1.6)
	return true

func _process(dt: float) -> void:
	if game.paused or game.loading or (game.travel and game.travel.active): return
	time+=dt
	feedback=maxf(0,feedback-dt*2.2)
	for i in flames.size():
		flames[i].visible=intensity>0
		flames[i].scale=Vector3(.6,1.3+sin(time*8+i)*.5,.6)*maxf(.05,intensity)*(1-feedback*.2)
	steam_clock-=dt
	if feedback>.1 and steam_clock<=0:
		steam_clock=.09
		for mesh in steam_pool:
			if mesh.visible: continue
			mesh.show()
			mesh.position=Vector3(randf_range(-.65,.65),1.6,randf_range(-.65,.65))
			steam.append({"mesh":mesh,"life":1.15,"velocity":Vector3(randf_range(-.3,.3),1.7,randf_range(-.3,.3))})
			break
	for i in range(steam.size()-1,-1,-1):
		var puff:=steam[i]
		puff.life-=dt
		puff.mesh.position+=puff.velocity*dt
		puff.mesh.scale=Vector3.ONE*(.75+(1.15-puff.life)*1.5)
		puff.mesh.look_at(game.camera.global_position)
		TownProps.effect_opacity(puff.mesh,minf(1,(1.15-puff.life)*8)*maxf(0,puff.life)*.58)
		if puff.life<=0: puff.mesh.hide(); steam.remove_at(i)
	for i in smoke.size():
		var t:=fmod(time*.27+i/12.0,1.0)
		smoke[i].position=Vector3(t*1.2+sin(time+i)*.18,2.2+t*4.5,t*.5)
		smoke[i].scale=Vector3.ONE*(.9+t*2.6)*maxf(.01,intensity)
		TownProps.effect_opacity(smoke[i],(1-t)*.48)
		smoke[i].look_at(game.camera.global_position)
		smoke[i].visible=intensity>0
	for i in embers.size():
		var t:=fmod(time*.55+i/9.0,1.0)
		embers[i].position=Vector3(sin(i*3.7)*t,1.8+t*2.8,cos(i*4.2)*t)
		embers[i].visible=intensity>0
	fire_light.light_energy=(.5+sin(time*14)*.1)*intensity
