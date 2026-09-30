extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	seed(42)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer=0
	game.stage=4
	game.hud.hide()
	var output:="res://output/lighting/capture.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		for child in game.get_children():
			if child is DirectionalLight3D and arg.begins_with("--sun="): child.light_energy=float(arg.trim_prefix("--sun="))
			if child is WorldEnvironment:
				var env: Environment=child.environment
				if arg.begins_with("--ambient="): env.ambient_light_energy=float(arg.trim_prefix("--ambient="))
				if arg.begins_with("--exposure="): env.tonemap_exposure=float(arg.trim_prefix("--exposure="))
				if arg.begins_with("--saturation="): env.adjustment_saturation=float(arg.trim_prefix("--saturation="))
				if arg.begins_with("--contrast="): env.adjustment_contrast=float(arg.trim_prefix("--contrast="))
				if arg=="--ao": env.ssao_enabled=true
	for i in 90:
		await physics_frame
		await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	root.get_texture().get_image().save_png(output)
	game.queue_free()
	await process_frame
	await process_frame
	quit()
