class_name TownProps
extends RefCounted

static var materials: Dictionary = {}
static var rounded_mesh: Mesh
static var sphere_mesh: SphereMesh
static var cylinder_meshes: Dictionary = {}
static var effect_shaders: Dictionary = {}

static func model(path: String, parent: Node3D) -> Node3D:
	var node: Node3D=load(path).instantiate()
	parent.add_child(node)
	return node

static func collider(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body:=StaticBody3D.new()
	parent.add_child(body)
	body.position=pos
	var c:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	c.shape=shape
	body.add_child(c)

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.4
	materials[key] = m
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if rounded_mesh==null:
		var source: Node3D=load("res://assets/models/rounded_cube.glb").instantiate()
		rounded_mesh=source.get_child(0).mesh
		source.free()
	node.mesh = rounded_mesh
	node.scale=size
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = Vector3.ONE
		shape.shape = bounds
		body.add_child(shape)
		node.add_child(body)
	return node

static func ball(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if sphere_mesh==null:
		sphere_mesh=SphereMesh.new()
		sphere_mesh.radial_segments=20
		sphere_mesh.rings=12
	node.mesh=sphere_mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	node.scale = size
	return node

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var key:=Vector3(radius,height,top)
	if not cylinder_meshes.has(key):
		var mesh:=CylinderMesh.new()
		mesh.top_radius=radius if top<0 else top
		mesh.bottom_radius=radius
		mesh.height=height
		mesh.radial_segments=20
		cylinder_meshes[key]=mesh
	node.mesh=cylinder_meshes[key]
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

static func label(parent: Node3D, pos: Vector3, words: String, size: int = 40) -> Label3D:
	var l := Label3D.new()
	parent.add_child(l)
	l.position = pos
	l.text = words
	l.font_size = size
	l.pixel_size = 0.025
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("fff3d4")
	l.outline_modulate = Color("253e47")
	return l

static func tree(parent: Node3D, pos: Vector3, size: float = 1.0) -> Node3D:
	var root:=Node3D.new()
	root.name="GardenTree"
	parent.add_child(root)
	root.position=pos
	var art:=model("res://assets/models/tree_%d.glb" % (1 if pos.x<0 and pos.z>0 else 0),root)
	art.scale=Vector3.ONE*size
	art.rotation.y=pos.x*0.3
	collider(root,Vector3(0,1.25,0),Vector3(0.48,2.5,0.48)*size)
	return root

static func house(parent: Node3D, pos: Vector3, color: Color, title: String, height: float = 5.0) -> void:
	var root:=Node3D.new()
	root.name=title.to_pascal_case()
	parent.add_child(root)
	root.position=pos
	var file:="cottage"
	if title.contains("STATION"): file="station"
	elif title.contains("BAKERY"): file="bakery"
	elif color.r>color.g: file="peach_house"
	model("res://assets/models/"+file+".glb",root)
	collider(root,Vector3(0,2.5,0),Vector3(8,5,6))

static func person(parent: Node3D, pos: Vector3, shirt: Color) -> Node3D:
	var p:=Node3D.new()
	p.name="Neighbour"
	parent.add_child(p)
	p.position=pos
	var skin:=Color("d9a17b")
	var hair:=Color("694f3f")
	if shirt==Color("ecb354"): hair=Color("99523b"); skin=Color("dfac81")
	if shirt==Color("6d9cb2"): skin=Color("b88160"); hair=Color("4b3f37")
	if shirt==Color("b88ca1"): hair=Color("c8c6b4"); skin=Color("d1a888")
	for x in [-0.22,0.22]:
		box(p,Vector3(x,0.4,0),Vector3(0.27,0.68,0.32),Color("465967"))
		ball(p,Vector3(x,0.1,-0.12),Vector3(0.37,0.24,0.57),Color("775d4a"))
	ball(p,Vector3(0,1.03,0),Vector3(0.94,1.08,0.60),shirt)
	box(p,Vector3(0,1.09,-0.29),Vector3(0.045,0.63,0.035),shirt.darkened(0.16))
	for y in [0.85,1.08,1.31]: ball(p,Vector3(0,y,-0.325),Vector3.ONE*0.075,Color("e8d4ac"))
	ball(p,Vector3(0,1.94,0),Vector3(1.01,1.07,0.88),skin)
	ball(p,Vector3(0,2.29,0.06),Vector3(1.07,0.62,0.95),hair)
	for side in [-1,1]:
		ball(p,Vector3(side*0.47,1.92,0),Vector3(0.18,0.28,0.2),skin)
		ball(p,Vector3(side*0.34,2.32,-0.23),Vector3(0.4,0.34,0.32),hair)
		var arm:=Node3D.new()
		p.add_child(arm)
		arm.name="ArmLeft" if side<0 else "ArmRight"
		arm.position=Vector3(side*0.48,1.35,0)
		arm.rotation.z=side*0.12
		ball(arm,Vector3(0,-0.28,0),Vector3(0.28,0.65,0.32),shirt)
		ball(arm,Vector3(0,-0.62,0),Vector3(0.22,0.24,0.22),skin)
	var eyes:=Node3D.new()
	p.add_child(eyes)
	eyes.name="Eyes"
	eyes.position=Vector3(0,1.98,-0.413)
	for side in [-1,1]:
		ball(eyes,Vector3(side*0.205,0,0),Vector3(0.12,0.175,0.075),Color("3b4037"))
		ball(eyes,Vector3(side*0.205-0.025,0.045,-0.04),Vector3.ONE*0.033,Color("fff1d6"))
	ball(p,Vector3(0,1.84,-0.455),Vector3(0.15,0.13,0.16),skin.lightened(0.08))
	ball(p,Vector3(0,1.68,-0.41),Vector3(0.17,0.055,0.045),Color("956352"))
	if shirt==Color("b88ca1"):
		ball(p,Vector3(0,2.57,0.1),Vector3(0.48,0.46,0.5),hair)
	return p

# Compatibility/WebGL has a much smaller instance-uniform buffer. Particle
# pools use separate material parameters there so trails never exhaust it.
static func effect_material(shader: Shader) -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		if not effect_shaders.has(shader.resource_path):
			var web_shader:=Shader.new()
			web_shader.code=shader.code.replace("instance uniform", "uniform")
			effect_shaders[shader.resource_path]=web_shader
		material.shader=effect_shaders[shader.resource_path]
	else: material.shader=shader
	return material

static func effect_instance(material: ShaderMaterial) -> ShaderMaterial:
	return material.duplicate() as ShaderMaterial if RenderingServer.get_current_rendering_method()=="gl_compatibility" else material

static func effect_opacity(mesh: MeshInstance3D, value: float) -> void:
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		(mesh.material_override as ShaderMaterial).set_shader_parameter("opacity",value)
	else: mesh.set_instance_shader_parameter("opacity",value)

# Merge opt-in, static decoration after collision surfaces and breakable props
# have been registered. Small spatial groups preserve neighbourhood culling.
static func batch_decorations(root: Node3D) -> int:
	var groups: Dictionary={}
	var count:=0
	for child in root.get_children():
		if not child is MeshInstance3D or not child.get_meta("batch_static",false): continue
		var cell:=Vector2i(floori(child.position.x/16),floori(child.position.z/16))
		var key:="%s/%s/%s" % [child.mesh.get_rid(),child.material_override.get_rid(),cell]
		if not groups.has(key): groups[key]=[]
		groups[key].append(child)
	for meshes in groups.values():
		if meshes.size()<2: continue
		var batch:=MultiMeshInstance3D.new()
		var instances:=MultiMesh.new()
		instances.transform_format=MultiMesh.TRANSFORM_3D
		instances.mesh=meshes[0].mesh
		instances.instance_count=meshes.size()
		batch.multimesh=instances
		batch.material_override=meshes[0].material_override
		root.add_child(batch)
		for i in meshes.size():
			instances.set_instance_transform(i,meshes[i].transform)
			meshes[i].hide()
			meshes[i].queue_free()
			count+=1
	return count
