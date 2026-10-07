class_name RollingMat
extends MeshInstance3D

var finish: ShaderMaterial
static var shared_sheet: ArrayMesh

func _ready() -> void:
	name="PrintedTrafficCarpet"
	if not shared_sheet: shared_sheet=carpet_mesh()
	mesh=shared_sheet
	finish=ShaderMaterial.new()
	finish.shader=preload("res://shaders/play_mat.gdshader")
	finish.set_shader_parameter("felt_color",Color("609958"))
	finish.set_shader_parameter("maple_print",preload("res://assets/scenery/maple_mat.png"))
	if ResourceLoader.exists("res://assets/scenery/race_mat.png"):
		finish.set_shader_parameter("race_print",load("res://assets/scenery/race_mat.png"))
	material_override=finish
	custom_aabb=AABB(Vector3(-100,-1,-100),Vector3(200,65,200))
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	position.y=.14
	hide()

func show_mat(is_race: bool, amount: float, centre: Vector3=Vector3.ZERO) -> void:
	position=centre+Vector3.UP*.14
	finish.set_shader_parameter("race",is_race)
	amount=clampf(amount,0,1)
	finish.set_shader_parameter("roll",amount)
	show()

static func carpet_mesh() -> ArrayMesh:
	# One closed sheet, including its underside and narrow edge faces. The shader
	# curls this same geometry into a spiral; there is no cylinder or hidden print.
	# Half-unit longitudinal spacing keeps the inner wraps smooth in close shots.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in [0.0,-.9]:
		surface.set_normal(Vector3.UP if layer==0 else Vector3.DOWN)
		for z in 320:
			for x in 40:
				var a:=Vector3(-80+x*4,layer,-80+z*.5)
				var b:=a+Vector3(4,0,0)
				var c:=a+Vector3(0,0,.5)
				var d:=a+Vector3(4,0,.5)
				for point in [a,b,c,b,d,c] if layer==0 else [a,c,b,b,c,d]: surface.add_vertex(point)
	for side in [-1,1]:
		surface.set_normal(Vector3.RIGHT*side)
		for z in 320:
			var a:=Vector3(side*80,0,-80+z*.5)
			var b:=a+Vector3(0,0,.5)
			for point in [a,a+Vector3.DOWN*.9,b,b,a+Vector3.DOWN*.9,b+Vector3.DOWN*.9] if side==1 else [a,b,a+Vector3.DOWN*.9,b,b+Vector3.DOWN*.9,a+Vector3.DOWN*.9]: surface.add_vertex(point)
		surface.set_normal(Vector3.BACK*side)
		for x in 40:
			var a:=Vector3(-80+x*4,0,side*80)
			var b:=a+Vector3(4,0,0)
			for point in [a,b,a+Vector3.DOWN*.9,b,b+Vector3.DOWN*.9,a+Vector3.DOWN*.9] if side==1 else [a,a+Vector3.DOWN*.9,b,b,a+Vector3.DOWN*.9,b+Vector3.DOWN*.9]: surface.add_vertex(point)
	# Explicit face normals keep the thin top/underside and cut edges separate.
	# Averaging coincident slab corners smears them into each other in a roll.
	surface.index()
	return surface.commit()
