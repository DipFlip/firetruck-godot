extends SceneTree
var game: Node3D
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.truck.use_automation=true
	game.truck.position=Vector3(-70,1,70)
	game.truck.freeze=true
	await frames(3)
	var life: TownLife=game.life
	var solo:=true
	for i in life.ground_birds.size():
		for j in range(i+1,life.ground_birds.size()):
			solo=solo and life.ground_birds[i].home.distance_to(life.ground_birds[j].home)>7
	check(solo and life.ground_birds.size()==16,"Ground birds occupy separated, individual foraging patches")
	var compact:=true
	for bird in life.ground_birds:
		compact=compact and bird.open==0 and bird.home.y>=.01 and bird.home.y<.2
		for feather in bird.feathers:
			compact=compact and feather.scale.x<.1 and feather.scale.z>.25 and absf(feather.position.x)<.02
	check(compact,"Ground birds stand on the surface with compact wings along their sides")
	var pool_clear:=true
	for walker in life.walkers:
		for p in walker.path: pool_clear=pool_clear and life._pool_safe(p)
	check(pool_clear,"Every pedestrian waypoint stays well clear of the pool")
	var pedestrian: Node3D=life.walkers[4].node
	pedestrian.position=TownLayout.POOL+Vector3(4,.16,2.5)
	life._keep_pool_clear(pedestrian)
	check(life._pool_safe(pedestrian.position),"Pedestrian dodges are kept away from the pool rim")
	var bird: Dictionary=life.ground_birds[0]
	# Inspect the pecking pose with the bird in view, while the truck stays
	# far enough away to leave it undisturbed. Off-screen poses are now culled.
	game.set_process(false)
	game.camera.position=bird.home+game.camera_offset
	game.camera.look_at(bird.home)
	var origin: Vector3=bird.node.position
	var wandered:=0.0
	var beak_high: float=(bird.head.global_transform*Vector3(0,.005,-.175)).y
	var beak_low:=beak_high
	var walk:=false
	var peck:=false
	var safe:=true
	var initial_nodes:=life.get_child_count()
	for i in 650:
		await frames(1)
		wandered=maxf(wandered,Vector2(bird.node.position.x-origin.x,bird.node.position.z-origin.z).length())
		walk=walk or bird.forage=="walk"
		peck=peck or bird.forage=="peck"
		beak_low=minf(beak_low,(bird.head.global_transform*Vector3(0,.005,-.175)).y)
		safe=safe and bird.node.position.y>=bird.ground_y-.001 and bird.node.position.distance_to(bird.home)<1.5 and bird.open==0
	check(walk and peck and wandered>.3,"An undisturbed bird walks, pauses and pecks within its patch")
	check(beak_high-beak_low>.15,"The complete head lowers its beak toward the ground while pecking")
	check(safe and life.get_child_count()==initial_nodes,"Foraging stays grounded and uses existing animation nodes")
	game.paused=true
	var paused_position: Vector3=bird.node.position
	var paused_head: Transform3D=bird.head.transform
	await frames(30)
	check(bird.node.position==paused_position and bird.head.transform.is_equal_approx(paused_head),"Pause freezes walking and pecking")
	game.paused=false
	game.truck.position=bird.node.position+Vector3(0,1,8.5)
	game.truck.linear_velocity=Vector3.ZERO
	await frames(2)
	check(bird.mode=="flee","Birds take off before the truck reaches the old close-range trigger")
	await frames(30)
	check(bird.node.position.y>2 and bird.open>.95,"Takeoff quickly gains height and unfolds the wings")
	await frames(150)
	var flight_start: Vector3=bird.node.position
	await frames(90)
	check(bird.node.position.distance_to(flight_start)>3 and bird.node.position.y>13,"Fleeing birds keep flying above roofs and canopies instead of hovering inside scenery")
	game.truck.position=Vector3(-70,1,70)
	await frames(480)
	check(bird.mode=="ground" and bird.node.position.distance_to(bird.home)<1.5 and bird.open<.01,"Birds land with folded wings and resume their own foraging patch")
	game.truck.position=bird.node.position+Vector3(0,1,15)
	game.truck.linear_velocity=Vector3(0,0,-15)
	await frames(2)
	check(bird.mode=="flee","Approaching at driving speed gives birds additional warning")
	game.queue_free()
	await process_frame
	await process_frame
	print("BIRD CHECKS: ","ALL PASS" if failures==0 else str(failures)+" failed")
	quit(0 if failures==0 else 1)
