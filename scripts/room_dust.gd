class_name RoomDust
extends MultiMeshInstance3D

# Sunlit dust drifting above the play mat. Positions wrap in the shader around
# the point the camera looks at, so nothing is simulated on the CPU.
const COUNT:=55
const BOX:=Vector3(60,24,60)
const HEIGHT:=9.0
var game: Node3D
var dust: ShaderMaterial
var strength:=0.0
var boost:=1.0

func _ready() -> void:
	name="RoomDust"
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	var specks:=MultiMesh.new()
	specks.transform_format=MultiMesh.TRANSFORM_3D
	specks.mesh=quad
	specks.instance_count=COUNT
	var rng:=RandomNumberGenerator.new()
	rng.seed=5309
	for i in COUNT:
		specks.set_instance_transform(i,Transform3D(Basis(),Vector3(rng.randf()*BOX.x,rng.randf()*BOX.y,rng.randf()*BOX.z)))
	multimesh=specks
	dust=ShaderMaterial.new()
	dust.shader=preload("res://shaders/dust.gdshader")
	dust.set_shader_parameter("box_size",BOX)
	# Compatibility has no glow pass, so its specks need a little more presence.
	if RenderingServer.get_current_rendering_method()=="gl_compatibility": boost=1.6
	material_override=dust
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb=AABB(Vector3(-400,-50,-400),Vector3(800,150,800))

func _process(dt: float) -> void:
	var camera: Camera3D=game.camera
	if not camera: return
	# Centre the dust volume where the view ray meets mid-air above the mat.
	var forward:=-camera.global_basis.z
	var reach:=(camera.global_position.y-HEIGHT)/maxf(.1,-forward.y)
	dust.set_shader_parameter("centre",camera.global_position+forward*reach)
	# Specks are only visible close up; the wide intro overview loses them.
	var target:=clampf(pow(25.8/maxf(1,camera.size),1.5),0,1.1)
	strength=lerpf(strength,target,1-exp(-6*dt))
	dust.set_shader_parameter("strength",strength*boost)
