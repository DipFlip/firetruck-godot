class_name ToyModels
extends RefCounted

# Sculpted toy upgrades for characters, pets, birds, ducks and winter animals.
# Keeps the chunky painted-wood / satin-vinyl aesthetic, existing joint names,
# and ToyBlendRig compatibility (via blend_accessory metadata).

static var capsule_meshes: Dictionary = {}
static var torus_meshes: Dictionary = {}

static func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var key := Vector2(radius, height)
	if not capsule_meshes.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 16
		mesh.rings = 6
		capsule_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = capsule_meshes[key]
	node.material_override = TownProps.material(color)
	parent.add_child(node)
	node.position = pos
	return node

static func _torus(parent: Node3D, pos: Vector3, inner: float, outer: float, color: Color) -> MeshInstance3D:
	var key := Vector2(inner, outer)
	if not torus_meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 20
		mesh.ring_segments = 10
		torus_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = torus_meshes[key]
	node.material_override = TownProps.material(color)
	parent.add_child(node)
	node.position = pos
	return node

static func _clear_mesh_children(root: Node3D) -> void:
	for child in root.get_children():
		if child is MeshInstance3D or child.get_meta("toy_sculpt", false):
			root.remove_child(child)
			child.queue_free()

static func _mark_accessory(node: Node3D) -> Node3D:
	node.set_meta("blend_accessory", true)
	node.set_meta("toy_sculpt", true)
	return node

