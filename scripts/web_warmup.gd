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
	var sources: Array[MeshInstance3D]=[
		game.truck.pool[0],game.truck.splash_pool[0],game.truck.ring_pool[0],
		game.truck.effects.dust_pool[0],game.truck.effects.track_pool[0],
		game.atmosphere.steam_pool[0],game.rewards.star_pool[0]]
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
	var views: Array[Vector3]=[Vector3.ZERO,Vector3(-36,0,-36),Vector3(36,0,-36),Vector3(-36,0,36),Vector3(36,0,36),TownLayout.FIRE,TownLayout.POOL,Vector3.ZERO]
	for i in views.size():
		camera.size=165 if i==0 else (55 if i<5 else 26)
		camera.position=views[i]+game.camera_offset
		camera.look_at(views[i])
		proxies.position=views[i]
		for proxy in proxies.get_children():
			if proxy.mesh is QuadMesh: proxy.look_at(camera.global_position)
		await _draw_frames(3)
		rendered_views+=1
		if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckWarmup(%f)" % (float(i+1)/views.size()))
	proxies.queue_free()
	camera.transform=saved_transform
	camera.size=saved_size
	# Populate the portrait/font shader paths before the first incoming call.
	for speaker in ["DISPATCH","MAYA","LEO","JUNE","OLIVER"]:
		game.hud.begin_dialogue(speaker,"ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789.,!? ' · ›")
		game.hud.dialogue_panel.modulate.a=1
		game.hud.dialogue_label.visible_characters=-1
		await _draw_frames(2)
	game.hud.dialogue_panel.hide()
	game.hud.bubble_position_ready=false
	game.hud.full_text=""
	game.hud.dialogue_text=""
	game.music.stream_paused=game.music_muted
	game.audio.stream_paused=false
	game.loading=false
	tree.paused=false
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckReady()")
	queue_free()
