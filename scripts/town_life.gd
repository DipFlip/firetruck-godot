class_name TownLife
extends Node3D

var game: Node3D
var cars: Array[Dictionary]=[]
var walkers: Array[Dictionary]=[]
var birds: Array[Dictionary]=[]
var time:=0.0
var ground_birds: Array[Dictionary]=[]
const BIRD_FLEE_RADIUS:=9.5
var honk_stream: AudioStreamWAV

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	honk_stream=load("res://assets/audio/town/honk_0.wav")
	# Lanes circulate around separate blocks, leaving the centre of junctions clear.
	_car([Vector3(1.8,0,28),Vector3(1.8,0,34.2),Vector3(34.2,0,34.2),Vector3(34.2,0,1.8),Vector3(1.8,0,1.8)],Color("e5bd72"),0)
	_car([Vector3(-34.2,0,-15),Vector3(-34.2,0,-1.8),Vector3(-1.8,0,-1.8),Vector3(-1.8,0,-34.2),Vector3(-34.2,0,-34.2)],Color("91afb4"),1)
	_car([Vector3(1.8,0,-12),Vector3(1.8,0,-1.8),Vector3(34.2,0,-1.8),Vector3(34.2,0,-34.2),Vector3(1.8,0,-34.2)],Color("c78e83"),2)
	var paths: Array[Array]=[
		[Vector3(5.0,.16,22),Vector3(5.0,.16,31),Vector3(30.7,.16,31),Vector3(30.7,.16,5),Vector3(5.0,.16,5)],
		[Vector3(-5,.16,-9),Vector3(-5,.16,-31),Vector3(-31,.16,-31),Vector3(-31,.16,-5),Vector3(-5,.16,-5)],
		[Vector3(41,.16,-8),Vector3(41,.16,-31),Vector3(58,.16,-31),Vector3(58,.16,-5),Vector3(41,.16,-5)],
		[Vector3(-5,.16,24),Vector3(-5,.16,5),Vector3(-31,.16,5),Vector3(-31,.16,31),Vector3(-5,.16,31)],
		[Vector3(5,.16,43),Vector3(5,.16,65),Vector3(30,.16,65),Vector3(30,.16,41),Vector3(5,.16,41)],
		[Vector3(-41,.16,-9),Vector3(-41,.16,-31),Vector3(-59,.16,-31),Vector3(-59,.16,-5),Vector3(-41,.16,-5)]]
	for i in paths.size():
		var person:=TownProps.person(self,paths[i][0],[Color("819a83"),Color("d4a17a"),Color("8d9db6"),Color("c59099"),Color("dcbe77"),Color("9b9b7a")][i])
		person.scale=Vector3.ONE*.85
		var legs: Array[Node3D]=[]
		for side in [-1,1]:
			var pivot:=Node3D.new()
			person.add_child(pivot)
			pivot.position=Vector3(side*.22,.72,0)
			# Reparent each matching trouser and shoe under a hip joint.
			for child in person.get_children():
				if child is MeshInstance3D and absf(child.position.x-side*.22)<.01 and child.position.y<.75:
					child.reparent(pivot)
			legs.append(pivot)
		walkers.append({"node":person,"path":paths[i],"next":1,"speed":.95+i*.06,"phase":i*1.7,"legs":legs,"hop":1.0,"from":person.position,"to":person.position,"cooldown":0.0})
	for i in 9:
		var bird:=_bird(i)
		bird.center=Vector3(-15,14.5,6) if i<5 else Vector3(43,14.5,-16)
		bird.radius=12.0+i*.6
		birds.append(bird)
	# Individual foraging patches, rather than paired birds at each stop.
	var perches: Array[Vector3]=[Vector3(-8,0,21),Vector3(8,0,29),Vector3(8,0,-7),Vector3(28,0,-27),Vector3(-9,0,-25),Vector3(-29,0,-6),Vector3(29,0,29),Vector3(-28,0,29),Vector3(43,0,-8),Vector3(58,0,8),Vector3(8,0,45),Vector3(29,0,56),Vector3(-41,0,28),Vector3(-57,0,-7),Vector3(-29,0,-48),Vector3(-8,0,57)]
	for i in perches.size():
		var bird:=_bird(i+9)
		bird.node.scale=Vector3.ONE*1.6
		bird.node.position=perches[i]
		bird.home=perches[i]
		bird.mode="ground"
		bird.age=0.0
		bird.escape=Vector3.ZERO
		bird.from=perches[i]
		bird.terrain_ready=false
		bird.forage="idle"
		bird.forage_age=0.0
		bird.wait=1.0+fmod(i*.71,2.0)
		bird.goal=perches[i]
		bird.ground_y=0.0
		bird.visits=i
		bird.open=0.0
		_pose_bird(bird,0,0,0,0)
		ground_birds.append(bird)

