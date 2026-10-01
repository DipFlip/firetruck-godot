class_name LittleTown
extends Node3D

@export var hydrants: Array[Vector3] = []
@export var cat: Node3D
@export var dog: Node3D
@export var pool_water: MeshInstance3D
@export var flames: Array[MeshInstance3D] = []
@export var people: Array[Node3D] = []
var time := 0.0
var truck: Node3D
var foliage: Array[Node3D]=[]
var fire_amount := 1.0
var water_response := 0.0

func _ready() -> void:
	if get_child_count()>0:
		_gather_foliage()
		return
	seed(42)
	TownProps.box(self,Vector3(0,-0.5,0),Vector3(160,1,160),Color("8ea57c"),true)
	# Connected street grid; all curbs are shallow enough for rounded supports.
	for x in [-36,0,36]:
		TownProps.box(self,Vector3(x,0.025,0),Vector3(8,0.05,125),Color("7c8984"))
		for side in [-1,1]: TownProps.box(self,Vector3(x+side*4.8,0.08,0),Vector3(1.6,0.16,124),Color("d5cbb3"))
	for z in [-36,0,36]:
		TownProps.box(self,Vector3(0,0.035,z),Vector3(125,0.05,8),Color("7c8984"))
		for side in [-1,1]: TownProps.box(self,Vector3(0,0.08,z+side*4.8),Vector3(124,0.16,1.6),Color("d5cbb3"))
	for line in [-36,0,36]:
		for n in range(-14,15):
			var p := n*4.0
			if absf(p)<7 or absf(absf(p)-36)<7: continue
			TownProps.box(self,Vector3(line,0.075,p),Vector3(0.13,0.02,1.5),Color("f4d898"))
			TownProps.box(self,Vector3(p,0.08,line),Vector3(1.5,0.02,0.13),Color("f4d898"))
	for x in [-36,0,36]:
		for z in [-36,0,36]:
			for k in range(6):
				TownProps.box(self,Vector3(x-3.5+k*1.4,0.09,z+7.4),Vector3(0.7,0.025,2.0),Color("f2e5c8"))
	# Station and shops frame the first street.
	TownProps.house(self,Vector3(-15,0,13),Color("bd6252"),"STATION  04",5)
	TownProps.house(self,Vector3(18,0,19),Color("e9b978"),"SUNRISE BAKERY",5.2)
	TownProps.house(self,Vector3(19,0,-20),Color("76a3a1"),"MAPLE HOUSE",5)
	TownProps.house(self,Vector3(-19,0,-20),Color("dd987d"),"PEACH & PINE",6.3)
	TownProps.house(self,Vector3(49,0,18),Color("c1ae83"),"THE CORNER STORE",5.5)
	TownProps.house(self,Vector3(-48,0,18),Color("9eaaa2"),"POST OFFICE",5)
	TownProps.house(self,Vector3(18,0,49),Color("b99c9b"),"ROSE COTTAGE",4.6)
	TownProps.house(self,Vector3(-19,0,49),Color("e8c997"),"THE GREENHOUSE",4.7)
	TownProps.house(self,Vector3(-49,0,-22),Color("ccaa79"),"WILLOW COTTAGE",5)
	# Mission clearing: tree rescue near the station.
	TownProps.box(self,Vector3(14,0.06,-9),Vector3(13,0.1,9),Color("b9c895"))
	TownProps.tree(self,Vector3(17,0,-10),1.05)
	TownProps.box(self,Vector3(17,2.8,-8.6),Vector3(0.28,0.22,3.1),Color("93674d"))
	cat = _animal(Vector3(17,2.93,-7.2),Color("edc382"),true)
	cat.rotation.y=PI
	people.append(TownProps.person(self,TownLayout.MAYA,Color("ecb354")))
	TownProps.house(self,Vector3(49,0,-29),Color("76a3a1"),"LEO'S COTTAGE",5)
	# Barbecue yard, deliberately open toward the road.
	TownProps.box(self,TownLayout.FIRE+Vector3(0,0.06,-2),Vector3(9,0.12,14),Color("c5cd9c"))
	TownProps.cylinder(self,TownLayout.FIRE+Vector3.UP*0.7,0.65,1.2,Color("465763"))
	TownProps.cylinder(self,TownLayout.FIRE+Vector3.UP*1.35,1.1,0.4,Color("a65043"))
	for i in range(9):
		var flame := TownProps.ball(self,TownLayout.FIRE+Vector3(randf_range(-0.7,0.7),1.7,randf_range(-0.6,0.6)),Vector3(0.6,1.8,0.6),Color("ffb447") if i%2 else Color("ed693c"))
		flame.material_override = TownProps.material(Color("ffb447") if i%2 else Color("ed693c"),true)
		flames.append(flame)
	people.append(TownProps.person(self,TownLayout.LEO,Color("6d9cb2")))
	# Optional jobs have their own targets and persistent state.
	dog = _animal(TownLayout.DOG,Color("876445"),false)
	people.append(TownProps.person(self,TownLayout.JUNE,Color("b88ca1")))
	TownProps.box(self,TownLayout.POOL+Vector3.UP*0.35,Vector3(10,0.7,6),Color("eee6ce"),true)
	pool_water = TownProps.box(self,TownLayout.POOL+Vector3.UP*0.72,Vector3(8.8,0.08,4.8),Color("5eb8cc"))
	people.append(TownProps.person(self,TownLayout.OLIVER,Color("e99869")))
	for pos in [Vector3(-6,0,12),Vector3(6,0,-29),Vector3(30,0,6),Vector3(-30,0,30),Vector3(41,0,-12),Vector3(7,0,55),Vector3(-41,0,-9)]:
		hydrants.append(pos)
		TownProps.cylinder(self,pos+Vector3(0,0.5,0),0.25,1,Color("dd6950"))
		TownProps.ball(self,pos+Vector3(0,1,0),Vector3(0.6,0.4,0.6),Color("f0bd69"))
		TownProps.box(self,pos+Vector3(0,0.65,0),Vector3(0.9,0.23,0.25),Color("dd6950"))
	for pos in [Vector3(-26,0,9),Vector3(-27,0,-10),Vector3(9,0,23),Vector3(27,0,13),Vector3(-10,0,26),Vector3(56,0,-8),Vector3(-49,0,30),Vector3(9,0,46),Vector3(48,0,46),Vector3(-48,0,47)]:
		TownProps.tree(self,pos,randf_range(0.85,1.4))
	# Irregular groves and isolated trees occupy clear lawn, with open roads,
	# front paths and mission gardens preserved.
	for p in TownLayout.woodland_positions():
		TownProps.tree(self,p,randf_range(1.1,1.8))
	for x in [-7,7,29,-29]:
		for z in [-28,10,29]:
			TownProps.cylinder(self,Vector3(x,2.1,z),0.07,4.2,Color("47616a"))
			TownProps.box(self,Vector3(x,4.1,z),Vector3(0.7,0.18,0.6),Color("fff0bf"))
	for pos in [Vector3(-10,0,21),Vector3(10,0,-27),Vector3(-23,0,-8)]:
		TownProps.box(self,pos+Vector3(0,0.65,0),Vector3(2.8,0.2,0.7),Color("b88058"))
		TownProps.box(self,pos+Vector3(0,1.1,0.3),Vector3(2.8,0.8,0.12),Color("b88058"))
		for x in [-1,1]: TownProps.box(self,pos+Vector3(x,0.3,0),Vector3(0.15,0.6,0.5),Color("47616a"))

	# Garden islands, fences, and flower beds add scale without blocking routes.
	for garden in [Vector3(-20,0,24),Vector3(24,0,13),Vector3(-22,0,-28),Vector3(45,0,28)]:
		TownProps.box(self,garden+Vector3(0,0.055,0),Vector3(9,0.1,5),Color("92ab79"))
		for k in range(8):
			var p: Vector3 = garden+Vector3(-4+k*1.1,0,2.5)
			TownProps.box(self,p+Vector3.UP*0.65,Vector3(0.14,1.3,0.14),Color("e9d8b0"))
		for y in [0.4,0.95]: TownProps.box(self,garden+Vector3(0,y,2.5),Vector3(8.4,0.12,0.12),Color("e9d8b0"))
		for k in range(7):
			var p: Vector3 = garden+Vector3(randf_range(-3.5,3.5),0.2,randf_range(-1.7,1.7))
			TownProps.ball(self,p,Vector3(0.5,0.45,0.5),Color("e7ba7c") if k%2 else Color("c58286"))

