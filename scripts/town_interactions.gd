class_name TownInteractions
extends Node3D

var game: Node3D
var props: Array[BreakableProp] = []
var hydrant_props: Array[BreakableProp] = []
var npc_guards: Array[StaticBody3D] = []
var cat_guard: StaticBody3D
var ground_effects: Array[PropGroundEffects] = []

func _ready() -> void:
	name="TownInteractions"
	# Adapt the editable baked scene once. New props can call add_prop directly.
	for art in game.town.foliage:
		var root: Node3D=art.get_parent()
		var origin:=root.global_position
		var size: float=art.scale.x
		var prop:=add_prop("tree",origin,[root],Vector3(.5,4.5,.5)*size,Vector3.UP*2.25*size,15.0,1.5,.34*size)
		prop.protected_cat_tree=origin.distance_to(Vector3(17,0,-10))<.1
		if prop.protected_cat_tree:
			var branch:=_parts(game.town,Vector3(17,2.8,-8.6),Vector3(.2,.2,.2))
			for part in branch: part.reparent(prop)
			prop.meshes.clear()
			prop.finish_setup()
		var crown:=CollisionShape3D.new()
		var sphere:=SphereShape3D.new()
		sphere.radius=1.35*size
		crown.shape=sphere
		crown.position.y=4.1*size
		prop.add_child(crown)
		_ground_effect(prop)
	for x in [-7,7,29,-29]:
		for z in [-28,10,29]:
			var p:=Vector3(x,0,z)
			var lamp:=add_prop("lamp",p,_parts(game.town,p+Vector3.UP*2.1,Vector3(.8,2.2,.8)),Vector3(.18,4.2,.18),Vector3.UP*2.1,5.5,.48,.18)
			# The lantern is wider than the pole; give it its own shape so a
			# toppled lamp lies on top of the street rather than through it.
			var head:=CollisionShape3D.new()
			var head_box:=BoxShape3D.new()
			head_box.size=Vector3(.7,.2,.6)
			head.shape=head_box
			head.position=Vector3.UP*4.1
			lamp.add_child(head)
	for p in [Vector3(-10,0,21),Vector3(10,0,-27),Vector3(-23,0,-8)]:
		add_prop("bench",p,_parts(game.town,p+Vector3.UP*.7,Vector3(1.45,.65,.5)),Vector3(2.8,1.3,.8),Vector3.UP*.65,4.0,.55,1.1)
	for p in game.town.hydrants:
		var prop:=add_prop("hydrant",p,_parts(game.town,p+Vector3.UP*.65,Vector3(.5,.5,.3)),Vector3(.55,1.1,.5),Vector3.UP*.55,8.0,.85,.3)
		hydrant_props.append(prop)
		_ground_effect(prop)
	for garden in [Vector3(-20,0,24),Vector3(24,0,13),Vector3(-22,0,-28),Vector3(45,0,28)]:
		var p: Vector3=garden+Vector3(0,0,2.5)
		add_prop("fence",p,_parts(game.town,p+Vector3.UP*.65,Vector3(4.3,.66,.15)),Vector3(8.5,1.3,.15),Vector3.UP*.65,3.5,.45,1.0)
	for child in game.atmosphere.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh and child.scale.is_equal_approx(Vector3(.9,.92,.8)):
			add_prop("bush",child.global_position-Vector3.UP*.44,[child],Vector3(.78,.82,.7),Vector3.UP*.44,1.8,.16,.42)
	for p in [Vector3(8,0,10),Vector3(-8,0,-15),Vector3(29,0,23),Vector3(9,0,-26)]:
		add_prop("planter",p,_parts(game.atmosphere,p+Vector3.UP*.8,Vector3(.55,.81,.55)),Vector3(.9,1.5,.9),Vector3.UP*.75,2.8,.3,.5)
	for person in game.town.people:
		npc_guards.append(_visibility_guard("NeighbourPersonalSpace",person.global_position))
	cat_guard=_visibility_guard("CatRescuePersonalSpace",Vector3(game.cat_home.x,0,game.cat_home.z),2.4)
	_update_guards()

func _visibility_guard(label: String, origin: Vector3, front_reach: float=4.2) -> StaticBody3D:
	var guard:=StaticBody3D.new()
	guard.name=label
	guard.collision_layer=16
	guard.collision_mask=3
	add_child(guard)
	guard.global_position=origin
	# Overlapping upright capsules form a rounded footprint with extra room
	# on the camera side. The ladder and hose ignore this collision layer.
	var capsule:=CapsuleShape3D.new()
	capsule.radius=1.15
	# Bury the rounded lower cap so this boundary cannot act as a ramp for
	# the truck's spherical supports. The upper cap stays above jump height.
	capsule.height=7.0
	for forward in [0.0,front_reach*.5,front_reach]:
		var collision:=CollisionShape3D.new()
		collision.shape=capsule
		collision.position=Vector3(0,2.5,forward)
		guard.add_child(collision)
	return guard

func _physics_process(_dt: float) -> void:
	if game.paused: return
	_update_guards()

func _update_guards() -> void:
	var toward_camera: Vector3=game.camera.global_basis.z
	var angle:=atan2(toward_camera.x,toward_camera.z)
	for guard in npc_guards: guard.rotation.y=angle
	cat_guard.rotation.y=angle
	# The rescue freezes the truck while the cat is on the ladder. Release the
	# tree's approach zone once the cat boards, keeping the ladder tip reachable.
	cat_guard.collision_layer=0 if game.rescue_running or game.cat_rescued else 16

func _ground_effect(prop: BreakableProp) -> void:
	var effect:=PropGroundEffects.new()
	effect.prop=prop
	add_child(effect)
	ground_effects.append(effect)

func _parts(parent: Node3D, center: Vector3, half: Vector3) -> Array[Node3D]:
	var result: Array[Node3D]=[]
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var delta: Vector3=(child.global_position-center).abs()
		if delta.x<=half.x and delta.y<=half.y and delta.z<=half.z: result.append(child)
	return result

func add_prop(kind: String, origin: Vector3, parts: Array, size: Vector3, center: Vector3, threshold: float, weight: float, radius: float) -> BreakableProp:
	var prop:=BreakableProp.from_parts(self,game,kind,origin,parts,size,center,threshold,weight,radius)
	props.append(prop)
	return prop
