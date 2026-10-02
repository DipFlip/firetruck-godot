class_name WaterDrawBatch
extends MultiMeshInstance3D

var truck: FireEngine

func _ready() -> void:
	top_level=true
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_colors=true
	multimesh.mesh=truck.pool[0].mesh
	multimesh.instance_count=truck.pool.size()+truck.splash_pool.size()
	multimesh.visible_instance_count=0
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.roughness=.82
	material_override=material

func _process(_dt: float) -> void:
	var index:=0
	var bounds:=AABB()
	# Keep particle collision, colour and lifetime logic intact. Only replace
	# individual draw submissions, using interpolated poses for smooth water.
	for particles in [truck.droplets,truck.splashes]:
		for particle in particles:
			var source: MeshInstance3D=particle.mesh
			if not source.visible: continue
			var pose:=source.get_global_transform_interpolated()
			multimesh.set_instance_transform(index,pose)
			multimesh.set_instance_color(index,source.material_override.albedo_color)
			bounds=AABB(pose.origin,Vector3.ZERO) if index==0 else bounds.expand(pose.origin)
			index+=1
	multimesh.visible_instance_count=index
	if index>0: custom_aabb=bounds.grow(.6)
