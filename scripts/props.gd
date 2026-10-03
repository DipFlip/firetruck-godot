class_name TownProps
extends RefCounted

static var materials: Dictionary = {}
static var rounded_mesh: Mesh
static var sphere_mesh: SphereMesh
static var cylinder_meshes: Dictionary = {}
static var effect_shaders: Dictionary = {}
static var bake_scenery:=false
static var toy_materials: Dictionary={}
static var softened_materials: Dictionary={}

static func model(path: String, parent: Node3D) -> Node3D:
	var optimized: String="res://assets/scenery/"+path.get_file().get_basename()+".scn"
	var source_path:=optimized if path.get_file().begins_with("tree_") and ResourceLoader.exists(optimized) else path
	var node: Node3D=load(source_path).instantiate()
	apply_toy_finish(node)
	if path.get_file().begins_with("tree_"): soften_toy_shine(node)
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
	var dark:=maxf(color.r,maxf(color.g,color.b))<.26
	m.roughness = .72 if dark else .38
	m.metallic_specular = 0.42
	m.clearcoat_enabled = not dark and not glow
	m.clearcoat = 0.28
	m.clearcoat_roughness = 0.30
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.4
	m.set_meta("toy_finish",true)
	materials[key] = m
	return m

# Share the same satin plastic palette across imported and procedural art.
# Surface overrides preserve source GLBs and keep colour batching available.
static func toy_finish(source: StandardMaterial3D) -> StandardMaterial3D:
	if source.get_meta("toy_finish",false): return source
	if toy_materials.has(source): return toy_materials[source]
	var paint:=source.duplicate() as StandardMaterial3D
	var dark:=maxf(source.albedo_color.r,maxf(source.albedo_color.g,source.albedo_color.b))<.26 and not source.vertex_color_use_as_albedo
	paint.roughness=.72 if dark else .34
	paint.metallic=minf(source.metallic,.12)
	paint.metallic_specular=.28 if dark else .42
	paint.clearcoat_enabled=not dark and not source.emission_enabled
	paint.clearcoat=.30
	paint.clearcoat_roughness=.28
	paint.set_meta("toy_finish",true)
	toy_materials[source]=paint
	return paint

static func apply_toy_finish(root: Node) -> void:
	if root is MeshInstance3D and root.mesh:
		if root.material_override is StandardMaterial3D:
			root.material_override=toy_finish(root.material_override)
		elif root.material_override==null:
			for surface in root.mesh.get_surface_count():
				var source: Material=root.get_active_material(surface)
				if source is StandardMaterial3D: root.set_surface_override_material(surface,toy_finish(source))
	for child in root.get_children(): apply_toy_finish(child)

# Trees and people retain the toy finish with ten percent gentler highlights.
static func soften_toy_shine(root: Node) -> void:
	if root is MeshInstance3D and root.mesh:
		for surface in root.mesh.get_surface_count():
			var source: Material=root.get_active_material(surface)
			if not source is StandardMaterial3D or source.get_meta("softened_toy_shine",false): continue
			if not softened_materials.has(source):
				var paint:=source.duplicate() as StandardMaterial3D
				paint.metallic_specular*=.9
				paint.clearcoat*=.9
				paint.set_meta("softened_toy_shine",true)
				softened_materials[source]=paint
			if root.material_override is StandardMaterial3D: root.material_override=softened_materials[source]
			else: root.set_surface_override_material(surface,softened_materials[source])
	for child in root.get_children(): soften_toy_shine(child)

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
	soften_toy_shine(p)
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

