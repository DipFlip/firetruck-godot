class_name DriveSurfaces
extends Node3D

# Query-only geometry for shallow road paint, paving and curbs. The truck's
# rounded physical supports still roll smoothly across these tiny steps.
func register(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh:
			var bounds: AABB=child.mesh.get_aabb()
			var dimensions: Vector3=bounds.size*child.global_basis.get_scale()
			var center: Vector3=child.global_transform*(bounds.position+bounds.size*.5)
			if dimensions.y<.35 and center.y<.25 and center.y>-.1 and dimensions.x*dimensions.z>.035:
				var body:=StaticBody3D.new()
				body.name="PavingSurface"
				body.collision_layer=8
				body.collision_mask=0
				add_child(body)
				body.global_transform=Transform3D(child.global_basis.orthonormalized(),center)
				var shape:=CollisionShape3D.new()
				var box:=BoxShape3D.new()
				box.size=dimensions
				shape.shape=box
				body.add_child(shape)
		else:
			register(child)