# Dress any person with expressive eyebrows/cheeks/reaction mouth, collars/cuffs
# and character-specific hair, glasses, hats or scarves.
static func dress_person(person: Node3D, style: String = "default", accent: Color = Color.TRANSPARENT) -> void:
	if not is_instance_valid(person) or person.has_node("OutfitDetails"): return
	var head_parent: Node3D = person.get_node_or_null("HeadPivot")
	var head_offset := Vector3(0, 1.94, 0) - (head_parent.position if head_parent else Vector3.ZERO)
	if head_parent == null: head_parent = person

	var head_details := _mark_accessory(Node3D.new())
	head_details.name = "HeadDetails"
	head_parent.add_child(head_details)
	head_details.position = head_offset

	var outfit := _mark_accessory(Node3D.new())
	outfit.name = "OutfitDetails"
	person.add_child(outfit)

	# Detect base colours from the person's existing parts.
	var shirt := Color("ecb354")
	var skin := Color("d9a17b")
	var hair := Color("694f3f")
	var inv := person.global_transform.affine_inverse()
	for part: MeshInstance3D in person.find_children("*", "MeshInstance3D", true, false):
		var mat := part.get_active_material(0) as StandardMaterial3D
		if not mat: continue
		var at: Vector3 = inv * part.global_position
		if at.distance_to(Vector3(0, 1.03, 0)) < 0.05: shirt = mat.albedo_color
		elif part.name == "Head": skin = mat.albedo_color
		elif at.distance_to(Vector3(0, 2.29, 0.06)) < 0.05: hair = mat.albedo_color
	if accent.a <= 0.0: accent = shirt.lightened(0.22)

	# Expressive eyebrows, rosy cheek dots and hidden reaction mouth ("O" / grin).
	var brow_color := hair.darkened(0.18)
	var brows := Node3D.new()
	brows.name = "Eyebrows"
	head_details.add_child(brows)
	for side in [-1, 1]:
		var brow := _capsule(brows, Vector3(side * 0.205, 0.165, -0.415), 0.026, 0.15, brow_color)
		brow.rotation.z = PI * 0.5 + side * 0.10
		# Soft rosy cheek blush dots.
		var cheek := TownProps.ball(head_details, Vector3(side * 0.305, -0.095, -0.365), Vector3(0.125, 0.085, 0.05), Color("e28d81"))
		cheek.rotation.y = side * 0.48
	var mouth_open := TownProps.ball(head_details, Vector3(0, -0.255, -0.425), Vector3(0.15, 0.14, 0.06), Color("7d3d3b"))
	mouth_open.name = "MouthOpen"
	mouth_open.visible = false

	# Soft collar / neck transition so the head sits naturally on the torso.
	_torus(outfit, Vector3(0, 1.49, 0), 0.17, 0.285, accent if style not in ["elsa", "astrid", "nora", "winter_skater", "winter_villager"] else Color("f0e6d2"))
	# Subtle boot sole rims for grounded toy feet.
	for side in [-1, 1]:
		var leg_parent: Node3D = person.get_node_or_null("LegLeft" if side < 0 else "LegRight")
		var boot_rim := _mark_accessory(TownProps.ball(leg_parent if leg_parent else outfit, Vector3(0 if leg_parent else side * 0.22, -0.66 if leg_parent else 0.055, -0.12), Vector3(0.40, 0.08, 0.60), Color("4f4239")))
		boot_rim.name = "BootSole" + ("L" if side < 0 else "R")
		var arm: Node3D = person.get_node_or_null("ArmLeft" if side < 0 else "ArmRight")
		if arm:
			var cuff := _mark_accessory(_torus(arm, Vector3(0, -0.48, 0), 0.095, 0.165, shirt.lightened(0.16)))
			cuff.name = "SleeveCuff"

	# Style-specific sculpted headgear, hair silhouettes, glasses and clothes.
	match style:
		"maya":
			# Auburn bob side curls and cosy raincoat pockets.
			for side in [-1, 1]:
				var curl := _capsule(head_details, Vector3(side * 0.44, -0.02, 0.08), 0.145, 0.50, hair)
				curl.rotation.z = side * 0.16
			TownProps.ball(head_details, Vector3(0, 0.05, 0.40), Vector3(0.76, 0.56, 0.30), hair)
			for side in [-1, 1]:
				TownProps.box(outfit, Vector3(side * 0.26, 0.78, -0.27), Vector3(0.18, 0.14, 0.06), shirt.darkened(0.12))
		"leo":
			# Round dark glasses, curly hair tufts, neat beard and barbecue apron.
			_add_glasses(head_details, Color("3c474d"))
			for p in [Vector3(-0.26, 0.50, -0.10), Vector3(0.0, 0.55, -0.06), Vector3(0.26, 0.50, -0.10), Vector3(-0.34, 0.42, 0.18), Vector3(0.34, 0.42, 0.18)]:
				TownProps.ball(head_details, p, Vector3(0.27, 0.23, 0.25), hair)
			TownProps.ball(head_details, Vector3(0, -0.34, -0.25), Vector3(0.58, 0.34, 0.36), hair)
			TownProps.box(outfit, Vector3(0, 0.90, -0.30), Vector3(0.56, 0.58, 0.07), Color("c96f55"))
			_torus(outfit, Vector3(0, 0.94, 0.02), 0.36, 0.44, Color("c96f55"))
		"june":
			# Round green glasses and pearl cardigan collar.
			_add_glasses(head_details, Color("5a8d73"))
			for i in 5:
				var a := -0.7 + i * 0.35
				TownProps.ball(outfit, Vector3(sin(a) * 0.27, 1.46, -cos(a) * 0.24), Vector3.ONE * 0.075, Color("f6efdf"))
		"oliver":
			# Wavy sandy hair sweep and crisp cream polo collar.
			var sweep := _capsule(head_details, Vector3(0.08, 0.48, -0.16), 0.16, 0.56, hair)
			sweep.rotation = Vector3(0.18, 0.2, PI * 0.46)
			for side in [-1, 1]:
				var lapel := TownProps.box(outfit, Vector3(side * 0.17, 1.43, -0.25), Vector3(0.16, 0.10, 0.07), Color("f4ecd8"))
				lapel.rotation.z = -side * 0.35
		"rowan":
			# Subtle brass collar kerchief (keeps Rowan's separate cap & moustache).
			_torus(outfit, Vector3(0, 1.47, 0), 0.19, 0.30, Color("d9b579"))
		"kit":
			_add_cap(head_details, Color("d47157"), Color("f3e5c7"))
			_torus(outfit, Vector3(0, 0.78, 0), 0.37, 0.45, Color("4b5a64"))
		"sami":
			_add_cap(head_details, Color("eee2c5"), Color("c86b56"))
			TownProps.box(outfit, Vector3(0, 0.92, -0.30), Vector3(0.56, 0.56, 0.07), Color("f1e6cd"))
		"nora":
			_add_beanie(head_details, Color("c5807b"), Color("f3e8d2"))
			_add_scarf(outfit, Color("e6c17b"))
		"quinn":
			_add_cap(head_details, Color("cd7058"), Color("f4e5be"))
			for side in [-1, 1]:
				_torus(head_details, Vector3(side * 0.18, 0.38, -0.40), 0.06, 0.11, Color("3c5664")).rotation.x = PI * 0.5
		"piper":
			_add_cap(head_details, Color("405b67"), Color("f4e5be"))
			_torus(outfit, Vector3(0, 1.44, 0), 0.18, 0.29, Color("cd7058"))
		"elsa":
			_add_beanie(head_details, Color("4f949a"), Color("f4ebd8"))
			_add_scarf(outfit, Color("d97762"))
			for side in [-1, 1]:
				var hair_tail := _capsule(head_details, Vector3(side * 0.43, -0.08, 0.14), 0.12, 0.48, hair)
				hair_tail.rotation.z = side * 0.14
		"bram":
			TownProps.ball(head_details, Vector3(0, -0.32, -0.25), Vector3(0.64, 0.40, 0.40), Color("c5c3b8"))
			TownProps.ball(head_details, Vector3(0, -0.19, -0.40), Vector3(0.38, 0.13, 0.14), Color("b8b6ab"))
			_torus(outfit, Vector3(0, 1.48, 0), 0.20, 0.32, Color("b84b44"))
			_torus(outfit, Vector3(0, 0.74, 0), 0.39, 0.48, Color("3f6853"))
		"astrid":
			_add_earmuffs(head_details, Color("d9a34a"), Color("b88233"))
			_add_scarf(outfit, Color("efe3c9"))
			for side in [-1, 1]:
				var braid := _capsule(head_details, Vector3(side * 0.38, -0.22, 0.18), 0.11, 0.54, hair)
				braid.rotation.z = side * 0.18
		"torsten":
			_add_beanie(head_details, Color("354c63"), Color("354c63"), false)
			for side in [-1, 1]:
				TownProps.ball(head_details, Vector3(side * 0.12, -0.17, -0.42), Vector3(0.24, 0.095, 0.08), Color("cfa060"))
			_torus(outfit, Vector3(0, 1.48, 0), 0.20, 0.36, Color("f3ead6"))
			_torus(outfit, Vector3(0, 0.72, 0), 0.39, 0.49, Color("f3ead6"))
		"winter_skater", "winter_villager":
			if int(absf(person.position.x * 7 + person.position.z * 13)) % 2 == 0:
				_add_beanie(head_details, accent, Color("f4ecd8"))
			else:
				_add_earmuffs(head_details, accent, accent.darkened(0.22))
			_add_scarf(outfit, accent.lightened(0.18))
		"spectator":
			var variant := int(absf(person.position.x * 11 + person.position.z * 5)) % 4
			if variant == 0: _add_cap(head_details, Color("d47157"), Color("f3e5c7"))
			elif variant == 1: _add_cap(head_details, Color("5c8fa3"), Color("f3e5c7"))
			elif variant == 2:
				for side in [-1, 1]:
					_capsule(head_details, Vector3(side * 0.43, -0.02, 0.10), 0.13, 0.42, hair)
		"operator":
			_add_cap(head_details, Color("3b525c"), Color("3b525c"))
			_add_earmuffs(head_details, Color("3a474f"), Color("2a343b"))
		_:
			var variant := int(absf(person.position.x * 9 + person.position.z * 7)) % 4
			if variant == 0: _add_cap(head_details, shirt.darkened(0.18), Color("f1e5ca"))
			elif variant == 1: _add_scarf(outfit, shirt.lightened(0.24))
			elif variant == 2:
				for side in [-1, 1]:
					_capsule(head_details, Vector3(side * 0.43, -0.02, 0.10), 0.13, 0.42, hair)

	TownProps.soften_toy_shine(head_details)
	TownProps.soften_toy_shine(outfit)

