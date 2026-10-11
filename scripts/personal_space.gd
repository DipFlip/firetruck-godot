class_name PersonalSpace
extends Node3D

var enabled:=true
var radius:=.75
const REACH:=2.0

static func protect(actor: Node3D, truck: RigidBody3D, clearance: float=.75) -> PersonalSpace:
	var field:=PersonalSpace.new()
	field.name="PersonalSpace"
	field.radius=clearance
	actor.add_child(field)
	truck.personal_spaces.append(field)
	return field

func repel(state: PhysicsDirectBodyState3D) -> void:
	if not enabled or not is_visible_in_tree() or not can_process(): return
	var pose:=state.transform
	if absf(pose.origin.y-global_position.y)>4.0: return
	# Measure from the actual oriented chassis, rather than reserving a long
	# camera-facing corridor. This also lets the truck pass closely sideways.
	var local:=pose.affine_inverse()*global_position
	var nearest:=Vector3(clampf(local.x,-1.1,1.1),0,clampf(local.z,-2.15,1.95))
	var away:=nearest-Vector3(local.x,0,local.z)
	var distance:=away.length()
	var clearance:=distance-radius
	if clearance>=REACH: return
	if distance<.001:
		# Only needed if a scene placement starts inside the chassis footprint.
		var side:=1.1-absf(local.x)
		var front:=local.z+2.15
		var rear:=1.95-local.z
		if side<minf(front,rear):
			away=Vector3(-1 if local.x>=0 else 1,0,0)
			clearance=-radius-side
		elif front<rear:
			away=Vector3.BACK
			clearance=-radius-front
		else:
			away=Vector3.FORWARD
			clearance=-radius-rear
	else: away/=distance
	var normal:=pose.basis*away
	normal.y=0
	normal=normal.normalized()
	var velocity:=state.linear_velocity
	var inward:=maxf(0,-velocity.dot(normal))
	var weight:=1-smoothstep(0,REACH,clearance)
	# A damped spring: pressure builds progressively and only brakes movement
	# toward the character. Tangential movement is free to slide around them.
	velocity+=normal*(40+inward*20)*weight*state.step
	if clearance<0:
		# Compact inner limit prevents tunnelling at exceptional speeds. Normal
		# approaches settle in the spring before ever reaching this limit.
		pose.origin-=normal*clearance
		state.transform=pose
		velocity-=normal*minf(0,velocity.dot(normal))
	state.linear_velocity=velocity
