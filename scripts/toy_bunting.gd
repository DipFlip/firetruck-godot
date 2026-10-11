class_name ToyBunting
extends RefCounted

static var flag_mesh: ArrayMesh
static var flag_material: ShaderMaterial

static func build(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var root:=TownProps.toy_group(parent,(a+b)*.5,"drop","Bunting")
	a-=root.position
	b-=root.position
	for end in [a,b]: TownProps.cylinder(root,end+Vector3.UP*4,.1,8,Color("d3b184"))
	var tangent: Vector3=(b-a).normalized()
	var rope_colour:=Color("ead6af")
	var points: PackedVector3Array=[]
	for i in 13: points.append(a.lerp(b,float(i)/12)+Vector3.UP*(7.7-sin(float(i)/12*PI)*.8))
	for i in 12: _string(root,points[i],points[i+1],.045,rope_colour)
	var flags:=MultiMeshInstance3D.new()
	flags.name="WindFlags"
	flags.multimesh=MultiMesh.new()
	flags.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	flags.multimesh.use_colors=true
	flags.multimesh.use_custom_data=true
	flags.multimesh.mesh=_mesh()
	flags.multimesh.instance_count=13
	if not flag_material:
		flag_material=ShaderMaterial.new()
		flag_material.shader=preload("res://shaders/bunting.gdshader")
	flags.material_override=flag_material
	root.add_child(flags)
	var basis:=Basis(Vector3.UP,-atan2(tangent.z,tangent.x))
	var colours: Array[Color]=[Color("c97560"),Color("72a9b0"),Color("e5ba6d")]
	for i in 13:
		var top:=points[i]-Vector3.UP*.20
		flags.multimesh.set_instance_transform(i,Transform3D(basis,top))
		flags.multimesh.set_instance_color(i,colours[i%3])
		flags.multimesh.set_instance_custom_data(i,Color(i*1.73+a.x*.07,0,0,0))
		# Two short ties join each pinned flag corner to the sagging main cord.
		for side in [-1,1]:
			var offset: Vector3=tangent*.34*side
			_string(root,points[i]+offset,top+offset,.025,rope_colour)
	return root

static func _string(parent: Node3D, a: Vector3, b: Vector3, thickness: float, colour: Color) -> void:
	var direction:=b-a
	var cord:=TownProps.cylinder(parent,(a+b)*.5,thickness*.5,direction.length(),colour)
	var up:=direction.normalized()
	var right:=up.cross(Vector3.FORWARD).normalized()
	if right.length()<.1: right=up.cross(Vector3.RIGHT).normalized()
	cord.basis=Basis(right,up,right.cross(up))

static func _mesh() -> ArrayMesh:
	if flag_mesh: return flag_mesh
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for row in 7:
		var v:=float(row)/6
		for col in 5:
			var u:=float(col)/4
			vertices.append(Vector3((u-.5)*.68*(1-v),-v*.84,0))
			normals.append(Vector3.BACK)
			uvs.append(Vector2(u,v))
	for row in 6:
		for col in 4:
			var n:=row*5+col
			indices.append_array([n,n+1,n+5,n+1,n+6,n+5])
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	flag_mesh=ArrayMesh.new()
	flag_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return flag_mesh