static func _add_glasses(head: Node3D, frame_color: Color) -> void:
	for side in [-1, 1]:
		var rim := _torus(head, Vector3(side * 0.205, 0.04, -0.435), 0.095, 0.125, frame_color)
		rim.rotation.x = PI * 0.5
	TownProps.box(head, Vector3(0, 0.04, -0.44), Vector3(0.14, 0.03, 0.03), frame_color)

static func _add_cap(head: Node3D, crown: Color, trim: Color) -> void:
	TownProps.ball(head, Vector3(0, 0.39, 0.04), Vector3(1.06, 0.48, 0.96), crown)
	var brim := TownProps.ball(head, Vector3(0, 0.26, -0.42), Vector3(0.84, 0.10, 0.52), trim)
	brim.rotation.x = 0.14
	TownProps.ball(head, Vector3(0, 0.62, 0.04), Vector3.ONE * 0.12, trim)

static func _add_beanie(head: Node3D, knit: Color, pom: Color, with_pom: bool = true) -> void:
	TownProps.ball(head, Vector3(0, 0.40, 0.04), Vector3(1.08, 0.58, 0.98), knit)
	var cuff := _torus(head, Vector3(0, 0.24, 0.04), 0.39, 0.54, knit.lightened(0.12))
	cuff.scale = Vector3(1.0, 1.35, 0.92)
	if with_pom:
		TownProps.ball(head, Vector3(0, 0.72, 0.08), Vector3.ONE * 0.28, pom)

