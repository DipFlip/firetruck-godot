extends SceneTree
# Offline carpet art and a linear timing map share the actual toy schedules.
# No per-tree decals, extra live draw calls or per-frame image edits are needed.
var game: Node3D
func _initialize() -> void: call_deferred("run")

func capture(path: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw()
	var error:=root.get_texture().get_image().save_png(path)
	assert(error==OK,"Could not bake "+path)
	print("MAT PRINT: ",path)

func excluded() -> void:
	for node in game.find_children("*","Node3D",true,false):
		if node.get_meta("omit_mat_print",false): node.hide()
	# The carpet records places and buildings, rather than the current cast.
	game.town.cat.hide()
	game.town.dog.hide()
	for duck in game.travel.race.ducks: duck.hide()

func pixel_at(point: Vector2) -> Vector2:
	return (point+Vector2.ONE*80)/160*1024

func paint_rect(image: Image, ownership: Image, bounds: Rect2, centre: Vector2, timing: Color) -> void:
	var a:=pixel_at(bounds.position)
	var b:=pixel_at(bounds.end)
	var origin:=pixel_at(centre)
	for y in range(clampi(floori(a.y),0,1023),clampi(ceili(b.y),0,1024)):
		for x in range(clampi(floori(a.x),0,1023),clampi(ceili(b.x),0,1024)):
			var distance:=Vector2(x,y).distance_squared_to(origin)
			if distance>=ownership.get_pixel(x,y).r: continue
			ownership.set_pixel(x,y,Color(distance,0,0,1))
			image.set_pixel(x,y,timing)

func replacements(is_race: bool) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for item in game.travel.assembly:
		if item.gpu or item.instance>=0: continue
		var tree: bool=item.node is BreakableProp and item.node.kind=="tree"
		var road: bool=item.node.get_meta("mat_print_replacement",false)
		if not tree and not road: continue
		var local_bounds: AABB=item.node.get_aabb() if item.node is GeometryInstance3D else TownProps.visual_bounds(item.node)
		var bounds: AABB=item.transform*local_bounds
		var rect:=Rect2(Vector2(bounds.position.x,bounds.position.z)-Vector2(game.travel.assembly_origin.x,game.travel.assembly_origin.z),Vector2(bounds.size.x,bounds.size.z)).grow(1.2)
		var origin: Vector3=item.transform.origin-game.travel.assembly_origin
		result.append({"node":item.node,"rect":rect,"centre":Vector2(origin.x,origin.z),"timing":Color(item.delay+item.span*(.48 if tree else .52),item.delay+item.span*(.76 if tree else .78),1,1),"road":road})
	return result

func timing_map(records: Array[Dictionary], is_race: bool) -> void:
	var image:=Image.create(1024,1024,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,1,0,1))
	var ownership:=Image.create(1024,1024,false,Image.FORMAT_RF)
	ownership.fill(Color(1e8,0,0,1))
	# Only the ribbon footprint loses its printed road. Grass elsewhere and
	# printed houses keep their detail until the normal final print fade.
	if is_race:
		for record in records:
			if record.node.name!="RibbonRoadAndBridge": continue
			var points:=RaceCourse.points()
			for i in range(0,points.size(),3):
				var centre:=pixel_at(Vector2(points[i].x,points[i].z))
				var radius:=10.5/160*1024
				for y in range(clampi(floori(centre.y-radius),0,1023),clampi(ceili(centre.y+radius),0,1024)):
					for x in range(clampi(floori(centre.x-radius),0,1023),clampi(ceili(centre.x+radius),0,1024)):
						if Vector2(x,y).distance_squared_to(centre)<radius*radius: image.set_pixel(x,y,record.timing)
	for record in records:
		if not record.road: paint_rect(image,ownership,record.rect,record.centre,record.timing)
	image.save_png("res://assets/scenery/"+("race" if is_race else "maple")+"_mat_arrival.png")

func bake(is_race: bool) -> void:
	var records:=replacements(is_race)
	timing_map(records,is_race)
	game.travel.flatten_for_print()
	excluded()
	var world: String="race" if is_race else "maple"
	await capture("res://assets/scenery/"+world+"_mat.png")
	for record in records: record.node.hide()
	await capture("res://assets/scenery/"+world+"_mat_clean.png")

func run() -> void:
	root.size=Vector2i(1024,1024)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.start()
	game.set_process(false)
	game.travel.set_process(false)
	game.travel.mat.hide()
	game.playroom.hide()
	game.truck.hide()
	game.hud.hide()
	game.miniature.hide()
	game.marker.hide()
	game.job_label.hide()
	for node in game.get_children():
		if node is RoomDust: node.hide()
	game.camera.position=Vector3(0,200,0)
	game.camera.look_at(Vector3.ZERO,Vector3(0,0,-1))
	game.camera.size=160
	game.camera.far=450
	await bake(false)
	game.intro.finish()
	game.travel.set_world_visible(false)
	game.travel.in_race=true
	game.travel.race.show()
	game.travel.race.mat.position.y=-.01
	for fire in get_nodes_in_group("toy_fires"): fire.hide()
	game.travel.begin_assembly(true)
	game.travel.race.get_node("RacePlayroomFloor").hide()
	game.camera.position=ToyRaceTrack.ORIGIN+Vector3(0,200,0)
	game.camera.look_at(ToyRaceTrack.ORIGIN,Vector3(0,0,-1))
	game.camera.size=160
	await bake(true)
	game.travel.finish_assembly()
	for player in [game.audio,game.music,game.water_audio]:
		player.stop()
		player.stream=null
	game.playback=null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
