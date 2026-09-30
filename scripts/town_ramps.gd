class_name TownRamps
extends Node3D

var ramps: Array[StaticBody3D]=[]

func _ready() -> void:
	# Clear outer lanes, away from homes, mission yards and traffic loops.
	_make_ramp(Vector3(-51,.06,-36),PI/2)
	_make_ramp(Vector3(36,.06,51),0)
	_make_ramp(Vector3(-36,.06,52),PI)
	_make_ramp(Vector3(52,.06,36),-PI/2)

func _make_ramp(at: Vector3, yaw: float) -> void:
	var body:=StaticBody3D.new()
	body.name="NeighbourhoodRamp"
	add_child(body)
	body.position=at
	body.rotation.y=yaw
	ramps.append(body)
	# A true convex wedge: zero-height approach at +Z, a 1.35 m lip at -Z.
	var points:=PackedVector3Array([Vector3(-1.8,0,3.8),Vector3(1.8,0,3.8),Vector3(-1.8,0,-3.8),Vector3(1.8,0,-3.8),Vector3(-1.8,1.35,-3.8),Vector3(1.8,1.35,-3.8)])
	var collision:=CollisionShape3D.new()
	var hull:=ConvexPolygonShape3D.new()
	hull.points=points
	collision.shape=hull
	body.add_child(collision)
	var mesh:=MeshInstance3D.new()
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[0,4,1],[1,4,5],[0,2,4],[1,5,3],[2,3,5],[2,5,4],[0,1,2],[1,3,2]]:
		for index in tri: surface.add_vertex(points[index])
	surface.generate_normals()
	mesh.mesh=surface.commit()
	mesh.material_override=TownProps.material(Color("577b87"))
	mesh.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
	body.add_child(mesh)
	# Painted mint edge strips and coral launch marks share the deck's slope.
	var deck:=Node3D.new()
	body.add_child(deck)
	deck.position=Vector3(0,.69,0)
	deck.rotation.x=atan2(1.35,7.6)
	for side in [-1,1]: TownProps.box(deck,Vector3(side*1.63,.02,0),Vector3(.14,.025,7.6),Color("ccf3e9"))
	for z in [-2.7,-1.5,-.3]:
		for side in [-1,1]:
			var stripe:=TownProps.box(deck,Vector3(side*.4,.03,z),Vector3(.16,.03,1.05),Color("f18a76"))
			stripe.rotation.y=side*-.7
	for side in [-1,1]:
		TownProps.cylinder(body,Vector3(side*2.15,.22,-3.8),.19,.44,Color("ed816b"),.07)