func _animal(pos: Vector3, color: Color, is_cat: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position=pos
	TownProps.ball(root,Vector3(0,0.5,0),Vector3(0.5,0.6,0.95) if is_cat else Vector3(0.8,0.7,1.3),color)
	TownProps.ball(root,Vector3(0,0.8,-0.4),Vector3(0.6,0.6,0.55),color)
	for x in [-0.2,0.2]:
		TownProps.cylinder(root,Vector3(x,1.1,-0.4),0.15,0.3,color,0.0)
		TownProps.ball(root,Vector3(x*0.6,0.85,-0.66),Vector3(0.08,0.1,0.04),Color("283f46"))
		for z in [-0.3,0.3]: TownProps.box(root,Vector3(x,0.2,z),Vector3(0.15,0.4,0.15),color)
	var tail := TownProps.box(root,Vector3(0,0.65,0.65),Vector3(0.15,0.15,0.6),color)
	tail.rotation.x=-0.5
	return root

func _gather_foliage() -> void:
	for child in get_children():
		if child.get_child_count()>0:
			var first: Node=child.get_child(0)
			if first is Node3D and first.scene_file_path.contains("tree_"): foliage.append(first)

func _process(dt: float) -> void:
	time+=dt
	for i in foliage.size():
		foliage[i].rotation.z=sin(time*0.8+i*1.6)*0.009
		foliage[i].rotation.x=cos(time*0.6+i)*0.006
	for i in flames.size():
		flames[i].visible=fire_amount>0
		flames[i].scale=Vector3(0.6,1.3+sin(time*8+i)*0.5,0.6)*maxf(0.05,fire_amount)*(1.0-water_response*.2)
	for i in people.size():
		var person:=people[i]
		person.scale.y=1+sin(time*2+i)*0.009
		var eyes: Node3D=person.get_node_or_null("Eyes")
		if eyes: eyes.scale.y=0.1 if fmod(time+i*0.8,4.3)<0.13 else 1.0
		if truck and person.global_position.distance_to(truck.global_position)<11:
			var toward:=truck.global_position-person.global_position
			person.rotation.y=lerp_angle(person.rotation.y,atan2(-toward.x,-toward.z),dt*2)
			person.get_node("ArmRight").rotation.z=0.8+sin(time*5+i)*0.25
		else: person.get_node("ArmRight").rotation.z=0.12
	dog.rotation.y = PI+sin(time*2)*0.15
