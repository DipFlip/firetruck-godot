class_name TownRamps
extends Node3D

var ramps: Array[StaticBody3D]=[]

func _ready() -> void:
	# Mid-block streets bring the jumps into the neighbourhood.
	# Ramps on traffic routes face the direction those cars travel.
	_make_ramp(Vector3(-18,-.02,0),-PI/2)
	_make_ramp(Vector3(-36,-.02,17),0)
	_make_ramp(Vector3(-18,-.02,36),PI/2)
	_make_ramp(Vector3(36,-.02,16),0)

func _make_ramp(at: Vector3, yaw: float) -> void:
	var body:=StaticBody3D.new()
	body.name="NeighbourhoodRamp"
	add_child(body)
	body.position=at
	body.rotation.y=yaw
	ramps.append(body)
	# A true convex wedge: submerged approach at +Z, a 1.41 m world-space lip at -Z.
	# The entry meets the road continuously, including box-shaped town cars.
	var points:=PackedVector3Array([Vector3(-3.6,0,3.8),Vector3(3.6,0,3.8),Vector3(-3.6,0,-3.8),Vector3(3.6,0,-3.8),Vector3(-3.6,1.43,-3.8),Vector3(3.6,1.43,-3.8)])
	var collision:=CollisionShape3D.new()
	var hull:=ConvexPolygonShape3D.new()
	hull.points=points
	collision.shape=hull
	body.add_child(collision)
	var mesh:=MeshInstance3D.new()
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[0,4,1],[1,4,5],[0,2,4],[1,5,3],[2,3,5],[2,5,4],[0,1,2],[1,3,2]]:
		for index in tri: surface.add_vertex(points[index])
	surface.generate_normals()
	mesh.mesh=surface.commit()
	var asphalt:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code=preload("res://shaders/ground.gdshader").code.replace("render_mode diffuse_burley;","render_mode diffuse_burley, cull_disabled;")
	asphalt.shader=shader
	asphalt.set_shader_parameter("base_color",Color("788780"))
	asphalt.set_shader_parameter("grain_scale",18.0)
	asphalt.set_shader_parameter("variation",.045)
	mesh.material_override=asphalt
	body.add_child(mesh)
	# Road paint shares the deck's slope, with unobtrusive warm lane markings.
	var deck:=Node3D.new()
	body.add_child(deck)
	deck.position=Vector3(0,.73,0)
	deck.rotation.x=atan2(1.43,7.6)
	for side in [-1,1]: TownProps.box(deck,Vector3(side*3.43,.02,0),Vector3(.14,.025,7.6),Color("e5e7d9"))
	for z in [-2.7,-1.5,-.3]:
		for side in [-1,1]:
			var stripe:=TownProps.box(deck,Vector3(side*.65,.03,z),Vector3(.16,.03,1.05),Color("e0c98b"))
			stripe.rotation.y=side*-.7
	for side in [-1,1]:
		TownProps.cylinder(body,Vector3(side*3.85,.22,-3.8),.19,.44,Color("ed816b"),.07)