# Bake fixed geometry into small material groups. Original nodes remain as
# collision/query references; actors and shader-driven geometry are excluded.
static func merge_fixed_geometry(root: Node3D, excluded: Array[Node3D], cache_name: String="") -> int:
	var meshes: Array[MeshInstance3D]=[]
	_collect_fixed(root,excluded,meshes)
	if cache_name.is_empty(): cache_name=root.get_script().resource_path.get_file().get_basename()
	var cache_path: String="res://assets/scenery/"+cache_name+".scn"
	var signature: Array=[]
	for node in meshes:
		var palette: Array=[]
		for surface in node.mesh.get_surface_count():
			var paint: Material=node.get_active_material(surface)
			palette.append([paint.albedo_color,paint.roughness,paint.metallic,paint.transparency] if paint is StandardMaterial3D else paint.resource_path if paint else "")
		signature.append([node.mesh.resource_path,str(node.mesh.get_aabb()),str(palette),node.cast_shadow,str(root.global_transform.affine_inverse()*node.global_transform)])
	var fingerprint:=var_to_bytes(signature).hex_encode().sha256_text()
	if not bake_scenery and ResourceLoader.exists(cache_path):
		var cached: Node3D=load(cache_path).instantiate()
		if cached.get_meta("fingerprint","")==fingerprint:
			root.add_child(cached)
			var indices: Array=cached.get_meta("sources",[])
			for index in indices:
				meshes[index].layers=0
				meshes[index].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return indices.size()
		cached.free()
	var batches: Array[MeshInstance3D]=[]
	var groups: Dictionary={}
	var converted: Dictionary={}
	var tinted: Dictionary={}
	var material_keys: Dictionary={}
	var tinted_materials: Dictionary={}
	var inverse:=root.global_transform.affine_inverse()
	for node in meshes:
		var source: ArrayMesh
		if node.mesh is ArrayMesh: source=node.mesh
		elif node.mesh is PrimitiveMesh:
			if not converted.has(node.mesh):
				var array_mesh:=ArrayMesh.new()
				array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(0))
				converted[node.mesh]=array_mesh
			source=converted[node.mesh]
		else: continue
		var transform:=inverse*node.global_transform
		var p:=transform.origin
		var cell:=Vector2i(floori(p.x/16),floori(p.z/16))
		for surface in node.mesh.get_surface_count():
			var material: Material=node.material_override
			if not material: material=node.get_surface_override_material(surface)
			if not material: material=node.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D: continue
			if source.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: continue
			var surface_mesh:=source
			var surface_index:=surface
			# Bake opaque, untextured palette colours into vertices. Materials
			# that differ only in paint colour can then share one draw call.
			if material.albedo_texture==null and not material.vertex_color_use_as_albedo and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a==1:
				var tint_key:="%s/%s/%s" % [source.get_rid(),surface,material.albedo_color]
				if not tinted.has(tint_key):
					var arrays:=source.surface_get_arrays(surface)
					var colors:=PackedColorArray()
					colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
					colors.fill(material.albedo_color)
					arrays[Mesh.ARRAY_COLOR]=colors
					var colored:=ArrayMesh.new()
					colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
					tinted[tint_key]=colored
				if not tinted_materials.has(material):
					var painted:=material.duplicate() as StandardMaterial3D
					painted.albedo_color=Color.WHITE
					painted.vertex_color_use_as_albedo=true
					painted.vertex_color_is_srgb=true
					tinted_materials[material]=painted
				surface_mesh=tinted[tint_key]
				surface_index=0
				material=tinted_materials[material]
			if not material_keys.has(material): material_keys[material]=_material_signature(material)
			var key:="%s/%s/%s/%s" % [material_keys[material],surface_mesh.surface_get_format(surface_index),node.cast_shadow,cell]
			if not groups.has(key): groups[key]={"material":material,"shadow":node.cast_shadow,"parts":[]}
			groups[key].parts.append({"node":node,"mesh":surface_mesh,"surface":surface_index,"original_surface":surface,"transform":transform})
	var merged: Dictionary={}
	var eligible: Dictionary={}
	for group in groups.values():
		for part in group.parts: eligible[part.node]=eligible.get(part.node,0)+1
	for group in groups.values():
		var parts: Array=group.parts.filter(func(part: Dictionary): return eligible.get(part.node,0)==part.node.mesh.get_surface_count())
		if parts.is_empty(): continue
		var builder:=SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in parts: _append_transformed(builder,part.mesh,part.surface,part.transform)
		builder.set_material(group.material)
		var batch:=MeshInstance3D.new()
		batch.name="FixedSceneryBatch"
		var importer:=ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,builder.commit_to_arrays(),[],{},group.material)
		importer.generate_lods(60,25,[])
		batch.mesh=importer.get_mesh()
		batch.cast_shadow=group.shadow
		root.add_child(batch)
		batches.append(batch)
		for part in parts:
			if not merged.has(part.node): merged[part.node]=[]
			merged[part.node].append(part.original_surface)
	# Only suppress an original once all its surfaces have a replacement.
	for node in merged:
		if merged[node].size()==node.mesh.get_surface_count():
			node.layers=0
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if bake_scenery:
		DirAccess.make_dir_recursive_absolute("res://assets/scenery")
		var baked:=Node3D.new()
		baked.name="BakedScenery"
		baked.set_meta("fingerprint",fingerprint)
		var indices: Array=[]
		for node in merged: indices.append(meshes.find(node))
		baked.set_meta("sources",indices)
		for batch in batches:
			var copy:=batch.duplicate()
			baked.add_child(copy)
			copy.owner=baked
		var scene:=PackedScene.new()
		scene.pack(baked)
		var error:=ResourceSaver.save(scene,cache_path,ResourceSaver.FLAG_COMPRESS)
		assert(error==OK,"Could not bake scenery: "+cache_path)
		baked.free()
	return merged.size()

