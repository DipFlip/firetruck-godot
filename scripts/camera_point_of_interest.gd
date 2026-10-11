class_name CameraPointOfInterest
extends Node3D

# Place these under the level or a moving toy. The camera keeps their bounds
# and the truck in view; radii control how gradually attention comes and goes.
@export var half_extents:=Vector3(2,2,2)
@export var full_radius:=12.0
@export var release_radius:=28.0
@export var enabled:=true
var active_when: Callable
var weight:=0.0
var engagement_left:=0.0

func _ready() -> void:
	var ancestor:=get_parent()
	while ancestor:
		if ancestor.has_method("register_camera_point"):
			ancestor.register_camera_point(self)
			return
		ancestor=ancestor.get_parent()

func engage(seconds: float=2.4) -> void:
	engagement_left=maxf(engagement_left,seconds)

func update_weight(truck_position: Vector3, dt: float) -> void:
	engagement_left=maxf(0,engagement_left-dt)
	var target:=0.0
	if enabled and is_visible_in_tree() and (not active_when.is_valid() or active_when.call()):
		target=1-smoothstep(full_radius,release_radius,truck_position.distance_to(global_position))
		if engagement_left>0: target=1.0
	weight=lerpf(weight,target,1-exp(-5*dt))
	if weight<.0001: weight=0.0

func reset() -> void:
	weight=0
	engagement_left=0

func world_bounds() -> PackedVector3Array:
	var result:=PackedVector3Array()
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]: result.append(global_transform*(half_extents*Vector3(x,y,z)))
	return result