static func _add_earmuffs(head: Node3D, fluff: Color, band: Color) -> void:
	var arch := _torus(head, Vector3(0, 0.12, 0.02), 0.46, 0.52, band)
	arch.rotation.x = PI * 0.5
	for side in [-1, 1]:
		TownProps.ball(head, Vector3(side * 0.53, 0.0, 0.02), Vector3(0.24, 0.30, 0.28), fluff)

static func _add_scarf(outfit: Node3D, color: Color) -> void:
	_torus(outfit, Vector3(0, 1.48, 0), 0.20, 0.36, color)
	var tail := TownProps.box(outfit, Vector3(0.16, 1.18, -0.32), Vector3(0.19, 0.46, 0.09), color)
	tail.rotation.z = 0.12
	var tail2 := TownProps.box(outfit, Vector3(-0.04, 1.24, -0.33), Vector3(0.17, 0.34, 0.08), color.darkened(0.08))
	tail2.rotation.z = -0.08

static func set_face_reaction(person: Node3D, active: bool, happy: bool = false) -> void:
	if not is_instance_valid(person): return
	var details := person.find_child("HeadDetails", true, false)
	if not details: return
	var mouth := details.get_node_or_null("MouthOpen")
	if mouth:
		mouth.visible = active
		mouth.scale = Vector3(0.20, 0.11, 0.06) if happy else Vector3(0.14, 0.17, 0.06)
	var brows := details.get_node_or_null("Eyebrows")
	if brows:
		brows.position.y = (0.065 if not happy else 0.045) if active else 0.0

# Sculpted toy Pippin (cat): preserves 4 MeshInstance3D paws at y=0.2 for ladder climbing.
static func upgrade_cat(cat: Node3D) -> void:
	if not is_instance_valid(cat) or cat.get_meta("toy_upgraded", false): return
	cat.set_meta("toy_upgraded", true)
	_clear_mesh_children(cat)
	var fur := Color("edc382")
	var cream := Color("f8ebd0")
	var pink := Color("e8a19c")
	var collar := Color("569da3")

	# Arched plush toy body + soft cream chest bib.
	TownProps.ball(cat, Vector3(0, 0.54, 0.04), Vector3(0.52, 0.56, 0.96), fur)
	TownProps.ball(cat, Vector3(0, 0.48, -0.34), Vector3(0.38, 0.40, 0.36), cream)
	# Rounded paws at y = 0.20 so game.gd automatically collects them into cat_paws.
	for x in [-0.17, 0.17]:
		for z in [-0.28, 0.28]:
			var paw := _capsule(cat, Vector3(x, 0.20, z), 0.095, 0.40, fur)
			paw.name = "CatPaw"
			TownProps.ball(paw, Vector3(0, -0.14, -0.04), Vector3(0.17, 0.10, 0.22), cream)

	# Collar + little gold bell.
	_torus(cat, Vector3(0, 0.67, -0.34), 0.15, 0.22, collar).rotation.x = 0.45
	TownProps.ball(cat, Vector3(0, 0.55, -0.52), Vector3.ONE * 0.12, Color("f0c659"))

	# Sculpted head, muzzle cushions, pink nose, expressive eyes and pink-lined ears.
	var head := Node3D.new()
	head.name = "CatHead"
	head.set_meta("toy_sculpt", true)
	cat.add_child(head)
	head.position = Vector3(0, 0.88, -0.42)
	TownProps.ball(head, Vector3.ZERO, Vector3(0.62, 0.56, 0.56), fur)
	for side in [-1, 1]:
		# Pointed ear + pink inner ear.
		var ear := TownProps.cylinder(head, Vector3(side * 0.20, 0.30, 0.02), 0.13, 0.26, fur, 0.02)
		ear.rotation.z = -side * 0.20
		var inner := TownProps.cylinder(head, Vector3(side * 0.19, 0.29, -0.03), 0.075, 0.18, pink, 0.015)
		inner.rotation.z = -side * 0.20
		# Glossy eye + white catchlight.
		TownProps.ball(head, Vector3(side * 0.14, 0.05, -0.25), Vector3(0.105, 0.125, 0.06), Color("283f46"))
		TownProps.ball(head, Vector3(side * 0.14 - 0.02, 0.08, -0.285), Vector3.ONE * 0.032, Color("fff5dc"))
		# Muzzle cheek cushions.
		TownProps.ball(head, Vector3(side * 0.075, -0.07, -0.25), Vector3(0.16, 0.12, 0.12), cream)
	TownProps.ball(head, Vector3(0, -0.02, -0.30), Vector3(0.08, 0.06, 0.05), pink)

	# Curved upright S-tail.
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.set_meta("toy_sculpt", true)
	cat.add_child(tail)
	tail.position = Vector3(0, 0.62, 0.44)
	var seg1 := _capsule(tail, Vector3(0, 0.16, 0.14), 0.075, 0.42, fur)
	seg1.rotation.x = 0.72
	var seg2 := _capsule(tail, Vector3(0, 0.42, 0.24), 0.07, 0.38, fur)
	seg2.rotation.x = -0.18
	TownProps.ball(tail, Vector3(0, 0.58, 0.20), Vector3(0.14, 0.14, 0.14), cream)
	TownProps.soften_toy_shine(cat)