func _bird(index: int) -> Dictionary:
	var bird:=Node3D.new()
	add_child(bird)
	var body:=Node3D.new()
	bird.add_child(body)
	TownProps.ball(body,Vector3(0,.17,.035),Vector3(.22,.26,.37),Color("677a79"))
	var tail:=TownProps.ball(body,Vector3(0,.15,.23),Vector3(.10,.065,.20),Color("52676d"))
	tail.rotation.x=.25
	# Beak and eyes share the neck pivot, so the complete head pecks together.
	var head:=Node3D.new()
	body.add_child(head)
	head.position=Vector3(0,.20,-.10)
	TownProps.ball(head,Vector3(0,.03,-.065),Vector3(.18,.18,.21),Color("ece5cc"))
	TownProps.box(head,Vector3(0,.005,-.175),Vector3(.055,.045,.10),Color("d7a55d"))
	for side in [-1,1]:
		TownProps.ball(head,Vector3(side*.076,.055,-.125),Vector3(.032,.032,.032),Color("294754"))
	var legs: Array[Node3D]=[]
	for side in [-1,1]:
		var leg:=Node3D.new()
		bird.add_child(leg)
		leg.position=Vector3(side*.055,.06,.035)
		TownProps.box(leg,Vector3.ZERO,Vector3(.024,.10,.024),Color("d7a55d"))
		TownProps.box(leg,Vector3(0,-.05,-.025),Vector3(.036,.02,.075),Color("d7a55d"))
		legs.append(leg)
	var wings: Array[Node3D]=[]
	var feathers: Array[MeshInstance3D]=[]
	for side in [-1,1]:
		var wing:=Node3D.new()
		body.add_child(wing)
		wing.position=Vector3(side*.105,.18,0)
		feathers.append(TownProps.ball(wing,Vector3(side*.20,0,0),Vector3(.44,.045,.20),Color("d4d8c5")))
		wings.append(wing)
	return {"node":bird,"body":body,"head":head,"legs":legs,"wings":wings,"feathers":feathers,"phase":index*.48,"open":1.0}

func _pose_bird(bird: Dictionary, open: float, peck: float, step: float, flap: float) -> void:
	bird.body.rotation.x=.12*open-.10*peck
	bird.head.rotation.x=-.8*peck
	bird.head.position.y=.20-.03*peck
	for i in 2:
		var side: float=-1 if i==0 else 1
		# A folded feather lies along the flank, rather than rotating a wide
		# flight wing vertically. Unfold the same mesh smoothly on takeoff.
		bird.feathers[i].position=Vector3(side*.01,-.02,.045).lerp(Vector3(side*.20,0,0),open)
		bird.feathers[i].scale=Vector3(.065,.18,.31).lerp(Vector3(.44,.045,.20),open)
		bird.wings[i].rotation.z=-side*sin(flap)*.8*open
		bird.legs[i].rotation.x=lerpf(step*side,-1.1,open)
		bird.legs[i].position.y=lerpf(.06,.13,open)

