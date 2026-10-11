extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage:=Node3D.new()
	root.add_child(stage)
	var person:=TownProps.person(stage,Vector3.ZERO,Color("ecb354"))
	var bun_person:=TownProps.person(stage,Vector3.ZERO,Color("ecb354"))
	TownProps.ball(bun_person,Vector3(0,2.57,.1),Vector3(.48,.46,.5),Color("99523b"))
	var models: Dictionary={}
	var toys: Array=[["person",person],["person_bun",bun_person]]
	var hydrant:=Node3D.new()
	stage.add_child(hydrant)
	FireHydrant.build_art(hydrant)
	toys.append(["hydrant",hydrant])
	for variant in 2:
		var tree: Node3D=load("res://assets/models/tree_%d.glb"%variant).instantiate()
		stage.add_child(tree)
		toys.append(["tree" if variant==0 else "tree1",tree])
	for pair in toys:
		var parts: Array=[]
		var is_person: bool=str(pair[0]).begins_with("person")
		for mesh: MeshInstance3D in pair[1].find_children("*","MeshInstance3D",true,false):
			var bounds:=mesh.mesh.get_aabb()
			var pose: Transform3D=pair[1].global_transform.affine_inverse()*mesh.global_transform
			var centre: Vector3=pose*bounds.get_center()
			var inverse:=pose.basis.inverse()
			var normal_basis:=inverse.transposed()
			var path: String=str(pair[1].get_path_to(mesh))
			var bone:=0
			if path.begins_with("ArmLeft/"): bone=1
			elif path.begins_with("ArmRight/"): bone=2
			elif path.begins_with("Eyes/"): bone=6
			elif centre.y>=1.6: bone=3
			elif centre.y<.75: bone=4 if centre.x<0 else 5
			for surface in mesh.mesh.get_surface_count():
				var arrays:=mesh.mesh.surface_get_arrays(surface)
				var points: Array=[]
				var normals: Array=[]
				for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var world:=pose*v
					points.append([world.x,world.y,world.z])
				for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
					var direction: Vector3=(normal_basis*n).normalized()
					normals.append([direction.x,direction.y,direction.z])
				var paint: StandardMaterial3D=mesh.get_active_material(surface)
				var colour:=paint.albedo_color
				var category:=3
				if is_person:
					if colour.is_equal_approx(Color("ecb354")): category=0
					elif colour.is_equal_approx(Color("dfac81")): category=1
					elif colour.is_equal_approx(Color("99523b")): category=2
					elif colour.is_equal_approx(Color("dfac81").lightened(.08)): category=4
					elif colour.is_equal_approx(Color("ecb354").darkened(.16)): category=5
				var eligible:=is_person and category<3 and bounds.size.length()*mesh.scale.length()/sqrt(3)>=.30
				if pair[0]=="hydrant": eligible=colour.is_equal_approx(Color("dd6950"))
				parts.append({"raw":points,"normals":normals,"indices":Array(arrays[Mesh.ARRAY_INDEX]),"path":path,"kind":"ellipsoid" if mesh.mesh is SphereMesh else "cylinder" if mesh.mesh is CylinderMesh else "box","centre":[centre.x,centre.y,centre.z],"radii":[bounds.size.x*.5,bounds.size.y*.5,bounds.size.z*.5],"inverse":[[inverse.x.x,inverse.y.x,inverse.z.x],[inverse.x.y,inverse.y.y,inverse.z.y],[inverse.x.z,inverse.y.z,inverse.z.z]],"colour":[colour.r,colour.g,colour.b],"category":category,"bone":bone,"eligible":eligible})
				if pair[0]=="hydrant" and parts[-1].kind=="box":
					# This rounded crossbar is axis-aligned in fixture space.
					var size: Vector3=bounds.size*mesh.scale*.5
					parts[-1].radii=[size.x,size.y,size.z]
					parts[-1].inverse=[[1,0,0],[0,1,0],[0,0,1]]
					parts[-1].kind="rounded_box"
					parts[-1].rounding=.018
		models[pair[0]]=parts
		print(pair[0]," source surfaces: ",parts.size())
	var file:=FileAccess.open("res://assets/scenery/blend_primitives.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(models))
	stage.free()
	quit()
