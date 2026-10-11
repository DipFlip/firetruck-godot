extends SceneTree
var failures:=0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.call_timer=0
	game.intro.start()
	var assembly: Array=game.travel.assembly
	var fountain: Node3D=game.atmosphere.fountain
	check(assembly.filter(func(item): return item.node==fountain).size()==1 and game.atmosphere.fountain_drops.all(func(drop): return drop.get_parent()==fountain),"Fountain water, jets and stone container share one complete assembly toy")
	for title in ["WoodenTrackWest","WoodenTrackEast"]:
		var track: Node3D=game.railway.get_node(title)
		check(assembly.filter(func(item): return item.node==track).size()==1,"Rails, sleepers and wooden bed assemble together: "+title)
	game.intro.clock=TownIntro.LENGTH-.001
	game.intro.update((0)/PlayMatTravel.INTRO_PACE)
	var before: Transform3D=game.camera.global_transform
	var screen: Vector2=game.camera.unproject_position(game.truck.global_position)
	game.intro.update((.001)/PlayMatTravel.INTRO_PACE)
	check(game.camera.global_position.distance_to(before.origin)<.05 and game.camera.unproject_position(game.truck.global_position).distance_to(screen)<1 and game.truck.linear_velocity.z>4.9,"Maple Bay entrance transfers position, camera and rolling speed continuously")
	var rail: NorthlineRailway=game.railway
	var from: Vector3=rail.driver.position
	var seat: Vector3=rail.engine.position+NorthlineRailway.CAB_STANDING_POSE
	var clears_wall:=true
	var keeps_moving:=true
	var smooth_velocity:=true
	var min_speed:=INF
	for i in 316:
		var t:=i*.01
		var p:=NorthlineRailway.boarding_position(from,seat,t)
		var side: float=p.z-rail.engine.position.z
		if side>.7 and side<1.85: clears_wall=clears_wall and p.y>rail.engine.position.y+3.85
		if t>.5 and t<2.35:
			var before_p:=NorthlineRailway.boarding_position(from,seat,t-.001)
			var after_p:=NorthlineRailway.boarding_position(from,seat,t+.001)
			var velocity: Vector3=(after_p-before_p)/.002
			min_speed=minf(min_speed,velocity.length())
			keeps_moving=keeps_moving and velocity.length()>.4
			var before_velocity: Vector3=(p-before_p)/.001
			var after_velocity: Vector3=(after_p-p)/.001
			smooth_velocity=smooth_velocity and before_velocity.distance_to(after_velocity)<.08
	var takeoff:=NorthlineRailway.BOARDING_TAKEOFF
	var landing:=takeoff+NorthlineRailway.BOARDING_FLIGHT
	check(clears_wall,"Rowan's continuous arc clears the cab wall before descending inside")
	check(keeps_moving and smooth_velocity,"The jump never stops between ascent, sideways travel and descent; minimum mid-flight speed: "+str(min_speed))
	check(NorthlineRailway.boarding_position(from,seat,takeoff).is_equal_approx(from) and NorthlineRailway.boarding_position(from,seat,landing).is_equal_approx(seat),"The flight joins the exact standing poses at both ends")
	check(NorthlineRailway.boarding_position(from,seat,takeoff+.001).distance_to(from)/.001<.002 and NorthlineRailway.boarding_position(from,seat,landing-.001).distance_to(seat)/.001<.002,"Takeoff and landing ease smoothly to rest")
	game.travel.start(true)
	game.travel._update_transition(game.travel.duration-.001)
	before=game.camera.global_transform
	screen=game.camera.unproject_position(game.truck.global_position)
	var wheel: float=game.truck.wheel_travel
	game.travel._update_transition(.001)
	check(game.camera.global_position.distance_to(before.origin)<.05 and game.camera.unproject_position(game.truck.global_position).distance_to(screen)<1 and game.truck.linear_velocity.z>4.9 and game.truck.wheel_travel==wheel,"Motorway entrance hands over without stopping, resetting wheels or cutting the camera")
	var race: ToyRaceTrack=game.travel.race
	var curbs:=race.get_children().filter(func(node): return str(node.name).begins_with("StripedRaisedCurb"))
	var measured:=true
	for curb in curbs:
		var data: Array=curb.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
		for i in range(2,vertices.size(),2):
			var length: float=((vertices[i]+vertices[i+1])*.5).distance_to((vertices[i-2]+vertices[i-1])*.5)
			measured=measured and absf(uv[i].x-uv[i-2].x-length)<.001
		var period: float=curb.material_override.get_shader_parameter("stripe_period")
		measured=measured and period>3.9 and period<4.1 and absf(uv[-1].x/period-round(uv[-1].x/period))<.001
	check(curbs.size()==2 and measured,"Both curb stripe patterns use their own actual arc length and meet cleanly at the loop seam")
	check(race.has_node("BridgeGroundShade") and race.get_node("BridgeGroundShade").cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"A soft ground shade separates the elevated deck from grass and lower asphalt")
	var fire: ToyFire=race.grill_fire
	fire.get_parent().global_position+=Vector3(2,0,0)
	var center: Vector3=fire.global_position+Vector3.UP*1.8
	var hit:=center+Vector3(1.8,0,0)
	race.water_hit(hit,10)
	var centroid:=Vector3.ZERO
	for sparkle in game.rewards.sparkles: centroid+=sparkle.mesh.position
	centroid/=game.rewards.sparkles.size()
	check(race.jobs[1].done and Vector2(centroid.x,centroid.z).distance_to(Vector2(center.x,center.z))<.001,"Fire reward stars surround the moved grill's centre rather than the final water contact")
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