func _car(path: Array, color: Color, index: int) -> void:
	var body:=RigidBody3D.new()
	body.name="NeighbourCar%d" % index
	body.collision_layer=2
	body.collision_mask=19
	body.mass=1.0
	body.continuous_cd=true
	body.can_sleep=false
	body.linear_damp=.6
	body.angular_damp=2.5
	body.axis_lock_angular_x=true
	body.axis_lock_angular_z=true
	var material:=PhysicsMaterial.new()
	material.friction=.06
	material.bounce=.04
	body.physics_material_override=material
	add_child(body)
	body.position=path[0]+Vector3.UP*.12
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(1.65,1.45,3.0)
	collision.shape=shape
	collision.position.y=.725
	body.add_child(collision)
	# The box settles about 1 cm into contact; lift the complete art slightly
	# so 34 cm tires sit on the road rather than cutting through it.
	var art:=Node3D.new()
	art.name="CarArt"
	body.add_child(art)
	art.position.y=.045
	TownProps.box(art,Vector3(0,.65,0),Vector3(1.7,.62,3.0),color)
	TownProps.box(art,Vector3(0,1.18,.1),Vector3(1.4,.75,1.65),color)
	TownProps.box(art,Vector3(0,1.22,-.75),Vector3(1.25,.46,.07),Color("577884"))
	TownProps.box(art,Vector3(0,1.22,.94),Vector3(1.25,.4,.06),Color("577884"))
	for side in [-1,1]:
		TownProps.box(art,Vector3(side*.713,1.22,.1),Vector3(.035,.42,1.36),Color("577884"))
		TownProps.box(art,Vector3(side*.715,1.22,.1),Vector3(.04,.5,.08),color)
		TownProps.box(art,Vector3(side*.54,.7,-1.5),Vector3(.38,.2,.07),Color("fff0c5"))
		TownProps.box(art,Vector3(side*.55,.7,1.5),Vector3(.28,.15,.07),Color("b15d4f"))
	TownProps.box(art,Vector3(0,.46,-1.53),Vector3(1.4,.13,.13),Color("cfceb7"))
	var wheels: Array[Node3D]=[]
	for side in [-1,1]:
		for z in [-.95,.98]:
			var wheel:=Node3D.new()
			art.add_child(wheel)
			wheel.position=Vector3(side*.82,.32,z)
			var tire:=TownProps.cylinder(wheel,Vector3.ZERO,.34,.19,Color("435152"))
			tire.rotation.z=PI/2
			var hub:=TownProps.box(wheel,Vector3(side*.11,0,0),Vector3(.035,.36,.07),Color("d7d1b9"))
			wheels.append(wheel)
	var honk:=AudioStreamPlayer3D.new()
	honk.stream=honk_stream
	honk.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	honk.volume_db=-16
	honk.max_distance=35
	honk.unit_size=8
	body.add_child(honk)
	cars.append({"wet_age":10.0,"wash_time":0.0,"wash_cooldown":0.0,"honk":honk,"honk_count":0,"node":body,"path":path,"next":1,"speed":0.0,"cruise":4.0+index*.4,"wheels":wheels,"coast":0.0,"stalled":0.0,"recovery":-1.0,"fade_in":1.0,"last_position":body.position,"progress_clock":0.0})

