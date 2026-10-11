extends SceneTree

var game: Node3D
var failures:=0
const TEST_POINT:=Vector3(-12,0,-52)

func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func gap(field: PersonalSpace) -> float:
	var local: Vector3=game.truck.global_transform.affine_inverse()*field.global_position
	var closest:=Vector2(clampf(local.x,-1.1,1.1),clampf(local.z,-2.15,1.95))
	return closest.distance_to(Vector2(local.x,local.z))-field.radius
func steer(desired: Vector3) -> void:
	var forward: Vector3=-game.camera.global_basis.z
	forward.y=0
	game.truck.automated_drive=Vector2(desired.dot(game.camera.global_basis.x),-desired.dot(forward.normalized()))
func place(field: PersonalSpace, outward: Vector3, distance: float=10, speed: float=0) -> void:
	game.truck.automated_drive=Vector2.ZERO
	game.truck.global_position=field.global_position+outward*distance+Vector3.UP*.85
	game.truck.heading=atan2(outward.x,outward.z)
	game.truck.rotation.y=game.truck.heading
	game.truck.linear_velocity=-outward*speed
	game.truck.reset_physics_interpolation()
func drive_at(field: PersonalSpace, outward: Vector3, label: String) -> void:
	place(field,outward)
	var min_gap:=INF
	var max_step:=0.0
	var max_slowdown:=0.0
	var previous_speed:=0.0
	for i in 180:
		steer(-outward)
		var before: Vector3=game.truck.global_position
		await frames(1)
		min_gap=minf(min_gap,gap(field))
		max_step=maxf(max_step,(game.truck.global_position-before).length())
		var speed: float=Vector2(game.truck.linear_velocity.x,game.truck.linear_velocity.z).length()
		max_slowdown=maxf(max_slowdown,previous_speed-speed)
		previous_speed=speed
	check(min_gap>.1,label+" slows before the inner separation limit (gap "+str(snappedf(min_gap,.01))+")")
	check(gap(field)>.1 and previous_speed<.5,label+" settles in the soft field under held throttle")
	check(max_slowdown<3 and max_step<.4,label+" slows progressively without a hard impact or position jump (deceleration "+str(snappedf(max_slowdown,.01))+", step "+str(snappedf(max_step,.01))+")")
	check(game.truck.global_position.distance_to(field.global_position)<4.2,label+" allows a compact approach without the long southern extension")

func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer=0
	game.stage=4
	game.cat_rescued=true
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	for car in game.life.cars: car.node.freeze=true; car.node.position=Vector3(200,0,200)
	game.truck.use_automation=true
	# Isolate character clearance from incidental breakable scenery contacts.
	for prop in game.interactions.props: prop.collision_layer=0
	for field in game.truck.personal_spaces: field.enabled=false
	await frames(3)
	check(game.interactions.npc_guards.size()==4 and game.interactions.dog_guard!=null,"All quest neighbours and Biscuit have personal-space fields")
	var field: PersonalSpace=game.interactions.npc_guards[0]
	var actor: Node3D=field.get_parent()
	var home: Vector3=actor.global_position
	actor.global_position=TEST_POINT
	field.enabled=true
	for outward in [Vector3.BACK,Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT,Vector3(1,0,1).normalized()]:
		await drive_at(field,outward,"NPC approach "+str(outward))
	# A glancing approach must be able to slide past instead of hitting a wall.
	place(field,Vector3.RIGHT,2.5)
	game.truck.heading=0
	game.truck.rotation.y=0
	game.truck.linear_velocity=Vector3(0,0,-8)
	var start: Vector3=game.truck.position
	var min_gap:=INF
	for i in 80:
		steer(Vector3.FORWARD)
		await frames(1)
		min_gap=minf(min_gap,gap(field))
	check(game.truck.position.z<start.z-8 and min_gap>=-.06,"Glancing movement slides freely past the NPC while preserving separation")
	place(field,Vector3.BACK,6,28)
	min_gap=INF
	for i in 60:
		await frames(1)
		min_gap=minf(min_gap,gap(field))
	check(min_gap>=-.06,"An unusually fast approach cannot tunnel through the NPC")
	# Fields follow their actors and don't depend on the camera direction.
	actor.global_position=TEST_POINT+Vector3.RIGHT*6
	game.camera.rotation.y+=PI
	await drive_at(field,Vector3.BACK,"Moved NPC with reversed camera")
	field.enabled=false
	actor.global_position=home
	var dog: PersonalSpace=game.interactions.dog_guard
	var dog_home: Vector3=game.town.dog.global_position
	game.dog_puddle.set_process(false)
	game.town.dog.global_position=TEST_POINT
	dog.enabled=true
	await drive_at(dog,Vector3.BACK,"Biscuit")
	check(game.truck.global_position.distance_to(dog.global_position)<9,"Biscuit remains within hose and mission interaction range")
	game.truck.automated_drive=Vector2.ZERO
	dog.get_parent().hide()
	place(dog,Vector3.BACK,4,12)
	for i in 60:
		steer(Vector3.FORWARD)
		await frames(1)
	check(game.truck.position.z<TEST_POINT.z,"Hidden actors leave no invisible field behind")
	dog.get_parent().show()
	dog.process_mode=Node.PROCESS_MODE_DISABLED
	place(dog,Vector3.BACK,4,12)
	for i in 60:
		steer(Vector3.FORWARD)
		await frames(1)
	check(game.truck.position.z<TEST_POINT.z,"An inactive map's fields cannot repel the truck")
	dog.process_mode=Node.PROCESS_MODE_INHERIT
	game.town.dog.global_position=dog_home
	dog.enabled=false
	# Keep manual NPC interaction reachable with the smaller field.
	field.enabled=true
	place(field,Vector3.BACK,3.5)
	await frames(2)
	check(game._nearest_npc()==0,"Space can still reach the quest neighbour from the soft boundary")
	check(field.get_class()=="Node3D" and field.get_child_count()==0,"NPC fields contain no rigid colliders or camera-facing additions")
	var race: ToyRaceTrack=game.travel.race
	for person in race.people:
		check(person.get_node_or_null("PersonalSpace") is PersonalSpace,"Motorway mission NPC "+person.name+" has the same field")
	game.queue_free()
	await process_frame
	await process_frame
	print("VISIBILITY GUARD CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
