class_name CameraFraming
extends RefCounted

var points: Array[CameraPointOfInterest]=[]
var active: Array[CameraPointOfInterest]=[]

func register(point: CameraPointOfInterest) -> void:
	if not points.has(point): points.append(point)

func add(parent: Node3D, label: String, at: Vector3, extents: Vector3, when: Callable, full: float=12, release: float=28) -> CameraPointOfInterest:
	var point:=CameraPointOfInterest.new()
	point.name=label+"CameraInterest"
	point.position=at
	point.half_extents=extents
	point.active_when=when
	point.full_radius=full
	point.release_radius=release
	parent.add_child(point)
	return point

func focus(base: Vector3, truck_position: Vector3, dt: float) -> Vector3:
	active.clear()
	var centre:=base
	var total:=1.0
	for point in points:
		if not is_instance_valid(point): continue
		point.update_weight(truck_position,dt)
		if point.weight<=0: continue
		active.append(point)
		var influence:=point.weight*.65
		centre+=point.global_position*influence
		total+=influence
	return centre/total

func fit(camera: Camera3D, truck_transform: Transform3D, view: Vector2, minimum: float) -> float:
	# Measure the actual projection, so the same bounds work in landscape,
	# portrait and with either orthographic aspect mode or camera orientation.
	var frame:=Rect2(camera.unproject_position(truck_transform.origin),Vector2.ZERO)
	for x in [-1.45,1.45]:
		for y in [-.85,2.7]:
			for z in [-2.7,2.7]: frame=frame.expand(camera.unproject_position(truck_transform*Vector3(x,y,z)))
	for point in active:
		for corner in point.world_bounds():
			# Blend the bounds too, avoiding a lens jump at the influence radius.
			frame=frame.expand(camera.unproject_position(truck_transform.origin.lerp(corner,point.weight)))
	var centre:=view*.5
	# v_offset translates the projected focus; its effect is measured directly.
	centre=camera.unproject_position(camera.global_position-camera.global_basis.z*20)
	var safe:=Rect2(Vector2(24,90),view-Vector2(48,118))
	var ratio:=maxf((centre.x-frame.position.x)/maxf(1,centre.x-safe.position.x),(frame.end.x-centre.x)/maxf(1,safe.end.x-centre.x))
	ratio=maxf(ratio,(centre.y-frame.position.y)/maxf(1,centre.y-safe.position.y))
	ratio=maxf(ratio,(frame.end.y-centre.y)/maxf(1,safe.end.y-centre.y))
	return maxf(minimum,camera.size*ratio)

func screen_rect(camera: Camera3D, truck_position: Vector3) -> Rect2:
	var frame:=Rect2()
	var first:=true
	for point in active:
		if point.weight<.15: continue
		for corner in point.world_bounds():
			var pixel:=camera.unproject_position(truck_position.lerp(corner,point.weight))
			if first: frame=Rect2(pixel,Vector2.ZERO); first=false
			else: frame=frame.expand(pixel)
	return frame

func reset() -> void:
	active.clear()
	for point in points:
		if is_instance_valid(point): point.reset()