func _physics_process(dt: float) -> void:
	for car in cars:
		car.node.freeze=game.paused
		car.honk.stream_paused=game.paused
	if game.paused: return
	time+=dt
	for car in cars:
		var body: RigidBody3D=car.node
		car.wet_age+=dt
		car.wash_cooldown=maxf(0,car.wash_cooldown-dt)
		if car.wet_age<2.5:
			if car.wash_time>=1.0 and car.wash_cooldown<=0:
				car.wash_time=0.0
				car.wash_cooldown=8.0
				car.honk_count+=1
				game.sounds.play("clean",body.global_position,1.0,.35)
				game.sounds.play("honk",body.global_position,.8,1.4)
				game.rewards.sparkle_burst(body.global_position+Vector3.UP*1.25,12,1.4)
		else: car.wash_time=maxf(0,car.wash_time-dt*.5)
		if _recover_traffic(car,dt): continue
		var target: Vector3=car.path[car.next]+Vector3.UP*.12
		var direction:=target-body.position
		direction.y=0
		if direction.length()<.8:
			car.next=(car.next+1)%car.path.size()
			direction=car.path[car.next]-body.position
			direction.y=0
		direction=direction.normalized()
		var yield_now:=false
		var to_truck: Vector3=game.truck.global_position-body.position
		if to_truck.length()<7 and to_truck.normalized().dot(direction)>.25: yield_now=true
		# Sloped street decks are drivable ground, not stopped traffic. Keep their
		# physical contacts, but omit them from the forward obstacle sensor.
		var obstacles_exclude: Array[RID]=[body.get_rid()]
		for ramp in game.ramps.ramps: obstacles_exclude.append(ramp.get_rid())
		var query:=PhysicsRayQueryParameters3D.create(body.position+Vector3.UP*.7,body.position+Vector3.UP*.7+direction*4,3,obstacles_exclude)
		if get_world_3d().direct_space_state.intersect_ray(query): yield_now=true
		car.coast=maxf(0,car.coast-dt)
		var planar:=Vector3(body.linear_velocity.x,0,body.linear_velocity.z)
		car.speed=planar.length()
		# Tire grip remains active during a bump. Damp across the axle much more
		# strongly than along the wheel direction; cars are still pushable.
		var lateral:=body.global_basis.x
		var slip:=planar.dot(lateral)
		if absf(body.position.y)<.65:
			body.apply_central_force(-lateral*slip*body.mass*7.5)
			if car.coast>0: body.apply_central_force(-planar*body.mass*.9)
		# Briefly accept forward impact momentum before resuming lane steering.
		if car.coast<=0:
			var desired: Vector3=direction*(0.0 if yield_now else car.cruise)
			var force: Vector3=((desired-planar)*2.8+desired*body.linear_damp)*body.mass
			body.apply_central_force(force.limit_length(body.mass*8))
			var error:=wrapf(atan2(-direction.x,-direction.z)-body.rotation.y,-PI,PI)
			body.apply_torque(Vector3.UP*(error*10-body.angular_velocity.y*3.5))
		if not TownProps.near_view(game.camera,body.position,4): continue
		for wheel in car.wheels:
			wheel.rotation.x-=car.speed*dt/.34
			# Raised intersection paint/paving is query-only, so also keep the
			# visible tires above it without changing the car's rigid collider.
			wheel.position.y=.32
			var center: Vector3=wheel.global_position
			var support:=PhysicsRayQueryParameters3D.create(center+Vector3.UP*.5,center+Vector3.DOWN,9,[body.get_rid(),game.truck.get_rid()])
			var road:=get_world_3d().direct_space_state.intersect_ray(support)
			# A tire reaches a raised crossing before its hub does. Include its
			# leading contact patch so the first frame at an edge stays clear.
			var leading:=Vector3(body.linear_velocity.x,0,body.linear_velocity.z).normalized()*.36
			support.from+=leading
			support.to+=leading
			var next_road:=get_world_3d().direct_space_state.intersect_ray(support)
			if next_road and next_road.normal.y>.5 and (road.is_empty() or next_road.position.y>road.position.y): road=next_road
			if road and road.normal.y>.5:
				var clearance: Vector3=wheel.get_parent().to_local(Vector3(center.x,road.position.y+.355,center.z))
				wheel.position.y=maxf(.32,clearance.y)
	for walker in walkers:
		var person: Node3D=walker.node
		var target: Vector3=walker.path[walker.next]
		var delta:=target-person.position
		delta.y=0
		if delta.length()<.25:
			walker.next=(walker.next+1)%walker.path.size()
			continue
		walker.cooldown=maxf(0,walker.cooldown-dt)
		var danger:=_threat(person.global_position)
		if not danger.is_empty() and walker.cooldown<=0:
			_begin_dodge(walker,danger)
		if walker.hop<1:
			walker.hop=minf(1,walker.hop+dt/.48)
			person.position=walker.from.lerp(walker.to,smoothstep(0,1,walker.hop))+Vector3.UP*sin(walker.hop*PI)*.75
			walker.legs[0].rotation.x=-.55*sin(walker.hop*PI)
			walker.legs[1].rotation.x=.35*sin(walker.hop*PI)
			person.get_node("ArmLeft").rotation.z=-.85*sin(walker.hop*PI)
			person.get_node("ArmRight").rotation.z=.85*sin(walker.hop*PI)
			_keep_clear(person)
			continue
		var stop: bool=person.global_position.distance_to(game.truck.global_position)<4.5 or walker.cooldown>.3
		if not stop:
			person.position+=delta.normalized()*walker.speed*dt
			person.rotation.y=lerp_angle(person.rotation.y,atan2(-delta.x,-delta.z),1-exp(-6*dt))
			walker.phase+=dt*6
		var step: float=sin(walker.phase)*(.45 if not stop else .03)
		walker.legs[0].rotation.x=step
		walker.legs[1].rotation.x=-step
		person.get_node("ArmLeft").rotation.x=-step
		person.get_node("ArmRight").rotation.x=step
		person.get_node("ArmLeft").rotation.z=-.12
		person.get_node("ArmRight").rotation.z=.12
		person.position.y=.16+absf(cos(walker.phase))*(.035 if not stop else .0)
		_keep_clear(person)
	for bird in birds:
		var a: float=time*.23+bird.phase
		var p: Vector3=bird.center+Vector3(cos(a)*bird.radius,sin(time*.7+bird.phase)*1.2,sin(a)*bird.radius*.65)
		bird.node.position=p
		bird.node.rotation.y=atan2(sin(a),-cos(a)*.65)
		if TownProps.near_view(game.camera,p,2): _pose_bird(bird,1,0,0,time*13+bird.phase)
	_update_ground_birds(dt)

