class_name ToyRailGate
extends Node3D

var hinge: Node3D
var boom_body: AnimatableBody3D
var lamp: MeshInstance3D
var opening:=0.0
var train_near:=false

func _ready() -> void:
	name="WoodenRailwayPortal"
	set_meta("toy_arrival","drop")
	var wood:=Playroom.wood_finish(Color("d5b282"))
	var supports:=Node3D.new()
	add_child(supports)
	for z in [-4.075,4.075]:
		var leg:=TownProps.box(supports,Vector3(0,.95,z),Vector3(1.8,1.9,1.05),Color.WHITE)
		leg.material_override=wood
		leg.set_meta("batch_static",true)
		TownProps.collider(self,Vector3(0,1,z),Vector3(1.8,2,1.05))
	var curve:=MeshInstance3D.new()
	curve.name="BentWoodArch"
	curve.mesh=_arch_mesh()
	var bent:=Playroom.wood_finish(Color("d5b282"))
	bent.set_shader_parameter("bent",true)
	curve.material_override=bent
	supports.add_child(curve)
	for z in [-4.075,4.075]:
		for y in [.5,1.4]:
			for x in [-.93,.93]:
				var peg:=TownProps.cylinder(supports,Vector3(x,y,z),.13,.06,Color("aa855c"))
				peg.rotation.z=PI/2
				peg.set_meta("batch_static",true)
	TownProps.batch_decorations(supports)
	# The striped boom swings towards the top of the arch, never into the train.
	var pedestal:=TownProps.box(self,Vector3(-1.25,.65,-3.65),Vector3(.75,1.3,.8),Color("557785"))
	pedestal.name="GatePedestal"
	hinge=Node3D.new()
	add_child(hinge)
	hinge.position=Vector3(-1.25,1.3,-3.65)
	TownProps.box(hinge,Vector3(0,0,3.65),Vector3(.28,.30,7.3),Color("f0ece0"))
	for z in [1.0,2.6,4.2,5.8,7.0]:
		TownProps.box(hinge,Vector3(0,0,z),Vector3(.30,.32,.65),Color("c65d51"))
	var pin:=TownProps.cylinder(self,hinge.position,.23,.9,Color("ddbe85"))
	pin.rotation.z=PI/2
	lamp=TownProps.ball(self,Vector3(-1.25,1.75,-3.65),Vector3(.25,.25,.25),Color("c65d51"))
	boom_body=AnimatableBody3D.new()
	boom_body.collision_layer=Playroom.WALL_LAYER
	boom_body.collision_mask=1
	boom_body.add_to_group("wooden_boundary")
	hinge.add_child(boom_body)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.34,.34,7.3)
	shape.shape=box
	shape.position.z=3.65
	boom_body.add_child(shape)

func update_train(train_x: float, running: bool, dt: float) -> void:
	# Allow a full lifting animation before the boiler reaches the opening,
	# and keep the gate raised until the rear of the locomotive has cleared.
	train_near=running and absf(train_x-global_position.x)<18.0
	opening=move_toward(opening,1.0 if train_near else 0.0,dt/1.15)
	var eased:=opening*opening*(3.0-2.0*opening)
	hinge.rotation.x=-PI*.48*eased
	lamp.material_override=TownProps.material(Color("81b79a") if train_near else Color("c65d51"))

# A continuous curved piece with a real opening rather than a pile of wedges.
static func _arch_mesh() -> ArrayMesh:
	var builder:=SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		var a:=float(i)*PI/32
		var b:=float(i+1)*PI/32
		var inner_a:=Vector3(0,1.9+sin(a)*3.55,cos(a)*3.55)
		var inner_b:=Vector3(0,1.9+sin(b)*3.55,cos(b)*3.55)
		var outer_a:=Vector3(0,1.9+sin(a)*4.6,cos(a)*4.6)
		var outer_b:=Vector3(0,1.9+sin(b)*4.6,cos(b)*4.6)
		for side in [-1.0,1.0]:
			var offset:=Vector3(side*.9,0,0)
			_quad(builder,inner_a+offset,inner_b+offset,outer_b+offset,outer_a+offset,Vector3(side,0,0))
		var middle:=(a+b)*.5
		_quad(builder,outer_a+Vector3(-.9,0,0),outer_b+Vector3(-.9,0,0),outer_b+Vector3(.9,0,0),outer_a+Vector3(.9,0,0),Vector3(0,sin(middle),cos(middle)))
		_quad(builder,inner_a+Vector3(.9,0,0),inner_b+Vector3(.9,0,0),inner_b+Vector3(-.9,0,0),inner_a+Vector3(-.9,0,0),Vector3(0,-sin(middle),-cos(middle)))
	return builder.commit()

static func _quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var points: Array=[a,b,c,a,c,d] if (b-a).cross(c-a).dot(normal)<0 else [a,c,b,a,d,c]
	for point in points:
		builder.set_normal(normal)
		builder.add_vertex(point)
