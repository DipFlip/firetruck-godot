extends Node3D
# An isolated art study: each strength is a baked smooth union of one toy's
# original solids. Facial details remain separate so the expression survives.
var slider: HSlider
var value_label: Label
var originals: Array[Node3D]=[]
var softened: Array[MeshInstance3D]=[]
var study_rigs: Array[ToyBlendRig]=[]
var variants: Dictionary={}
var tree_originals: Array[Node3D]=[]
func _ready() -> void:
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("d9e4dd")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("e8f1ef")
	environment.environment.ambient_light_energy=.45
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_ACES
	environment.environment.tonemap_exposure=.75
	add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-28,0)
	light.light_energy=.22
	light.shadow_opacity=.72
	light.shadow_enabled=true
	add_child(light)
	TownProps.box(self,Vector3(0,-.22,0),Vector3(24,.4,15),Color("c9c1ac"))
	for column in 2:
		var offset:=-4.4 if column==0 else 4.4
		var tree: Node3D=load("res://assets/models/tree_0.glb").instantiate()
		add_child(tree)
		tree.position=Vector3(offset-1.6,0,0)
		TownProps.soften_toy_shine(tree)
		tree_originals.append(tree)
		var person:=TownProps.person(self,Vector3(offset+1.7,0,0),Color("ecb354"))
		person.scale=Vector3.ONE*1.7
		person.rotation.y=PI
		if column==1:
			originals.assign([tree,person])
			for pair in [[tree,"tree"],[person,"person"]]:
				var rig:=ToyBlendRig.new()
				pair[0].add_child(rig)
				rig.setup(pair[0],pair[1])
				study_rigs.append(rig)
				softened.append(rig.art)
		var hydrant:=Node3D.new()
		add_child(hydrant)
		hydrant.position=Vector3(offset+3.5,0,1.8)
		hydrant.scale=Vector3.ONE*2.7
		FireHydrant.build_art(hydrant)
		if column==1:
			var rig:=ToyBlendRig.new()
			hydrant.add_child(rig)
			rig.setup(hydrant,"hydrant")
			study_rigs.append(rig)
			softened.append(rig.art)
	var camera:=Camera3D.new()
	add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=18.7
	camera.position=Vector3(1,9,21)
	camera.look_at(Vector3(0,2,0))
	camera.current=true
	var ui:=CanvasLayer.new()
	add_child(ui)
	var panel:=VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left=30
	panel.offset_right=-30
	panel.offset_top=22
	panel.add_theme_constant_override("separation",8)
	ui.add_child(panel)
	var title:=Label.new()
	title.text="Model blending study"
	title.add_theme_font_size_override("font_size",28)
	panel.add_child(title)
	var subtitle:=Label.new()
	subtitle.text="Touching parts join within one colour. Green foliage can share shades."
	panel.add_child(subtitle)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	panel.add_child(row)
	slider=HSlider.new()
	slider.min_value=0
	slider.max_value=ToyBlending.OPTIONS.size()-1
	slider.step=1
	slider.custom_minimum_size=Vector2(280,34)
	row.add_child(slider)
	value_label=Label.new()
	value_label.custom_minimum_size=Vector2(150,34)
	row.add_child(value_label)
	var shoulders:=CheckButton.new()
	shoulders.text="Join moving shoulders (rest-pose experiment)"
	shoulders.add_theme_color_override("font_color",Color("253e38"))
	shoulders.add_theme_color_override("font_pressed_color",Color("253e38"))
	shoulders.add_theme_color_override("font_hover_color",Color("253e38"))
	shoulders.add_theme_color_override("font_hover_pressed_color",Color("253e38"))
	panel.add_child(shoulders)
	shoulders.toggled.connect(func(enabled: bool):
		study_rigs[1].model="person_joined" if enabled else "person"
		study_rigs[1].set_strength(ToyBlending.OPTIONS[roundi(slider.value)]))
	var palette:=OptionButton.new()
	palette.add_item("Green tree")
	palette.add_item("Golden tree")
	row.add_child(palette)
	palette.item_selected.connect(func(index: int):
		for column in 2:
			var tree: Node3D=load("res://assets/models/tree_%d.glb"%index).instantiate()
			add_child(tree)
			tree.transform=tree_originals[column].transform
			TownProps.soften_toy_shine(tree)
			if column==1:
				var rig:=ToyBlendRig.new()
				tree.add_child(rig)
				rig.setup(tree,"tree1" if index==1 else "tree")
				rig.set_strength(ToyBlending.OPTIONS[roundi(slider.value)])
				study_rigs[0]=rig
				softened[0]=rig.art
			tree_originals[column].queue_free()
			tree_originals[column]=tree)
	for i in 2:
		var label:=Label.new()
		label.text="Original" if i==0 else "Blended"
		label.position=Vector2(0,0)
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		label.position+=Vector2(-300 if i==0 else 180,-80)
		label.add_theme_font_size_override("font_size",24)
		label.add_theme_color_override("font_color",Color("253e38"))
		ui.add_child(label)
	var back:=Button.new()
	back.text="Back to game"
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.position+=Vector2(30,-55)
	ui.add_child(back)
	back.pressed.connect(func():
		if OS.has_feature("web"): JavaScriptBridge.eval("location.href=location.pathname")
		else: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	slider.value_changed.connect(set_blend)
	slider.value=ToyBlending.OPTIONS.find(25)
	for label: Label in [title,subtitle,value_label]: label.add_theme_color_override("font_color",Color("253e38"))
	if OS.has_feature("web"):
		await get_tree().process_frame
		await get_tree().process_frame
		JavaScriptBridge.eval("window.firetruckReady()")
func set_blend(value: float) -> void:
	var level: int=ToyBlending.OPTIONS[roundi(value)]
	value_label.text="  Original" if level==0 else "  Blend %d%%"%level
	for rig in study_rigs: rig.set_strength(level)