func _update_ground_birds(dt: float) -> void:
	var truck: Vector3=game.truck.global_position
	var ahead: Vector3=truck+game.truck.linear_velocity*.65
	for bird in ground_birds:
		bird.age+=dt
		var node: Node3D=bird.node
		if not bird.terrain_ready:
			bird.home=_bird_floor(bird.home)
			node.position=bird.home
			bird.ground_y=bird.home.y
			bird.goal=bird.home
			bird.terrain_ready=true
		var danger:=minf(Vector2(node.position.x-truck.x,node.position.z-truck.z).length(),Vector2(node.position.x-ahead.x,node.position.z-ahead.z).length())<BIRD_FLEE_RADIUS
		if bird.mode!="flee" and danger:
			game.sounds.play("bird",node.global_position,.85,.35)
			bird.mode="flee"
			bird.age=0.0
			bird.from=node.position
			var away: Vector3=node.position-truck
			away.y=0
			if away.length()<.1: away=Vector3(cos(bird.phase),0,sin(bird.phase))
			bird.escape=node.position+away.normalized()*14
			bird.escape.x=clampf(bird.escape.x,-69,69)
			bird.escape.z=clampf(bird.escape.z,-69,69)
			bird.escape.y=15.0
		if bird.mode=="ground":
			_forage_bird(bird,dt)
		else:
			var folding: bool=bird.mode=="land" and bird.age>2.05
			bird.open=move_toward(bird.open,0.0 if folding else 1.0,dt*5)
			if TownProps.near_view(game.camera,node.position,2) or node.position.distance_to(truck)<18: _pose_bird(bird,bird.open,0,0,time*19+bird.phase)
			if bird.mode=="flee":
				var t: float=clampf(bird.age/2.1,0,1)
				node.position=bird.from.lerp(bird.escape,smoothstep(.30,1,t))
				node.position.y=lerpf(bird.from.y,bird.escape.y,smoothstep(0,.65,t))
				node.rotation.y=lerp_angle(node.rotation.y,atan2(bird.from.x-bird.escape.x,bird.from.z-bird.escape.z),1-exp(-8*dt))
				if t>=1:
					var orbit: float=(bird.age-2.1)*.75
					node.position=bird.escape+Vector3(sin(orbit)*4,sin(orbit*2)*.7,(1-cos(orbit))*4)
					node.rotation.y=atan2(-cos(orbit),-sin(orbit))
				if bird.age>5 and truck.distance_to(bird.home)>15 and ahead.distance_to(bird.home)>12:
					bird.mode="land"
					bird.from=node.position
					bird.age=0.0
			else:
				var t: float=clampf(bird.age/2.4,0,1)
				node.position=bird.from.lerp(bird.home,smoothstep(0,.55,t))
				node.position.y=lerpf(bird.from.y,bird.home.y,smoothstep(.45,1,t))
				node.rotation.y=lerp_angle(node.rotation.y,atan2(bird.from.x-bird.home.x,bird.from.z-bird.home.z),1-exp(-6*dt))
				if t>=1:
					bird.mode="ground"
					bird.age=0.0
					bird.forage="idle"
					bird.forage_age=0.0
					bird.wait=1.5+fmod(bird.phase,1.0)
					bird.ground_y=bird.home.y