# Sculpted toy Biscuit (dog) with floppy ears, wagging tail, snout and gradual mud spots.
static func upgrade_dog(dog: Node3D) -> void:
	if not is_instance_valid(dog) or dog.get_meta("toy_upgraded", false): return
	dog.set_meta("toy_upgraded", true)
	_clear_mesh_children(dog)
	var muddy := Color("876445")
	var dark_mud := Color("694b33")
	var fur_parts: Array[MeshInstance3D] = []
	var mud_parts: Array[MeshInstance3D] = []

	# Plump puppy body + chest.
	fur_parts.append(TownProps.ball(dog, Vector3(0, 0.54, 0.04), Vector3(0.84, 0.72, 1.32), muddy))
	fur_parts.append(TownProps.ball(dog, Vector3(0, 0.50, -0.46), Vector3(0.62, 0.56, 0.54), muddy))
	# Rounded stubby legs with cute paws.
	for x in [-0.24, 0.24]:
		for z in [-0.36, 0.36]:
			var leg := _capsule(dog, Vector3(x, 0.23, z), 0.125, 0.46, muddy)
			fur_parts.append(leg)
			fur_parts.append(TownProps.ball(dog, Vector3(x, 0.08, z - 0.06), Vector3(0.24, 0.14, 0.30), muddy))

	# Coral collar + gold ID tag.
	_torus(dog, Vector3(0, 0.72, -0.46), 0.21, 0.30, Color("d46b57")).rotation.x = 0.42
	TownProps.ball(dog, Vector3(0, 0.56, -0.71), Vector3.ONE * 0.14, Color("efc660"))

	# Sculpted head with snout, button nose, tiny pink tongue and floppy ears.
	var head := Node3D.new()
	head.name = "DogHead"
	head.set_meta("toy_sculpt", true)
	dog.add_child(head)
	head.position = Vector3(0, 0.90, -0.58)
	fur_parts.append(TownProps.ball(head, Vector3.ZERO, Vector3(0.68, 0.62, 0.64), muddy))
	fur_parts.append(TownProps.ball(head, Vector3(0, -0.08, -0.32), Vector3(0.38, 0.28, 0.36), muddy))
	TownProps.ball(head, Vector3(0, -0.02, -0.49), Vector3(0.16, 0.12, 0.11), Color("2d3134"))
	var tongue := TownProps.ball(head, Vector3(0, -0.19, -0.42), Vector3(0.12, 0.13, 0.06), Color("e58486"))
	tongue.rotation.x = -0.32
	for side in [-1, 1]:
		TownProps.ball(head, Vector3(side * 0.17, 0.08, -0.28), Vector3(0.11, 0.13, 0.06), Color("26353b"))
		TownProps.ball(head, Vector3(side * 0.17 - 0.02, 0.11, -0.315), Vector3.ONE * 0.036, Color("fff4db"))
		# Pivoted floppy ears.
		var ear := Node3D.new()
		ear.name = "EarLeft" if side < 0 else "EarRight"
		head.add_child(ear)
		ear.position = Vector3(side * 0.30, 0.14, 0.02)
		var flap := _capsule(ear, Vector3(side * 0.06, -0.17, 0.02), 0.12, 0.42, Color("6c4d35"))
		flap.rotation.z = side * 0.28
		flap.scale = Vector3(0.75, 1.0, 1.15)
		fur_parts.append(flap)

	# Pivoted wagging tail.
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.set_meta("toy_sculpt", true)
	dog.add_child(tail)
	tail.position = Vector3(0, 0.72, 0.58)
	var wag := _capsule(tail, Vector3(0, 0.18, 0.16), 0.095, 0.46, muddy)
	wag.rotation.x = 0.78
	fur_parts.append(wag)

	# Mud patches that shrink away as the player washes Biscuit.
	for spec in [
		[Vector3(0.32, 0.62, 0.05), Vector3(0.28, 0.24, 0.38)],
		[Vector3(-0.30, 0.56, 0.22), Vector3(0.26, 0.24, 0.32)],
		[Vector3(0.10, 0.82, 0.14), Vector3(0.32, 0.18, 0.36)],
		[Vector3(-0.18, 0.66, -0.22), Vector3(0.26, 0.22, 0.28)],
		[Vector3(0.22, 0.32, -0.36), Vector3(0.22, 0.22, 0.22)],
		[Vector3(-0.24, 0.30, 0.36), Vector3(0.22, 0.22, 0.22)],
	]:
		var spot := TownProps.ball(dog, spec[0], spec[1], dark_mud)
		spot.set_meta("mud_base_scale", spec[1])
		mud_parts.append(spot)

	dog.set_meta("dog_fur_parts", fur_parts)
	dog.set_meta("dog_mud_parts", mud_parts)
	TownProps.soften_toy_shine(dog)

