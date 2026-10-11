class_name ToyBlendRig
extends Node3D
# Cache geometry once; the existing toy joints continue to drive its skin.
const LEVELS:=[10,15,25,50,75,100]
const BONE_NAMES:=["Body","LeftArm","RightArm","Head","LeftLeg","RightLeg","Eyes"]
static var mesh_cache: Dictionary={}
static var palette_cache: Dictionary={}
var toy: Node3D
var model: String
var art: MeshInstance3D
var skeleton: Skeleton3D
var joints: Array[Node3D]=[]
var rests: Array[Transform3D]=[]
var sources: Array[Dictionary]=[]
var strength:=0

static func mesh_for(kind: String, level: int) -> Mesh:
	var key:="%s_%03d"%[kind,level]
	if not mesh_cache.has(key): mesh_cache[key]=load("res://assets/scenery/blend_"+key+".res")
	return mesh_cache[key]

static func person_palette(person: Node3D) -> ShaderMaterial:
	var shirt:=Color("ecb354")
	var skin:=Color("dfac81")
	var hair:=Color("99523b")
	var inverse:=person.global_transform.affine_inverse()
	for part: MeshInstance3D in person.find_children("*","MeshInstance3D",true,false):
		var material:=part.get_active_material(0) as StandardMaterial3D
		if not material or part.get_meta("assembly_vertices",false): continue
		var at: Vector3=inverse*part.global_position
		if at.distance_to(Vector3(0,1.03,0))<.02: shirt=material.albedo_color
		elif part.name=="Head": skin=material.albedo_color
		elif at.distance_to(Vector3(0,2.29,.06))<.02: hair=material.albedo_color
	var key:=shirt.to_html()+skin.to_html()+hair.to_html()
	if not palette_cache.has(key):
		var material:=ShaderMaterial.new()
		material.shader=preload("res://shaders/toy_blend.gdshader")
		material.set_shader_parameter("use_palette",true)
		material.set_shader_parameter("shirt",shirt)
		material.set_shader_parameter("skin",skin)
		material.set_shader_parameter("hair",hair)
		material.set_shader_parameter("nose",skin.lightened(.08))
		material.set_shader_parameter("seam",shirt.darkened(.16))
		palette_cache[key]=material
	return palette_cache[key]

func setup(owner_toy: Node3D, kind: String) -> void:
	toy=owner_toy
	model=kind
	name="ColourBlendRig"
	process_priority=90
	# Snapshot rendered batches as well as their suppressed source primitives.
	# Held props keep their independent wrists and materials.
	for part: GeometryInstance3D in toy.find_children("*","GeometryInstance3D",true,false):
		var accessory: bool=part.get_meta("blend_accessory",false)
		var ancestor: Node=part.get_parent()
		while ancestor and ancestor!=toy:
			if ancestor.name in ["Drink","Sandwich"] or ancestor.get_meta("blend_accessory",false): accessory=true
			ancestor=ancestor.get_parent()
		if not accessory: sources.append({"part":part,"layers":part.layers,"shadow":part.cast_shadow})
	art=MeshInstance3D.new()
	art.name="BlendedToy"
	# Travel assigns each mat's render layer before these replacement meshes
	# are created. Keep that layer so departure hides their art and shadows too.
	var render_layers:=0
	for source in sources: render_layers|=source.layers
	art.layers=render_layers if render_layers!=0 else 1
	if kind.begins_with("person"):
		art.material_override=person_palette(toy)
		skeleton=Skeleton3D.new()
		skeleton.name="ToySkeleton"
		add_child(skeleton)
		rests.assign([Transform3D.IDENTITY,Transform3D(Basis.from_euler(Vector3(0,0,-.12)),Vector3(-.48,1.35,0)),Transform3D(Basis.from_euler(Vector3(0,0,.12)),Vector3(.48,1.35,0)),Transform3D(Basis.IDENTITY,Vector3(0,1.55,0)),Transform3D(Basis.IDENTITY,Vector3(-.22,.72,0)),Transform3D(Basis.IDENTITY,Vector3(.22,.72,0)),Transform3D(Basis.IDENTITY,Vector3(0,1.98,-.413))])
		joints.assign([toy,toy.get_node_or_null("ArmLeft"),toy.get_node_or_null("ArmRight"),toy.get_node_or_null("HeadPivot"),toy.get_node_or_null("LegLeft"),toy.get_node_or_null("LegRight"),toy.find_child("Eyes",true,false)])
		var skin:=Skin.new()
		for i in BONE_NAMES.size():
			skeleton.add_bone(BONE_NAMES[i])
			skeleton.set_bone_rest(i,rests[i])
			skin.add_bind(i,rests[i].affine_inverse())
		skeleton.add_child(art)
		art.skeleton=NodePath("..")
		art.skin=skin
		art.custom_aabb=AABB(Vector3(-1.7,-.1,-1.3),Vector3(3.4,4.3,2.6))
	else:
		add_child(art)
	set_strength(0)
	_update_pose()

func set_strength(level: int) -> void:
	strength=level
	art.visible=level>0
	if level>0: art.mesh=mesh_for(model,level)
	# Layers preserve source visibility controlled by intros and prop fades.
	for source in sources:
		if not is_instance_valid(source.part): continue
		source.part.layers=0 if level>0 else source.layers
		source.part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if level>0 else source.shadow
	_update_pose()

func _process(_dt: float) -> void:
	if strength==0 or not skeleton or not toy.is_visible_in_tree(): return
	var camera:=get_viewport().get_camera_3d()
	if camera and not TownProps.near_view(camera,toy.global_position+Vector3.UP*1.8,5): return
	_update_pose()

func _update_pose() -> void:
	if not skeleton: return
	var inverse:=toy.global_transform.affine_inverse()
	for i in joints.size():
		var pose: Transform3D=inverse*joints[i].global_transform if is_instance_valid(joints[i]) else rests[i]
		skeleton.set_bone_global_pose(i,pose)