func _bird_floor(point: Vector3) -> Vector3:
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point+Vector3.DOWN*2,9,[game.truck.get_rid()])
	var floor_hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit and floor_hit.normal.y>.7: point.y=floor_hit.position.y+.012
	return point

func _forage_bird(bird: Dictionary, dt: float) -> void:
	var node: Node3D=bird.node
	bird.forage_age+=dt
	bird.open=move_toward(bird.open,0.0,dt*5)
	var step:=0.0
	var peck:=0.0
	var bob:=0.0
	if bird.forage=="walk":
		var delta: Vector3=bird.goal-node.position
		delta.y=0
		if delta.length()<.04:
			bird.forage="peck"
			bird.forage_age=0.0
			bird.wait=1.2+fmod(bird.phase,.6)
		else:
			node.position+=delta.normalized()*minf(delta.length(),dt*.5)
			node.rotation.y=lerp_angle(node.rotation.y,atan2(-delta.x,-delta.z),1-exp(-5*dt))
			bird.ground_y=move_toward(bird.ground_y,bird.goal.y,dt*.15)
			step=sin(bird.forage_age*11)*.30
			bob=absf(sin(bird.forage_age*11))*.012
	elif bird.forage=="peck":
		peck=pow(maxf(0,sin(bird.forage_age*TAU*1.6)),2)
		if bird.forage_age>bird.wait:
			bird.forage="idle"
			bird.forage_age=0.0
			bird.wait=1.0+fmod(bird.phase,1.4)
	elif bird.forage_age>bird.wait:
		bird.visits+=1
		var angle: float=bird.phase+bird.visits*2.39996
		var goal: Vector3=_bird_floor(bird.home+Vector3(cos(angle),0,sin(angle))*(.65+fmod(bird.phase,.6)))
		var query:=PhysicsRayQueryParameters3D.create(node.position+Vector3.UP*.3,goal+Vector3.UP*.3,19,[game.truck.get_rid()])
		var middle: Vector3=_bird_floor(node.position.lerp(goal,.5))
		if absf(goal.y-bird.home.y)<.045 and absf(middle.y-bird.home.y)<.045 and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			bird.goal=goal
			bird.forage="walk"
		bird.forage_age=0.0
	node.position.y=bird.ground_y+bob
	if TownProps.near_view(game.camera,node.position,2) or node.position.distance_to(game.truck.position)<18: _pose_bird(bird,bird.open,peck,step,time*19+bird.phase)

func water_hit(point: Vector3, amount: float) -> bool:
	for car in cars:
		# Most pellets are nowhere near traffic. Avoid three inverse transforms
		# per pellet before testing the unchanged, oriented wash hitbox.
		if car.node.global_position.distance_squared_to(point)>9: continue
		var local: Vector3=car.node.to_local(point)
		if absf(local.x)<=1.0 and absf(local.z)<=1.7 and local.y>=.25 and local.y<1.8:
			car.wet_age=0.0
			# Five 0.0036-unit pellets every 0.018 seconds: one unit per second.
			# Count actual water, so a brief aiming gap doesn't erase the wash.
			if car.wash_cooldown<=0: car.wash_time+=amount
			return true
	return false

