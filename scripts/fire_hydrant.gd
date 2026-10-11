class_name FireHydrant
extends BreakableProp

# One authored fixture for Maple Bay, Motorway and future play mats.
func _init() -> void:
	kind="hydrant"
	radius=.3

func _ready() -> void:
	super._ready()
	build_art(self)
	var collision: CollisionShape3D=get_node("CollisionShape3D")
	spawn_shape=collision.shape
	spawn_offset=collision.position
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass=spawn_offset
	finish_setup()

static func build_art(parent: Node3D, at: Vector3=Vector3.ZERO) -> void:
	TownProps.cylinder(parent,at+Vector3.UP*.5,.25,1,Color("dd6950"))
	TownProps.ball(parent,at+Vector3.UP,Vector3(.6,.4,.6),Color("f0bd69"))
	TownProps.box(parent,at+Vector3(0,.65,0),Vector3(.9,.23,.25),Color("dd6950"))

static func spawn(parent: Node3D, owner_game: Node3D, at: Vector3) -> FireHydrant:
	var fixture: FireHydrant=load("res://scenes/fire_hydrant.tscn").instantiate()
	fixture.game=owner_game
	fixture.position=parent.to_local(at)
	parent.add_child(fixture)
	return fixture
