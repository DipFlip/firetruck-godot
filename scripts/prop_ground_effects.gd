class_name PropGroundEffects
extends Node3D

# Ground remnants stay at the fixture's home while the loose rigid body tumbles.
var prop: BreakableProp
var stump: Node3D
var stump_meshes: Array[GeometryInstance3D]=[]
var water: MultiMeshInstance3D
var ripple: MeshInstance3D
var droplets: Array[Dictionary]=[]
var time:=0.0
var was_active:=false

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	if prop.kind=="tree": _make_stump()
	elif prop.kind=="hydrant": _make_water()
	global_transform=prop.home
	visible=false

func _make_stump() -> void:
	name="TreeStump"
	stump=Node3D.new()
	add_child(stump)
	var size:=prop.radius/.34
	stump_meshes.append(TownProps.cylinder(stump,Vector3(0,.16*size,0),.24*size,.32*size,Color("977251"),.225*size))
	stump_meshes.append(TownProps.cylinder(stump,Vector3(0,.325*size,0),.218*size,.014*size,Color("d3af7a")))
	for radius in [.10,.17]:
		var ring:=MeshInstance3D.new()
		var shape:=TorusMesh.new()
		shape.inner_radius=(radius-.006)*size
		shape.outer_radius=(radius+.006)*size
		shape.rings=16
		shape.ring_segments=6
		ring.mesh=shape
		ring.material_override=TownProps.material(Color("aa865d"))
		stump.add_child(ring)
		ring.position.y=.336*size
		stump_meshes.append(ring)

func _make_water() -> void:
	name="BrokenHydrantWater"
	TownProps.cylinder(self,Vector3(0,.12,0),.18,.24,Color("577584"))
	TownProps.cylinder(self,Vector3(0,.244,0),.125,.014,Color("293f49"))
	water=MultiMeshInstance3D.new()
	var batch:=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true
	# All seven jets share the hose's uploaded sphere; each jet is one draw call.
	batch.mesh=prop.game.truck.pool[0].mesh
	batch.instance_count=96
	water.multimesh=batch
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.roughness=.3
	water.material_override=material
	water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.custom_aabb=AABB(Vector3(-3,0,-3),Vector3(6,4,6))
	add_child(water)
	var rng:=RandomNumberGenerator.new()
	rng.seed=int(prop.home.origin.x*137+prop.home.origin.z*197)+4200
	for i in batch.instance_count:
		var angle:=rng.randf_range(0,TAU)
		var speed:=rng.randf_range(.15,.75) if i<60 else (rng.randf_range(.7,1.7) if i<72 else rng.randf_range(1.5,3.0))
		var up:=rng.randf_range(10.5,12.5) if i<72 else rng.randf_range(2.2,3.5)
		var velocity:=Vector3(cos(angle)*speed,up,sin(angle)*speed)
		var origin:=Vector3.ZERO if i<72 else Vector3(cos(angle),0,sin(angle))*rng.randf_range(.3,1.2)
		# Most drops form a dense rising jet; a smaller layer falls back around it.
		var lifetime:=up/26.0 if i<60 else up*2/26.0
		droplets.append({"velocity":velocity,"origin":origin,"life":lifetime,"phase":rng.randf(),"size":rng.randf_range(.10,.19) if i<72 else rng.randf_range(.07,.12)})
		batch.set_instance_color(i,FireEngine.WATER_COLORS[i%FireEngine.WATER_COLORS.size()])
	ripple=MeshInstance3D.new()
	ripple.mesh=PlaneMesh.new()
	ripple.material_override=TownProps.effect_material(preload("res://shaders/ripple.gdshader"))
	ripple.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ripple)
	ripple.position.y=.18

func _process(dt: float) -> void:
	if not is_instance_valid(prop):
		queue_free()
		return
	if prop.game.paused: return
	var active:=prop.loose or (stump!=null and prop.appearing)
	visible=active
	if not active:
		was_active=false
		return
	global_transform=prop.home
	if stump:
		for mesh in stump_meshes: mesh.transparency=clampf(prop.age,0,1) if prop.appearing else 0.0
		return
	if not was_active: time=0.0
	was_active=true
	time+=dt
	for i in droplets.size():
		var drop:=droplets[i]
		var t:=fmod(time+drop.phase*drop.life,drop.life)
		var position: Vector3=drop.origin+drop.velocity*t+Vector3.DOWN*13*t*t+Vector3.UP*(.25 if i<72 else .13)
		var velocity: Vector3=drop.velocity+Vector3.DOWN*26*t
		var basis:=Basis.looking_at(velocity.normalized(),Vector3.RIGHT)
		var stretch:=1+minf(velocity.length()/10,1.4) if i<72 else 1.0
		basis=basis.scaled(Vector3(1,1,stretch)*drop.size)
		water.multimesh.set_instance_transform(i,Transform3D(basis,position))
	var cycle:=fmod(time,1.1)/1.1
	ripple.scale=Vector3.ONE*(.7+cycle*1.9)
	TownProps.effect_opacity(ripple,(1-cycle)*.25)