func clear_start_area() -> void:
	var start:=Vector3(0,0,12)
	for car in cars:
		if Vector2(car.node.position.x-start.x,car.node.position.z-start.z).length()>=11: continue
		for i in car.path.size():
			var spot: Vector3=car.path[i]
			if spot.distance_to(start)<13: continue
			car.node.position=spot+Vector3.UP*.12
			car.node.linear_velocity=Vector3.ZERO
			car.next=(i+1)%car.path.size()
			car.node.reset_physics_interpolation()
			break
	for walker in walkers:
		if walker.node.position.distance_to(start)>=11: continue
		for i in walker.path.size():
			if walker.path[i].distance_to(start)<13: continue
			walker.node.position=walker.path[i]
			walker.next=(i+1)%walker.path.size()
			walker.node.reset_physics_interpolation()
			break

func _recover_traffic(car: Dictionary, dt: float) -> bool:
	var body: RigidBody3D=car.node
	if car.recovery>=0:
		car.recovery+=dt
		_car_opacity(body,1-clampf(car.recovery,0,1))
		if car.recovery<1: return true
		var spot:=_clear_lane_spot(car)
		if spot.is_empty(): return true
		body.global_position=spot.position
		body.rotation=Vector3(0,spot.heading,0)
		body.linear_velocity=Vector3.ZERO
		body.angular_velocity=Vector3.ZERO
		body.reset_physics_interpolation()
		car.next=spot.next
		car.recovery=-1.0
		car.fade_in=0.0
		car.stalled=0.0
		car.last_position=body.position
		car.coast=0.0
		return false
	if car.fade_in<1:
		car.fade_in=minf(1,car.fade_in+dt)
		_car_opacity(body,car.fade_in)
	car.progress_clock+=dt
	if car.progress_clock<1: return false
	car.progress_clock=0.0
	var progress: float=body.position.distance_to(car.last_position)
	car.last_position=body.position
	# Yield patiently to the player; only recover genuinely stranded traffic.
	if game.truck.global_position.distance_to(body.position)<10:
		car.stalled=0.0
	elif progress<.6 or absf(body.position.y)>.7:
		car.stalled+=1.0
	else: car.stalled=maxf(0,car.stalled-2.0)
	if car.stalled>=8:
		car.recovery=0.0
		return true
	return false

func _car_opacity(body: RigidBody3D, opacity: float) -> void:
	for mesh in body.find_children("*","GeometryInstance3D",true,false): mesh.transparency=1-opacity

func _clear_lane_spot(car: Dictionary) -> Dictionary:
	var body: RigidBody3D=car.node
	var best: Dictionary={}
	var nearest:=INF
	var box:=BoxShape3D.new()
	box.size=Vector3(2.2,1.5,3.8)
	for i in car.path.size():
		var start: Vector3=car.path[i]
		var end: Vector3=car.path[(i+1)%car.path.size()]
		var direction: Vector3=(end-start).normalized()
		var heading:=atan2(-direction.x,-direction.z)
		for step in range(2,int(start.distance_to(end))-2,4):
			var p: Vector3=start+direction*step+Vector3.UP*.08
			if p.distance_to(game.truck.global_position)<10: continue
			var distance:=p.distance_squared_to(body.position)
			if distance>=nearest: continue
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=box
			query.transform=Transform3D(Basis(Vector3.UP,heading),p+Vector3.UP*.8)
			query.collision_mask=19
			query.exclude=[body.get_rid()]
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
			var occupied:=false
			for walker in walkers:
				if walker.node.global_position.distance_to(p)<3: occupied=true
			if occupied: continue
			nearest=distance
			best={"position":p,"heading":heading,"next":(i+1)%car.path.size()}
	return best

