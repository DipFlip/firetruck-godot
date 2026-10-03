class_name BreakableProp
extends RigidBody3D

@export var impact_speed := 5.0
@export var respawn_seconds := 10.0
var game: Node3D
var kind := "prop"
var radius := .5
var home: Transform3D:
	set(value):
		home=value
		_cache_sweep()
var meshes: Array[GeometryInstance3D] = []
var loose := false
var age := 0.0
var appearing := false
var protected_cat_tree := false
var spawn_shape: Shape3D
var spawn_offset := Vector3.ZERO
var sweep_inverse:=Transform3D.IDENTITY
var sweep_basis_inverse:=Basis.IDENTITY
var sweep_half:=Vector3.ZERO
var sweep_radius:=0.0

func _ready() -> void:
	freeze=true
	freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
	collision_layer=1
	collision_mask=19
	continuous_cd=true
	linear_damp=.55
	angular_damp=.9
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	var mat:=PhysicsMaterial.new()
	mat.friction=.7
	mat.bounce=.14
	physics_material_override=mat
	process_physics_priority=-20

func finish_setup() -> void:
	home=global_transform
	_collect_meshes(self)

func _cache_sweep() -> void:
	if not spawn_shape: return
	sweep_inverse=home.affine_inverse()
	sweep_basis_inverse=home.basis.inverse()
	sweep_half=(spawn_shape as BoxShape3D).size*.5+Vector3(.84,0,.84)
	sweep_radius=Vector2(sweep_half.x,sweep_half.z).length()+1.1

func _collect_meshes(node: Node) -> void:
	if node is GeometryInstance3D: meshes.append(node)
	for child in node.get_children(): _collect_meshes(child)

func _opacity(value: float) -> void:
	for mesh in meshes: mesh.transparency=1-value

func knock(velocity: Vector3) -> bool:
	var planar:=Vector3(velocity.x,0,velocity.z)
	if loose or planar.length()<impact_speed or (protected_cat_tree and not game.cat_rescued): return false
	loose=true
	game.sounds.prop_impact(kind,global_position,planar.length())
	appearing=false
	age=0
	freeze=false
	sleeping=false
	linear_velocity=planar*.58+Vector3.UP*.65
	angular_velocity=Vector3.UP.cross(planar.normalized())*minf(4,planar.length()*.28)
	return true

func _physics_process(dt: float) -> void:
	if game.paused:
		if loose and not freeze: freeze=true
		return
	if loose:
		if freeze and age<respawn_seconds: freeze=false
		age+=dt
		if age>respawn_seconds-2: _opacity(clampf((respawn_seconds-age)/2,0,1))
		if age>=respawn_seconds:
			freeze=true
			collision_layer=0
			collision_mask=0
			if not _home_clear(): return
			global_transform=home
			reset_physics_interpolation()
			linear_velocity=Vector3.ZERO
			angular_velocity=Vector3.ZERO
			loose=false
			appearing=true
			age=0
			collision_layer=1
			collision_mask=19
		return
	if appearing:
		age+=dt
		_opacity(minf(1,age))
		if age>=1: appearing=false
	# Sweep the truck's leading supports before the rigid solver stops it on
	# the anchored prop. A glancing scrape uses its closing speed, not speed alone.
	var velocity: Vector3=game.truck.linear_velocity
	var direction:=Vector3(velocity.x,0,velocity.z)
	var speed:=direction.length()
	if speed<impact_speed: return
	var delta:=Vector2(game.truck.global_position.x-home.origin.x,game.truck.global_position.z-home.origin.z)
	if delta.length_squared()>pow(sweep_radius+speed*dt+.10,2): return
	direction/=speed
	for z in [-1.1,1.1]:
		var start: Vector3=game.truck.global_position+game.truck.global_basis*Vector3(0,0,z)
		if start.y>global_position.y+2.1 or start.y<global_position.y-.3: continue
		var local_start:=sweep_inverse*start-spawn_offset
		var local_direction:=sweep_basis_inverse*direction
		var half:=sweep_half
		var entry:=-INF
		var leave:=INF
		var normal_speed:=speed
		for axis in [0,2]:
			if absf(local_direction[axis])<.0001:
				if absf(local_start[axis])>half[axis]: leave=-INF
				continue
			var t1: float=(-half[axis]-local_start[axis])/local_direction[axis]
			var t2: float=(half[axis]-local_start[axis])/local_direction[axis]
			var near:=minf(t1,t2)
			if near>entry:
				entry=near
				normal_speed=absf(local_direction[axis])*speed
			leave=minf(leave,maxf(t1,t2))
		if entry>leave or leave<0 or entry>speed*dt+.10 or normal_speed<impact_speed: continue
		if entry<0 and local_start.dot(local_direction)>0: continue
		if knock(velocity):
			var retention:=clampf(1-mass/(game.truck.mass+mass)*.32,.78,.98)
			game.truck.linear_velocity.x*=retention
			game.truck.linear_velocity.z*=retention
			game.truck.bump.emit(.12)
			break

func _home_clear() -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=spawn_shape
	query.transform=home.translated_local(spawn_offset)
	query.collision_mask=18 # Traffic and the tight NPC boundaries.
	query.exclude=[get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	# Truck is layer 1 alongside the ground, so check its two supports explicitly.
	for z in [-1.1,1.1]:
		var p: Vector3=game.truck.global_position+game.truck.global_basis*Vector3(0,0,z)
		var local:=home.affine_inverse()*p-spawn_offset
		var half: Vector3=(spawn_shape as BoxShape3D).size*.5+Vector3(1.1,1.0,1.1)
		if absf(local.x)<half.x and absf(local.y)<half.y and absf(local.z)<half.z: return false
	for walker in game.life.walkers:
		if walker.node.global_position.distance_to(home.origin)<radius+1: return false
	return true