# SurfaceTool.append_from applies the same basis to normals as positions.
# Thin paving and nonuniform building parts need inverse-transpose normals.
static func _append_transformed(builder: SurfaceTool, mesh: ArrayMesh, surface: int, transform: Transform3D) -> void:
	var arrays:=mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var normal_basis:=transform.basis.inverse().transposed()
	for i in vertices.size(): vertices[i]=transform*vertices[i]
	for i in normals.size(): normals[i]=(normal_basis*normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	if arrays[Mesh.ARRAY_TANGENT]!=null:
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		for i in range(0,tangents.size(),4):
			var tangent: Vector3=(transform.basis*Vector3(tangents[i],tangents[i+1],tangents[i+2])).normalized()
			tangents[i]=tangent.x
			tangents[i+1]=tangent.y
			tangents[i+2]=tangent.z
		arrays[Mesh.ARRAY_TANGENT]=tangents
	var transformed:=ArrayMesh.new()
	transformed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	builder.append_from(transformed,0,Transform3D.IDENTITY)

static func _material_signature(material: StandardMaterial3D) -> String:
	var values: Array=[]
	for property in material.get_property_list():
		var key: String=property.name
		if (property.usage&PROPERTY_USAGE_STORAGE)==0 or key.begins_with("resource_") or key.begins_with("metadata/"): continue
		var value=material.get(key)
		values.append([key,value.get_instance_id() if value is Resource else value])
	return JSON.stringify(values)

static func near_view(camera: Camera3D, point: Vector3, radius: float=3.0) -> bool:
	if not camera or camera.is_position_behind(point): return false
	var view:=camera.get_viewport().get_visible_rect()
	var padding:=radius*view.size.y/maxf(1,camera.size)+32
	return view.grow(padding).has_point(camera.unproject_position(point))

static func _collect_fixed(node: Node3D, excluded: Array[Node3D], meshes: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if not child is Node3D or child in excluded: continue
		if child is CollisionObject3D or child is MultiMeshInstance3D: continue
		if child is MeshInstance3D and child.visible and child.layers!=0 and not child.mesh is QuadMesh:
			meshes.append(child)
		_collect_fixed(child,excluded,meshes)