func _threat(point: Vector3) -> Dictionary:
	var vehicles: Array[RigidBody3D]=[game.truck]
	for car in cars: vehicles.append(car.node)
	for vehicle in vehicles:
		var velocity:=Vector3(vehicle.linear_velocity.x,0,vehicle.linear_velocity.z)
		var offset:=point-vehicle.global_position
		offset.y=0
		var speed:=velocity.length()
		var arrival:=clampf(offset.dot(velocity)/maxf(.01,speed*speed),0,.85)
		var closest:=offset-velocity*arrival
		if (speed>1.0 and closest.length()<2.7 and offset.dot(velocity)>0 and offset.length()<speed*.85+3.3) or offset.length()<2.6:
			return {"vehicle":vehicle,"velocity":velocity,"offset":offset}
	return {}

func _keep_clear(person: Node3D) -> void:
	_keep_pool_clear(person)
	# A final horizontal separation guard covers sudden steering, boost speeds,
	# and a vehicle arriving during an existing dodge. People are never obstacles.
	var vehicles: Array[RigidBody3D]=[game.truck]
	for car in cars: vehicles.append(car.node)
	for vehicle in vehicles:
		var center:=vehicle.global_position+vehicle.linear_velocity/60.0
		if absf(center.y-person.global_position.y)>3: continue
		var axis:=vehicle.global_basis.z
		axis.y=0
		axis=axis.normalized()
		var offset:=person.global_position-center
		offset.y=0
		var closest:=axis*clampf(offset.dot(axis),-1.25,1.25)
		var away:=offset-closest
		var distance:=away.length()
		if distance>=1.7: continue
		if distance<.01: away=Vector3(-axis.z,0,axis.x)
		person.global_position+=away.normalized()*(1.7-distance)
	_keep_pool_clear(person)

func _pool_safe(point: Vector3) -> bool:
	var delta:=point-TownLayout.POOL
	return absf(delta.x)>=7.0 or absf(delta.z)>=5.0

func _keep_pool_clear(person: Node3D) -> void:
	if _pool_safe(person.global_position): return
	var local:=person.global_position-TownLayout.POOL
	var candidates: Array[Vector3]=[Vector3(-7.1,local.y,local.z),Vector3(7.1,local.y,local.z),Vector3(local.x,local.y,-5.1),Vector3(local.x,local.y,5.1)]
	var best:=person.global_position
	var score:=INF
	for offset in candidates:
		var point:=TownLayout.POOL+offset
		var distance:=point.distance_to(person.global_position)
		if point.distance_to(game.truck.global_position)<3: distance+=20
		if distance<score: best=point; score=distance
	person.global_position=best

func _begin_dodge(walker: Dictionary, danger: Dictionary) -> void:
	var person: Node3D=walker.node
	var travel: Vector3=danger.velocity.normalized()
	if travel.length()<.1: travel=-danger.vehicle.global_basis.z
	var side:=Vector3(-travel.z,0,travel.x)
	if side.dot(danger.offset)<0: side=-side
	var chosen:=person.position
	var best:=-INF
	for direction in [side,-side,(side-travel*.6).normalized(),(-side-travel*.6).normalized()]:
		var destination: Vector3=person.position+direction*3.4
		destination.y=.16
		if not _pool_safe(destination): continue
		var query:=PhysicsRayQueryParameters3D.create(person.position+Vector3.UP*.9,destination+Vector3.UP*.9,17,[game.truck.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query): continue
		var floor_query:=PhysicsRayQueryParameters3D.create(destination+Vector3.UP,destination+Vector3.DOWN*.3,1)
		if get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty(): continue
		var future: Vector3=danger.vehicle.global_position+danger.velocity*.45
		var safety:=Vector2(destination.x-future.x,destination.z-future.z).length()
		if safety>best: best=safety; chosen=destination
	if best==-INF: return
	walker.from=person.position
	walker.to=chosen
	game.sounds.play("dodge",person.global_position,.8,.4)
	walker.hop=0.0
	walker.cooldown=.9
	person.rotation.y=atan2(-travel.x,-travel.z)