static func set_dog_clean(dog: Node3D, progress: float) -> void:
	if not is_instance_valid(dog): return
	var p := clampf(progress, 0.0, 1.0)
	var coat := Color("876445").lerp(Color("e9c58b"), p)
	var ear_coat := Color("6c4d35").lerp(Color("cf9c61"), p)
	var fur_parts: Array = dog.get_meta("dog_fur_parts", [])
	for part in fur_parts:
		if not is_instance_valid(part): continue
		var is_ear := part.get_parent() != null and str(part.get_parent().name).begins_with("Ear")
		part.material_override = TownProps.material(ear_coat if is_ear else coat)
	var mud_parts: Array = dog.get_meta("dog_mud_parts", [])
	for spot in mud_parts:
		if not is_instance_valid(spot): continue
		var base: Vector3 = spot.get_meta("mud_base_scale", Vector3.ONE * 0.2)
		spot.visible = p < 0.96
		spot.scale = base * maxf(0.01, 1.0 - p * 1.05)

# Upgraded sculpted songbird keeping exact TownLife dictionary keys and animation poses.
static func build_bird(parent: Node3D, index: int, winter: bool = false) -> Dictionary:
	var palettes: Array[Dictionary] = [
		{"back": Color("647b7c"), "belly": Color("efe6cf"), "head": Color("e6dec5"), "wing": Color("d0d6c2"), "tip": Color("475d63"), "beak": Color("d9a354")},
		{"back": Color("7d6658"), "belly": Color("e2855e"), "head": Color("70584b"), "wing": Color("9b8373"), "tip": Color("54423a"), "beak": Color("d7a14f")},
		{"back": Color("5c8294"), "belly": Color("e9d48b"), "head": Color("4b6f82"), "wing": Color("7fa5b5"), "tip": Color("3d5664"), "beak": Color("d8a457")},
	]
	if winter:
		palettes = [
			{"back": Color("c94e45"), "belly": Color("df665b"), "head": Color("bf433b"), "wing": Color("9e3833"), "tip": Color("3b3332"), "beak": Color("e8a649")},
			{"back": Color("d9e4e8"), "belly": Color("f6f9fa"), "head": Color("eef3f5"), "wing": Color("9eb4be"), "tip": Color("566e79"), "beak": Color("df9f4f")},
			{"back": Color("5e8094"), "belly": Color("f0e8d4"), "head": Color("4d6d82"), "wing": Color("7c9fb0"), "tip": Color("3a5160"), "beak": Color("e0a454")},
		]
	var pal: Dictionary = palettes[index % palettes.size()]
	var bird := Node3D.new()
	bird.set_meta("toy_arrival", "fade")
	parent.add_child(bird)
	var body := Node3D.new()
	bird.add_child(body)
	# Plump teardrop body + soft contrasting breast patch + layered fanned tail.
	TownProps.ball(body, Vector3(0, 0.175, 0.03), Vector3(0.24, 0.27, 0.39), pal.back)
	TownProps.ball(body, Vector3(0, 0.145, -0.025), Vector3(0.21, 0.22, 0.30), pal.belly)
	for side in [-1, 0, 1]:
		var tail := TownProps.ball(body, Vector3(side * 0.042, 0.16, 0.25), Vector3(0.085, 0.045, 0.22), pal.tip if side == 0 else pal.back)
		tail.rotation = Vector3(0.28, side * 0.18, 0)
	# Sculpted head with tiny crest, conical tapered beak and gleaming eyes.
	var head := Node3D.new()
	body.add_child(head)
	head.position = Vector3(0, 0.21, -0.10)
	TownProps.ball(head, Vector3(0, 0.035, -0.06), Vector3(0.195, 0.195, 0.22), pal.head)
	var crest := TownProps.cylinder(head, Vector3(0, 0.135, -0.02), 0.055, 0.09, pal.back, 0.01)
	crest.rotation.x = 0.45
	var beak := TownProps.cylinder(head, Vector3(0, 0.01, -0.185), 0.036, 0.115, pal.beak, 0.006)
	beak.rotation.x = -PI * 0.5
	for side in [-1, 1]:
		TownProps.ball(head, Vector3(side * 0.082, 0.06, -0.125), Vector3(0.038, 0.042, 0.036), Color("233742"))
		TownProps.ball(head, Vector3(side * 0.086, 0.072, -0.142), Vector3.ONE * 0.014, Color("fff7e3"))
	var legs: Array[Node3D] = []
	for side in [-1, 1]:
		var leg := Node3D.new()
		bird.add_child(leg)
		leg.position = Vector3(side * 0.055, 0.06, 0.035)
		_capsule(leg, Vector3.ZERO, 0.014, 0.10, pal.beak)
		for toe in [-0.25, 0.0, 0.25]:
			var foot := _capsule(leg, Vector3(toe * 0.05, -0.048, -0.025), 0.011, 0.065, pal.beak)
			foot.rotation = Vector3(PI * 0.5, toe, 0)
		legs.append(leg)
	var wings: Array[Node3D] = []
	var feathers: Array[MeshInstance3D] = []
	for side in [-1, 1]:
		var wing := Node3D.new()
		body.add_child(wing)
		wing.position = Vector3(side * 0.11, 0.185, 0.0)
		var feather := TownProps.ball(wing, Vector3(side * 0.20, 0, 0), Vector3(0.45, 0.05, 0.22), pal.wing)
		var tip := TownProps.ball(feather, Vector3(side * 0.26, 0.02, 0.04), Vector3(0.46, 0.92, 0.85), pal.tip)
		tip.name = "WingTip"
		feathers.append(feather)
		wings.append(wing)
	TownProps.soften_toy_shine(bird)
	return {"node": bird, "body": body, "head": head, "legs": legs, "wings": wings, "feathers": feathers, "phase": index * 0.48, "open": 1.0}

