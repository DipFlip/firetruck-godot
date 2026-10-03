extends SceneTree

# Run after importing assets. Export builds always regenerate these batches
# so LOD generation and mesh uploads do not happen during browser startup.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	TownProps.bake_scenery=true
	# Trees stay separate rigid bodies. Collapse their palette surfaces inside
	# each model, so interaction and wind do not require eight material draws.
	for variant in 2:
		var tree: Node3D=load("res://assets/models/tree_%d.glb" % variant).instantiate()
		TownProps.apply_toy_finish(tree)
		TownProps.soften_toy_shine(tree)
		root.add_child(tree)
		TownProps.merge_fixed_geometry(tree,[],"tree_%d" % variant)
		tree.free()
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	print("BAKED SCENERY: ",game.merged_scenery," source meshes")
	for player in [game.audio,game.music,game.water_audio]:
		if player:
			player.stop()
			player.stream=null
	game.playback=null
	await create_timer(.3).timeout
	game.queue_free()
	await process_frame
	await process_frame
	quit()
