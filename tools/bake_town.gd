# Rebuilds the editable town scene from the deterministic layout in town.gd.
# Run: Godot --headless --path . --script tools/bake_town.gd
extends SceneTree
func _initialize() -> void: call_deferred("bake")
func own_children(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner=scene_root
		if child.scene_file_path.is_empty(): own_children(child,scene_root)
func bake() -> void:
	var town:=LittleTown.new()
	town.name="MapleBay"
	root.add_child(town)
	own_children(town,town)
	var packed:=PackedScene.new()
	var result:=packed.pack(town)
	if result==OK: result=ResourceSaver.save(packed,"res://scenes/maple_bay.tscn")
	print("Town scene bake: ",error_string(result))
	town.free()
	TownProps.materials.clear()
	quit(result)
