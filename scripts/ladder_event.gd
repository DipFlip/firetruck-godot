class_name LadderEvent
extends Area3D

# Reusable receiver for the ladder tip. Attach to a rescue target, connect
# activated, and provide an optional availability callback for mission rules.
signal activated(engine: FireEngine)
@export var enabled := true
@export var reach_radius := 0.7
@export var dock_offset := Vector3(0,0.06,0)
var consumed := false
var availability: Callable

func _ready() -> void:
	collision_layer=4
	collision_mask=0
	monitoring=false
	monitorable=true
	add_to_group("ladder_events")
	var shape:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=reach_radius
	shape.shape=sphere
	shape.position=Vector3.UP*.45
	add_child(shape)

func is_available() -> bool:
	return enabled and not consumed and (not availability.is_valid() or availability.call())

func dock_position() -> Vector3:
	return global_position+global_basis*dock_offset

func try_activate(engine: FireEngine) -> bool:
	if not is_available(): return false
	consumed=true
	activated.emit(engine)
	return true
