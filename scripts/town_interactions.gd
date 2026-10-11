class_name TownInteractions
extends Node3D

var game: Node3D
var props: Array[BreakableProp] = []
var hydrant_props: Array[BreakableProp] = []
var npc_guards: Array[PersonalSpace] = []
var dog_guard: PersonalSpace
var ground_effects: Array[PropGroundEffects] = []

func _ready() -> void:
	name="TownInteractions"
	# Adapt the editable baked scene once. New props can call add_prop directly.
	for art in game.town.foliage:
		var root: Node3D=art.get_parent()
		var origin:=root.global_position
		var size: float=art.scale.x
		var prop:=BreakableProp.tree_from_parts(self,game,origin,[root],size)
		_register(prop)
		prop.protected_cat_tree=origin.distance_to(Vector3(17,0,-10))<.1
		if prop.protected_cat_tree:
			var branch:=_parts(game.town,TownLayout.CAT_BRANCH,Vector3(.2,.2,.2))
			for part in branch: part.reparent(prop)
			prop.meshes.clear()
			prop.finish_setup()
			var branch_shape:=CollisionShape3D.new()
			var wood:=BoxShape3D.new()
			wood.size=Vector3(.28,.22,3.1)
			branch_shape.shape=wood
			branch_shape.position=TownLayout.CAT_BRANCH-TownLayout.CAT_TREE
			prop.add_child(branch_shape)
	for x in [-7,7,29,-29]:
		for z in [-28,10,29]:
			var p:=Vector3(x,0,z)
			var lamp:=add_prop("lamp",p,_parts(game.town,p+Vector3.UP*2.1,Vector3(.8,2.2,.8)),Vector3(.18,4.2,.18),Vector3.UP*2.1,.18)
			# The lantern is wider than the pole; give it its own shape so a
			# toppled lamp lies on top of the street rather than through it.
			var head:=CollisionShape3D.new()
			var head_box:=BoxShape3D.new()
			head_box.size=Vector3(.7,.2,.6)
			head.shape=head_box
			head.position=Vector3.UP*4.1
			lamp.add_child(head)
	for p in [Vector3(-10,0,21),Vector3(10,0,-27),Vector3(-23,0,-8)]:
		add_prop("bench",p,_parts(game.town,p+Vector3.UP*.7,Vector3(1.45,.65,.5)),Vector3(2.8,1.3,.8),Vector3.UP*.65,1.1)
	for p in game.town.hydrants:
		# Replace the legacy baked pieces with the same reusable fixture scene
		# used by every other map. Its script owns art, collider and water jet.
		for part in _parts(game.town,p+Vector3.UP*.65,Vector3(.5,.5,.3)): part.free()
		var prop:=FireHydrant.spawn(self,game,p)
		_register(prop)
		hydrant_props.append(prop)
	for garden in [Vector3(-20,0,24),Vector3(24,0,13),Vector3(-22,0,-28),Vector3(45,0,28)]:
		var p: Vector3=garden+Vector3(0,0,2.5)
		add_prop("fence",p,_parts(game.town,p+Vector3.UP*.65,Vector3(4.3,.66,.15)),Vector3(8.5,1.3,.15),Vector3.UP*.65,1.0)
	for child in game.atmosphere.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh and child.scale.is_equal_approx(Vector3(.9,.92,.8)):
			add_prop("bush",child.global_position-Vector3.UP*.44,[child],Vector3(.78,.82,.7),Vector3.UP*.44,.42)
	for p in [Vector3(8,0,10),Vector3(-8,0,-15),Vector3(29,0,23),Vector3(9,0,-26)]:
		add_prop("planter",p,_parts(game.atmosphere,p+Vector3.UP*.8,Vector3(.55,.81,.55)),Vector3(.9,1.5,.9),Vector3.UP*.75,.5)
	for person in game.town.people:
		npc_guards.append(PersonalSpace.protect(person,game.truck))
	dog_guard=PersonalSpace.protect(game.town.dog,game.truck,.85)

func _parts(parent: Node3D, center: Vector3, half: Vector3) -> Array[Node3D]:
	var result: Array[Node3D]=[]
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var delta: Vector3=(child.global_position-center).abs()
		if delta.x<=half.x and delta.y<=half.y and delta.z<=half.z: result.append(child)
	return result

func add_prop(kind: String, origin: Vector3, parts: Array, size: Vector3, center: Vector3, radius: float) -> BreakableProp:
	var prop:=BreakableProp.from_parts(self,game,kind,origin,parts,size,center,radius)
	_register(prop)
	return prop

func _register(prop: BreakableProp) -> void:
	props.append(prop)
	if prop.ground_effect: ground_effects.append(prop.ground_effect)
