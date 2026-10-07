class_name WebWarmup
extends Node

var game: Node3D
var rendered_views:=0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS

func _draw_frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
		await get_tree().process_frame

func run() -> void:
	# Compatibility compiles shader variants on first draw, not on resource load.
	# Keep the HTML loading screen up while the actual town and effects render.
	var tree:=get_tree()
	tree.paused=true
	game.loading=true
	game.music.stream_paused=true
	game.audio.stream_paused=true
	var camera: Camera3D=game.camera
	var saved_transform:=camera.transform
	var saved_size:=camera.size
	var proxies:=Node3D.new()
	game.add_child(proxies)
	var pool_proxy:=make_pool_proxy(game.town.pool_water)
	proxies.add_child(pool_proxy)
	pool_proxy.position=Vector3(0,1.5,0)
	var sources: Array[MeshInstance3D]=[
		game.truck.pool[0],game.truck.splash_pool[0],game.truck.ring_pool[0],
		game.truck.effects.dust_pool[0],game.truck.effects.track_pool[0],
		game.atmosphere.steam_pool[0],game.rewards.star_pool[0]]
	sources.append(game.railway.smoke[0].mesh)
	sources.append(game.dog_puddle.surfaces[1])
	# Include the transparent fade path used when a tree/prop is knocked loose.
	for prop in game.interactions.props:
		if prop.kind=="tree":
			for mesh in prop.meshes:
				if mesh is MeshInstance3D: sources.append(mesh)
			break
	for i in sources.size():
		var source:=sources[i]
		var proxy:=MeshInstance3D.new()
		proxy.mesh=source.mesh
		proxy.material_override=source.material_override
		for surface in source.mesh.get_surface_count():
			proxy.set_surface_override_material(surface,source.get_surface_override_material(surface))
		proxy.cast_shadow=source.cast_shadow
		proxies.add_child(proxy)
		proxy.position=Vector3((i%4-1.5)*2,2,float(i/4)*2)
		if i>=7: proxy.transparency=.5
		if proxy.material_override is ShaderMaterial: TownProps.effect_opacity(proxy,.6)
	# The live spray uses instancing/vertex colours, not the individual pool.
	var water_sample:=MultiMesh.new()
	water_sample.transform_format=MultiMesh.TRANSFORM_3D
	water_sample.use_colors=true
	water_sample.mesh=game.truck.water_batch.multimesh.mesh
	water_sample.instance_count=1
	water_sample.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.4),Vector3.ZERO))
	water_sample.set_instance_color(0,FireEngine.WATER_COLORS[0])
	var water_proxy:=MultiMeshInstance3D.new()
	water_proxy.multimesh=water_sample
	water_proxy.material_override=game.truck.water_batch.material_override
	water_proxy.cast_shadow=game.truck.water_batch.cast_shadow
	proxies.add_child(water_proxy)
	water_proxy.position=Vector3(2,3,0)
	# Render the opaque refill shader before the first hydrant connection.
	var hose_proxy:=MeshInstance3D.new()
	hose_proxy.mesh=game.refill_hose.segments[0].mesh
	hose_proxy.material_override=game.refill_hose.segments[0].material_override
	proxies.add_child(hose_proxy)
	hose_proxy.position=Vector3(0,2,0)
	hose_proxy.scale=Vector3(.12,1,.12)
	# Warm the instanced, vertex-coloured broken-hydrant water path too.
	# A visible sample avoids a first-impact shader hitch with the jets hidden.
	for effect in game.interactions.ground_effects:
		if not effect.water: continue
		var sample:=MultiMesh.new()
		sample.transform_format=MultiMesh.TRANSFORM_3D
		sample.use_colors=true
		sample.mesh=effect.water.multimesh.mesh
		sample.instance_count=1
		sample.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.4),Vector3.ZERO))
		sample.set_instance_color(0,FireEngine.WATER_COLORS[0])
		var proxy:=MultiMeshInstance3D.new()
		proxy.multimesh=sample
		proxy.material_override=effect.water.material_override
		proxy.cast_shadow=effect.water.cast_shadow
		proxies.add_child(proxy)
		proxy.position=Vector3(0,3,0)
		break
	var views: Array[Vector3]=[Vector3.ZERO,Vector3(-36,0,-36),Vector3(36,0,-36),Vector3(-36,0,36),Vector3(36,0,36),TownLayout.FIRE,TownLayout.POOL,TownLayout.DOG,game.railway.engine.position,Vector3.ZERO]
	for i in views.size():
		camera.size=165 if i==0 else (55 if i<5 else 26)
		camera.position=views[i]+game.camera_offset
		camera.look_at(views[i])
		proxies.position=views[i]
		for proxy in proxies.get_children():
			if proxy is MeshInstance3D and proxy.mesh is QuadMesh: proxy.look_at(camera.global_position)
		await _draw_frames(3)
		rendered_views+=1
		if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckWarmup(%f)" % (float(i+1)/views.size()))
	game.pool_shader_warmed=true
	# Draw the new mat, track and changing billboard before gameplay too.
	game.travel.race.show()
	game.travel.race.mat.show()
	camera.position=ToyRaceTrack.ORIGIN+Vector3(90,130,115)
	camera.look_at(ToyRaceTrack.ORIGIN)
	camera.size=180
	game.travel.mat.show_mat(false,.5,ToyRaceTrack.ORIGIN)
	await _draw_frames(3)
	game.travel.begin_assembly(true)
	game.travel.grow_assembly(.65)
	await _draw_frames(3)
	game.travel.finish_assembly()
	game.travel.race.hide()
	game.travel.begin_assembly(false)
	game.travel.grow_assembly(.65)
	camera.position=Vector3(90,130,115)
	camera.look_at(Vector3.ZERO)
	await _draw_frames(3)
	game.travel.finish_assembly()
	game.travel.mat.hide()
	proxies.queue_free()
	camera.transform=saved_transform
	camera.size=saved_size
	# Populate the portrait/font shader paths before the first incoming call.
	for speaker in ["DISPATCH","MAYA","LEO","JUNE","OLIVER","ROWAN"]:
		game.hud.begin_dialogue(speaker,"ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789.,!? ' · ›")
		game.hud.dialogue_panel.modulate.a=1
		game.hud.dialogue_label.visible_characters=-1
		await _draw_frames(2)
	game.hud.dialogue_panel.hide()
	game.hud.bubble_position_ready=false
	game.hud.full_text=""
	game.hud.dialogue_text=""
	# Prepare the opening frame while simulation is still paused. The shell
	# may finish loading long before the user presses Start.
	game.intro.start()
	await _draw_frames(1)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.firetruckReady()")
		while not bool(JavaScriptBridge.eval("window.firetruckStarted === true")):
			await tree.process_frame
	game.music.stream_paused=game.music_muted
	game.audio.stream_paused=false
	game.loading=false
	tree.paused=false
	queue_free()

static func make_pool_proxy(source: MeshInstance3D) -> MeshInstance3D:
	# Visibility and depth are presentation only; never mutate mission progress.
	var proxy:=MeshInstance3D.new()
	proxy.name="PoolWaterWarmup"
	proxy.mesh=source.mesh
	proxy.scale=source.scale
	proxy.cast_shadow=source.cast_shadow
	proxy.material_override=source.material_override.duplicate()
	proxy.material_override.set_shader_parameter("depth",.5)
	return proxy
