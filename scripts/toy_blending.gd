class_name ToyBlending
extends Node
# Runtime comparison switches only cached art, never missions or collision.
var game: Node3D
var rigs: Array[ToyBlendRig]=[]
var strength:=25
var selector: OptionButton
var label: Label
const OPTIONS:=[0,10,15,25,50,75,100]

static func nearest_level(value: int) -> int:
	var result:=0
	for level in OPTIONS:
		if absi(level-value)<absi(result-value): result=level
	return result

func _ready() -> void:
	name="ToyBlending"
	if TownProps.bake_scenery: return
	for person in game.find_children("*","Node3D",true,false):
		if person.get_node_or_null("ArmLeft") and person.get_node_or_null("ArmRight"):
			var inverse: Transform3D=person.global_transform.affine_inverse()
			var bun:=person.find_children("*","MeshInstance3D",true,false).any(func(part): return (inverse*part.global_position).distance_to(Vector3(0,2.57,.1))<.02)
			_attach(person,"person_bun" if bun else "person")
	for prop in game.interactions.props+game.travel.race.props:
		if not is_instance_valid(prop): continue
		if prop.kind=="hydrant":
			var hydrant_rig:=_attach(prop,"hydrant")
			prop.meshes.append(hydrant_rig.art)
			continue
		if prop.kind!="tree": continue
		var holder: Node3D=prop
		var variant:=0
		for child: Node3D in prop.find_children("*","Node3D",true,false):
			if child.scene_file_path.get_file().get_basename() in ["tree_0","tree_1"]:
				holder=child
				variant=1 if child.scene_file_path.get_file().get_basename()=="tree_1" else 0
				break
		var rig:=_attach(holder,"tree1" if variant==1 else "tree")
		prop.meshes.append(rig.art)
	var requested:=25
	if OS.has_feature("web"):
		var query=JavaScriptBridge.eval("new URLSearchParams(location.search).get('blend')")
		if query!=null and str(query).is_valid_int(): requested=nearest_level(int(query))
	set_strength(requested)
	label=Label.new()
	label.text="Toy shapes"
	label.add_theme_font_override("font",game.hud.bold)
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",game.hud.INK)
	game.hud.pause_panel.add_child(label)
	selector=OptionButton.new()
	selector.add_theme_font_override("font",game.hud.font)
	selector.add_theme_font_size_override("font_size",18)
	for level in OPTIONS: selector.add_item("Original" if level==0 else "Blend %d%%"%level,level)
	selector.select(OPTIONS.find(strength))
	selector.item_selected.connect(func(index: int): set_strength(selector.get_item_id(index)))
	game.hud.pause_panel.add_child(selector)
	layout()

func _attach(toy: Node3D, model: String) -> ToyBlendRig:
	var rig:=ToyBlendRig.new()
	toy.add_child(rig)
	rig.setup(toy,model)
	rigs.append(rig)
	return rig

func set_strength(level: int) -> void:
	strength=nearest_level(level)
	for rig in rigs: rig.set_strength(strength)
	if selector: selector.select(OPTIONS.find(strength))

func _process(_dt: float) -> void:
	layout()

func layout() -> void:
	if not selector: return
	var touch: bool=game.hud.touch_mode
	label.position=Vector2(22,93) if touch else Vector2(38,492)
	selector.position=Vector2(143,84) if touch else Vector2(245,480)
	selector.size=Vector2(165,48) if touch else Vector2(265,45)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_B: return
	if game.loading or game.in_main_menu or game.intro.active or game.travel.active: return
	if game.dialogue_control.interrupting and not game.paused: return
	set_strength(0 if strength>0 else 25)
	game.toast("Toy shapes: Original" if strength==0 else "Toy shapes: Blend 25%")
	get_viewport().set_input_as_handled()