# Upgraded chunky wooden/vinyl toy pond duck with tucked wings, upturned tail and crest.
static func build_duck(parent: Node3D, at: Vector3, index: int) -> Node3D:
	var mallard := index % 3 == 1
	var body_col := Color("d6cbb4") if mallard else Color("efc86c")
	var head_col := Color("4f846b") if mallard else Color("efc86c")
	var wing_col := Color("8b7d69") if mallard else Color("e0b355")
	var bill_col := Color("e0964a")
	var duck := TownProps.toy_group(parent, at, "drop", "SwimmingDuck")
	# Plump curved body + upturned tail tuft.
	TownProps.ball(duck, Vector3(0, 0.02, 0.02), Vector3(0.86, 0.56, 1.02), body_col)
	var tail := TownProps.cylinder(duck, Vector3(0, 0.18, 0.48), 0.16, 0.30, wing_col, 0.04)
	tail.rotation.x = 0.72
	# Tucked sculpted wings on each flank.
	for side in [-1, 1]:
		var wing := TownProps.ball(duck, Vector3(side * 0.39, 0.08, 0.08), Vector3(0.22, 0.34, 0.62), wing_col)
		wing.rotation = Vector3(-0.14, side * 0.16, -side * 0.18)
	# Neck + rounded head + tiny crest + wide rounded bill + eyes with glint.
	if mallard:
		_torus(duck, Vector3(0, 0.24, -0.24), 0.12, 0.18, Color("f4efe3"))
	TownProps.ball(duck, Vector3(0, 0.36, -0.28), Vector3(0.46, 0.46, 0.48), head_col)
	TownProps.ball(duck, Vector3(0, 0.59, -0.24), Vector3(0.12, 0.12, 0.18), head_col)
	TownProps.ball(duck, Vector3(0, 0.31, -0.58), Vector3(0.28, 0.12, 0.30), bill_col)
	for side in [-1, 1]:
		TownProps.ball(duck, Vector3(side * 0.18, 0.41, -0.42), Vector3(0.085, 0.095, 0.065), Color("28383f"))
		TownProps.ball(duck, Vector3(side * 0.19, 0.435, -0.45), Vector3.ONE * 0.028, Color("fff7e3"))
	TownProps.soften_toy_shine(duck)
	return duck

