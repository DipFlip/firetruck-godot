extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for model in ["person","person_bun","person_joined","tree","tree1","hydrant"]:
		for level in ToyBlendRig.LEVELS:
			var file:=FileAccess.open("res://builds/blend/%s_%03d.meshbin"%[model,level],FileAccess.READ)
			var count:=file.get_32()
			var index_count:=file.get_32()
			var points:=file.get_buffer(count*12).to_float32_array()
			var directions:=file.get_buffer(count*12).to_float32_array()
			var paints:=file.get_buffer(count*12).to_float32_array()
			var vertices:=PackedVector3Array()
			var normals:=PackedVector3Array()
			var colours:=PackedColorArray()
			vertices.resize(count)
			normals.resize(count)
			colours.resize(count)
			for i in count:
				vertices[i]=Vector3(points[i*3],points[i*3+1],points[i*3+2])
				normals[i]=Vector3(directions[i*3],directions[i*3+1],directions[i*3+2])
				colours[i]=Color(paints[i*3],paints[i*3+1],paints[i*3+2])
			var arrays:=[]
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_COLOR]=colours
			var uv:=file.get_buffer(count*8).to_float32_array()
			var coordinates:=PackedVector2Array()
			coordinates.resize(count)
			for i in count: coordinates[i]=Vector2(uv[i*2],uv[i*2+1])
			arrays[Mesh.ARRAY_TEX_UV]=coordinates
			var bones:=file.get_buffer(count*16).to_int32_array()
			var weights:=file.get_buffer(count*16).to_float32_array()
			if model.begins_with("person"):
				arrays[Mesh.ARRAY_BONES]=bones
				arrays[Mesh.ARRAY_WEIGHTS]=weights
			arrays[Mesh.ARRAY_INDEX]=file.get_buffer(index_count*4).to_int32_array()
			var mesh:=ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var material:=ShaderMaterial.new()
			material.shader=preload("res://shaders/toy_blend.gdshader")
			material.set_shader_parameter("use_palette",model.begins_with("person"))
			mesh.surface_set_material(0,material)
			var importer:=ImporterMesh.new()
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},material)
			importer.generate_lods(60,20,[])
			mesh=importer.get_mesh()
			var path:="res://assets/scenery/blend_%s_%03d.res"%[model,level]
			assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
			print("Baked ",path," (",count," vertices)")
	quit()
