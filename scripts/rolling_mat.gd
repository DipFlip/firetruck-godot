class_name RollingMat
extends MeshInstance3D

var finish: ShaderMaterial
var print_fade: ShaderMaterial
static var shared_sheet: ArrayMesh
static var shared_flat_sheet: ArrayMesh
static var print_fade_shader: Shader
const ROLLOUT_SECONDS:=2.075

func _ready() -> void:
	name="PrintedTrafficCarpet"
	if not shared_sheet: shared_sheet=carpet_mesh()
	if not shared_flat_sheet: shared_flat_sheet=flat_carpet_mesh()
	mesh=shared_sheet
	finish=ShaderMaterial.new()
	finish.shader=preload("res://shaders/play_mat.gdshader")
	finish.set_shader_parameter("felt_color",Color("609958"))
	finish.set_shader_parameter("pond_hole",Vector4(RaceCourse.POND_CENTRE.x,RaceCourse.POND_CENTRE.y,RaceCourse.POND_RADIUS.x,RaceCourse.POND_RADIUS.y))
	finish.set_shader_parameter("maple_print",preload("res://assets/scenery/maple_mat.png"))
	if ResourceLoader.exists("res://assets/scenery/race_mat.png"):
		finish.set_shader_parameter("race_print",load("res://assets/scenery/race_mat.png"))
	material_override=finish
	if not print_fade_shader:
		print_fade_shader=Shader.new()
		# Only the settled print needs transparency. The winding sheet retains
		# opaque depth writes so its overlapping wraps still occlude each other.
		print_fade_shader.code=finish.shader.code.replace("render_mode diffuse_burley;","render_mode diffuse_burley, depth_prepass_alpha;").replace("ROUGHNESS=.94;","ROUGHNESS=.94; ALPHA=print_opacity;")
	print_fade=finish.duplicate() as ShaderMaterial
	print_fade.shader=print_fade_shader
	custom_aabb=AABB(Vector3(-100,-1,-100),Vector3(200,65,200))
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	position.y=.14
	hide()

func show_mat(is_race: bool, amount: float, centre: Vector3=Vector3.ZERO, unfolding: bool=true) -> void:
	position=centre+Vector3.UP*.14
	rotation=Vector3.ZERO
	finish.set_shader_parameter("race",is_race)
	amount=clampf(amount,0,1)
	# Curvature needs dense longitudinal vertices only while the sheet rolls.
	# The same closed, rounded felt outline can be drawn with 208 triangles
	# once flat, instead of carrying 52,640 through every close-up and shadow.
	var sheet:=shared_flat_sheet if amount==0 else shared_sheet
	if mesh!=sheet: mesh=sheet
	finish.set_shader_parameter("roll",amount)
	finish.set_shader_parameter("unfolding",unfolding)
	custom_aabb=mesh.get_aabb() if amount==0 else AABB(Vector3(-100,-1,-100),Vector3(200,65,200))
	material_override=finish
	show()

static func rollout_amount(elapsed: float, seconds: float=ROLLOUT_SECONDS) -> float:
	# A quick throw carries the roll outward, then the loose fabric settles.
	return pow(1-clampf(elapsed/seconds,0,1),2.4)

func fade_print(opacity: float) -> void:
	if opacity>=1: return
	print_fade.set_shader_parameter("race",finish.get_shader_parameter("race"))
	print_fade.set_shader_parameter("roll",0.0)
	print_fade.set_shader_parameter("print_opacity",clampf(opacity,0,1))
	material_override=print_fade
	visible=opacity>0

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
				var a:=sheet_point(x,z,layer)
				var b:=sheet_point(x+1,z,layer)
				var c:=sheet_point(x,z+1,layer)
				var d:=sheet_point(x+1,z+1,layer)
				for point in [a,b,c,b,d,c] if layer==0 else [a,c,b,b,c,d]: surface.add_vertex(point)
	for side in [-1,1]:
		for z in 320:
			var a:=sheet_point(40 if side==1 else 0,z,0)
			var b:=sheet_point(40 if side==1 else 0,z+1,0)
			var normal: Vector3=(b-a).cross(Vector3.DOWN).normalized()*side
			surface.set_normal(normal)
			for point in [a,a+Vector3.DOWN*.9,b,b,a+Vector3.DOWN*.9,b+Vector3.DOWN*.9] if side==1 else [a,b,a+Vector3.DOWN*.9,b,b+Vector3.DOWN*.9,a+Vector3.DOWN*.9]: surface.add_vertex(point)
		surface.set_normal(Vector3.BACK*side)
		for x in 40:
			var a:=sheet_point(x,320 if side==1 else 0,0)
			var b:=sheet_point(x+1,320 if side==1 else 0,0)
			for point in [a,b,a+Vector3.DOWN*.9,b,b+Vector3.DOWN*.9,a+Vector3.DOWN*.9] if side==1 else [a,a+Vector3.DOWN*.9,b,b,a+Vector3.DOWN*.9,b+Vector3.DOWN*.9]: surface.add_vertex(point)
	# Explicit face normals keep the thin top/underside and cut edges separate.
	# Averaging coincident slab corners smears them into each other in a roll.
	surface.index()
	return surface.commit()

static func flat_carpet_mesh() -> ArrayMesh:
	var outline: Array[Vector3]=[]
	for corner in 4:
		var centre:=Vector3(75.5 if corner<2 else -75.5,0,-75.5 if corner==0 or corner==3 else 75.5)
		for step in 13:
			var angle: float=(-.5+corner*.5+step/24.0)*PI
			outline.append(centre+Vector3(cos(angle),0,sin(angle))*4.5)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in [0.0,-.9]:
		surface.set_normal(Vector3.UP if layer==0 else Vector3.DOWN)
		for i in outline.size():
			var a: Vector3=outline[i]+Vector3.UP*layer
			var b: Vector3=outline[(i+1)%outline.size()]+Vector3.UP*layer
			for point in [Vector3.UP*layer,a,b] if layer==0 else [Vector3.UP*layer,b,a]: surface.add_vertex(point)
	for i in outline.size():
		var a:=outline[i]
		var b:=outline[(i+1)%outline.size()]
		surface.set_normal((b-a).cross(Vector3.DOWN).normalized())
		for point in [a,a+Vector3.DOWN*.9,b,b,a+Vector3.DOWN*.9,b+Vector3.DOWN*.9]: surface.add_vertex(point)
	surface.index()
	return surface.commit()

static func sheet_point(x: int, z: int, y: float) -> Vector3:
	var along: float=-80+z*.5
	var bend:=maxf(0,absf(along)-75.5)
	var half_width:=75.5+sqrt(maxf(0,4.5*4.5-bend*bend))
	return Vector3(lerpf(-half_width,half_width,x/40.0),y,along)