# Adorable chunky toy Snowy Owl for the Frostpine Hollow ladder rescue!
static func build_owl(parent: Node3D, at: Vector3) -> Node3D:
	var owl := Node3D.new()
	owl.name = "SnowyOwl"
	owl.set_meta("toy_arrival", "drop")
	owl.set_meta("toy_kind", "Animal")
	parent.add_child(owl)
	owl.position = at
	var white := Color("f2f5f7")
	var frost := Color("d5e0e6")
	var amber := Color("e4a246")
	var scarf := Color("d46252")

	# Plump owl torso + snowy belly + little frost speckles.
	TownProps.ball(owl, Vector3(0, 0.56, 0.0), Vector3(0.68, 0.78, 0.62), white)
	TownProps.ball(owl, Vector3(0, 0.48, -0.14), Vector3(0.50, 0.56, 0.44), Color("fafcfd"))
	for speck in [Vector3(-0.14, 0.56, -0.32), Vector3(0.14, 0.54, -0.32), Vector3(0.0, 0.42, -0.34), Vector3(-0.12, 0.36, -0.30), Vector3(0.12, 0.36, -0.30)]:
		TownProps.ball(owl, speck, Vector3(0.08, 0.05, 0.04), frost)
	# Flappable tucked wings.
	for side in [-1, 1]:
		var wing := Node3D.new()
		wing.name = "WingLeft" if side < 0 else "WingRight"
		owl.add_child(wing)
		wing.position = Vector3(side * 0.31, 0.66, 0.02)
		var feather := TownProps.ball(wing, Vector3(side * 0.05, -0.18, 0.03), Vector3(0.20, 0.54, 0.44), frost)
		feather.rotation.z = side * 0.14
	# Cozy winter scarf around the owl's neck.
	_torus(owl, Vector3(0, 0.84, 0.0), 0.18, 0.30, scarf)
	var scarf_end := TownProps.box(owl, Vector3(0.18, 0.66, -0.25), Vector3(0.14, 0.32, 0.07), scarf)
	scarf_end.rotation.z = 0.20
	# Big round owl head, ear tufts, facial disc, golden-rimmed eyes and amber beak.
	TownProps.ball(owl, Vector3(0, 1.06, -0.02), Vector3(0.64, 0.54, 0.56), white)
	for side in [-1, 1]:
		var tuft := TownProps.cylinder(owl, Vector3(side * 0.24, 1.32, 0.02), 0.09, 0.18, frost, 0.015)
		tuft.rotation.z = -side * 0.35
		TownProps.ball(owl, Vector3(side * 0.15, 1.08, -0.25), Vector3(0.19, 0.19, 0.06), amber)
		TownProps.ball(owl, Vector3(side * 0.15, 1.08, -0.285), Vector3(0.115, 0.125, 0.05), Color("243038"))
		TownProps.ball(owl, Vector3(side * 0.15 - 0.025, 1.11, -0.31), Vector3.ONE * 0.036, Color("fff7e3"))
	var beak := TownProps.cylinder(owl, Vector3(0, 0.99, -0.32), 0.065, 0.14, amber, 0.01)
	beak.rotation.x = -PI * 0.44
	# Little clawed feet at y = 0.20.
	for side in [-1, 1]:
		var foot := _capsule(owl, Vector3(side * 0.15, 0.20, -0.04), 0.065, 0.20, amber)
		foot.name = "OwlFoot"
		foot.rotation.x = PI * 0.5
	var tail := TownProps.ball(owl, Vector3(0, 0.34, 0.30), Vector3(0.32, 0.12, 0.28), frost)
	tail.rotation.x = 0.45
	TownProps.soften_toy_shine(owl)
	return owl
