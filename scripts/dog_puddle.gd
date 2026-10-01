class_name DogPuddle
extends Node3D

var game: Node3D
var clean:=0.0
var clock:=0.0
var surfaces: Array[MeshInstance3D]=[]
var sizes: Array[Vector3]=[]
var drops: Array[Dictionary]=[]
var jumping:=false

func _ready() -> void:
	name="BiscuitPuddle"
	position=TownLayout.DOG
	for i in 2:
		var mesh:=MeshInstance3D.new()
		var shape:=ImmediateMesh.new()
		shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in 48:
			for angle in [-1.0,j*TAU/48,(j+1)*TAU/48]:
				var p:=Vector3.ZERO if angle<0 else Vector3(cos(angle),0,sin(angle))*.5*(1+.08*sin(angle*5)+.05*cos(angle*3))
				shape.surface_set_normal(Vector3.UP)
				shape.surface_set_uv(Vector2(p.x,p.z)+Vector2.ONE*.5)
				shape.surface_add_vertex(p)
		shape.surface_end()
		mesh.mesh=shape
		mesh.material_override=TownProps.material(Color("8b795d")) if i==0 else TownProps.effect_material(preload("res://shaders/puddle.gdshader"))
		add_child(mesh)
		mesh.position.y=.019+i*.008
		mesh.scale=Vector3(3.5 if i==0 else 3.23,1,2.6 if i==0 else 2.40)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surfaces.append(mesh)
		sizes.append(mesh.scale)
	for i in 18:
		var mesh:=TownProps.ball(self,Vector3.ZERO,Vector3.ONE*.12,Color("91c2c3") if i%3 else Color("9b805f"))
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.hide()
		drops.append({"mesh":mesh,"age":2.0,"velocity":Vector3.ZERO})

func water_hit(point: Vector3, amount: float) -> bool:
	var delta:=point-global_position
	if clean>=1 or point.y>.8 or pow(delta.x/2,2)+pow(delta.z/1.65,2)>1: return false
	clean=minf(1,clean+amount*.8)
	return true

func _process(dt: float) -> void:
	if game.paused or game.loading: return
	clock+=dt
	(surfaces[1].material_override as ShaderMaterial).set_shader_parameter("ripple_time",clock)
	for i in surfaces.size():
		surfaces[i].visible=clean<1
		var shrink:=maxf(.01,1-clean)
		surfaces[i].scale=sizes[i]*Vector3(shrink,1,shrink)
	var splash_time:=fmod(clock,1.0 if game.intro and game.intro.active else 4.5)
	var playful: bool=not game.dog_done and clean<1 and (game.intro and game.intro.active or game.truck.position.distance_to(global_position)<25)
	var hop:=sin(clampf(splash_time/.65,0,1)*PI)*.42 if playful and splash_time<.65 else 0.0
	game.town.dog.position.y=TownLayout.DOG.y+hop
	game.town.dog.rotation.z=sin(clock*8)*.035 if hop>0 else 0.0
	if jumping and hop==0: splash()
	jumping=hop>0
	for drop in drops:
		drop.age+=dt
		if drop.age>.6: drop.mesh.hide(); continue
		drop.velocity+=Vector3.DOWN*12*dt
		drop.mesh.position+=drop.velocity*dt
		drop.mesh.scale=Vector3.ONE*.12*(1-drop.age/.6)
		drop.mesh.show()

func splash() -> void:
	for i in drops.size():
		var angle:=i*TAU/drops.size()
		drops[i].mesh.position=Vector3(cos(angle)*.6,.12,sin(angle)*.5)
		drops[i].velocity=Vector3(cos(angle)*1.8,2.2+float(i%3)*.35,sin(angle)*1.8)
		drops[i].age=0.0
