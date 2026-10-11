extends SceneTree
var failures:=0
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1
func capture(label: String) -> void:
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/firedriver-colour-"+label+".png")
func posed_vertices(rig: ToyBlendRig) -> PackedVector3Array:
	var arrays:=rig.art.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var result:=PackedVector3Array()
	result.resize(vertices.size())
	for i in vertices.size():
		for j in 4:
			var bone:=bones[i*4+j]
			result[i]+=(rig.skeleton.get_bone_global_pose(bone)*rig.art.skin.get_bind_pose(bone)*vertices[i])*weights[i*4+j]
	return result
func run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.travel.set_process(false)
	game.life.set_physics_process(false)
	game.call_timer=0
	var blending: ToyBlending=game.toy_blending
	var people:=blending.rigs.filter(func(rig): return rig.model.begins_with("person"))
	var trees:=blending.rigs.filter(func(rig): return rig.model.begins_with("tree"))
	var hydrants:=blending.rigs.filter(func(rig): return rig.model=="hydrant")
	print("Blended reusable toys: ",people.size()," people, ",trees.size()," trees")
	check(people.size()>30 and trees.size()>60 and blending.strength==25,"Both maps use the shared 25% rule for trees and people")
	check(hydrants.size()==(game.interactions.props+game.travel.race.props).filter(func(prop): return prop.kind=="hydrant").size() and not hydrants.is_empty(),"Every hydrant on both maps uses the shared red-only blend")
	check(blending.rigs.all(func(rig): return rig.art.visible and rig.sources.all(func(source): return source.part.layers==0)),"Only the blended art renders while original art stays available for comparison")
	var collisions: Array=[]
	for body: CollisionObject3D in game.find_children("*","CollisionObject3D",true,false): collisions.append([body,body.get_rid(),body.collision_layer,body.collision_mask,body.global_transform])
	var meshes:=blending.rigs.map(func(rig): return rig.art.mesh)
	blending.set_strength(0)
	check(blending.rigs.all(func(rig): return not rig.art.visible and rig.sources.all(func(source): return source.part.layers==source.layers and source.part.cast_shadow==source.shadow)),"Original mode restores each source's precise render layers and shadows")
	blending.set_strength(25)
	check(blending.rigs.map(func(rig): return rig.art.mesh)==meshes,"Switching reuses cached meshes without another bake")
	check(collisions.all(func(saved): return saved[0].get_rid()==saved[1] and saved[0].collision_layer==saved[2] and saved[0].collision_mask==saved[3] and saved[0].global_transform.is_equal_approx(saved[4])),"Comparing art leaves colliders and world poses unchanged")
	for level in [10,15]:
		blending.selector.item_selected.emit(ToyBlending.OPTIONS.find(level))
		check(blending.strength==level and blending.selector.get_selected_id()==level and blending.rigs.all(func(item): return item.art.mesh==ToyBlendRig.mesh_for(item.model,level)),"The pause selector applies %d%% to every toy without index rounding"%level)
	blending.set_strength(25)
	var rig: ToyBlendRig=people.filter(func(item): return item.toy==game.town.people[0])[0]
	var arrays:=rig.art.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var categories: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var colours: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var rigid:=true
	for i in vertices.size():
		var largest:=maxf(maxf(weights[i*4],weights[i*4+1]),maxf(weights[i*4+2],weights[i*4+3]))
		rigid=rigid and largest>.999
	check(rigid,"Gameplay keeps articulated joints separate instead of stretching the shirt")
	var sharp:=true
	for i in range(0,indices.size(),3):
		sharp=sharp and categories[indices[i]].x==categories[indices[i+1]].x and categories[indices[i]].x==categories[indices[i+2]].x
	check(sharp,"No person triangle crosses a skin, shirt, hair or detail colour boundary")
	var buttons:=0
	var eyes:=0
	for i in vertices.size():
		if categories[i].x==3 and colours[i].is_equal_approx(Color("e8d4ac")): buttons+=1
		if categories[i].x==3 and colours[i].is_equal_approx(Color("3b4037")): eyes+=1
	check(buttons>200 and eyes>200,"Original button and dot-eye geometry remains in the mesh")
	var bind:=posed_vertices(rig)
	rig.toy.get_node("ArmLeft").rotation.z=-2.65
	rig.toy.get_node("ArmRight").rotation.z=2.65
	rig._update_pose()
	var raised:=posed_vertices(rig)
	var moved:=0
	var finite:=true
	for i in vertices.size():
		finite=finite and raised[i].is_finite()
		if bind[i].distance_to(raised[i])>.25: moved+=1
	check(finite and moved>500,"The baked shoulders and sleeves articulate with raised arms")
	var race_rig: ToyBlendRig=people.filter(func(item): return is_instance_valid(item.joints[3]))[0]
	race_rig.joints[3].rotation.y=.45
	race_rig.joints[6].scale.y=.1
	race_rig._update_pose()
	check(race_rig.skeleton.get_bone_global_pose(3).is_equal_approx(race_rig.toy.global_transform.affine_inverse()*race_rig.joints[3].global_transform) and race_rig.skeleton.get_bone_global_pose(6).basis.get_scale().y<.11,"Head turns and independent eye blinks reach the skin bones")
	check(game.travel.race.actor_rigs.values().filter(func(actor): return actor.snack!=null).all(func(actor): return actor.snack.find_children("*","GeometryInstance3D",true,false).any(func(art): return art.layers!=0)),"Held drinks and sandwiches retain their separate visible art")
	check(game.railway.driver.find_children("*","GeometryInstance3D",true,false).filter(func(part): return part.get_meta("blend_accessory",false)).all(func(part): return part.layers!=0),"The conductor keeps his separate cap and moustache")
	game.town.set_process(false)
	game.truck.freeze=true
	game.truck.set_physics_process(false)
	rig.toy.get_node("ArmLeft").rotation.z=-.12
	rig.toy.get_node("ArmRight").rotation.z=.12
	rig.toy.rotation.y=PI
	rig._update_pose()
	var focus:=TownLayout.MAYA+Vector3(1,1,-1)
	game.camera.position=focus+Vector3(12,12,16)
	game.camera.look_at(focus)
	game.camera.size=22
	await capture("maple-25")
	blending.set_strength(0)
	await capture("maple-original")
	blending.set_strength(25)
	game.paused=true
	game.hud.pause_panel.show()
	await capture("pause-selector")
	game.queue_free()
	await process_frame
	var study: Node3D=load("res://scenes/model_blend_preview.tscn").instantiate()
	root.add_child(study)
	check(ToyBlending.OPTIONS[roundi(study.slider.value)]==25,"The comparison starts at the requested 25%")
	await capture("study-25")
	study.slider.value=ToyBlending.OPTIONS.find(10)
	var palette: OptionButton=study.find_children("*","OptionButton",true,false)[0]
	palette.select(1)
	palette.item_selected.emit(1)
	check(study.study_rigs[0].model=="tree1" and study.study_rigs.all(func(item): return item.strength==10),"The comparison switches to the golden tree with the new 10% strength")
	study.slider.value=ToyBlending.OPTIONS.find(15)
	await capture("study-golden-15")
	check(study.study_rigs.all(func(item): return item.strength==15),"The comparison offers 15% for the golden tree, person and hydrant")
	for child in study.get_children():
		if child is Node3D and child.get_node_or_null("ArmLeft"):
			child.get_node("ArmLeft").rotation.z=-2.65
			child.get_node("ArmRight").rotation.z=2.65
	study.study_rigs[1]._update_pose()
	await capture("study-raised-arms")
	study.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
