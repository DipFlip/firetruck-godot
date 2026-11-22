class_name ToyWinterVillage
extends Node3D

# Third play-mat world: Frostpine Hollow.
# Reached through Maple Bay's east road exit; returns to Maple Bay via its west
# road exit. Features spray-to-ice slippery driving physics and four missions:
#   1. Freeze the village skating rink (Elsa)
#   2. Cool the runaway cocoa-lodge bonfire (Bram)
#   3. Rescue Snowball the snowy owl with the telescopic ladder (Astrid)
#   4. Freeze an icy lane and slide the heavy supply sled into place (Torsten)

const ORIGIN := Vector3(800, 0, 0)
const SPAWN := Vector3(-73, 0.855, 0)
const RINK_CENTER := Vector3(-28, 0, -24)
const RINK_SIZE := Vector2(18.0, 14.0)
const BONFIRE_POS := Vector3(36, 0, -26)
const OWL_TREE := Vector3(36, 0, 32)
const OWL_BRANCH := Vector3(36, 3.65, 30.6)
const OWL_PERCH := Vector3(36, 3.78, 29.2)
const SLED_START := Vector3(-24, 0.14, 34)
const SLED_GOAL := Vector3(10, 0, 34)
const NAMES: Array[String] = ["ELSA", "BRAM", "ASTRID", "TORSTEN"]
const HYDRANT_POINTS: Array[Vector3] = [Vector3(-50, 0.1, -8), Vector3(12, 0.1, -7)]

var game: Node3D
var mat: RollingMat
var ice_field: IceField
var active := false
var animation_clock := 0.0
var props: Array[BreakableProp] = []
var hydrants: Array[BreakableProp] = []
var suspended_bodies: Array[Dictionary] = []
var people: Array[Node3D] = []
var actor_rigs: Dictionary = {}
var walkers: Array[Dictionary] = []
var skaters: Array[Node3D] = []
var chatter_latches: Dictionary = {}

# Mission 1: Skating Rink
var rink_tiles: Array[Dictionary] = []
var rink_progress := 0.0
var rink_done := false

# Mission 2: Cocoa Lodge Bonfire
var bonfire_fire: ToyFire
var bonfire_done := false

# Mission 3: Snowy Owl Ladder Rescue
var owl: Node3D
var owl_home := Vector3.ZERO
var owl_ladder_event: LadderEvent
var owl_rescue_running := false
var owl_rescued := false
var owl_rescue_tween: Tween
var owl_tree_prop: BreakableProp

# Mission 4: Heavy Supply Sled on Ice Lane
var sled: RigidBody3D
var sled_goal_ring: MeshInstance3D
var sled_done := false
var sled_pushed_dry := false
var sled_slip := 0.0

# Ambient winter wildlife & snowfall
var birds: Array[Dictionary] = []
var ground_birds: Array[Dictionary] = []
var snow_batch: MultiMeshInstance3D
var snow_motes: Array[Dictionary] = []
var owl_hoot_timer := 5.0

func _ready() -> void:
	name = "ToyWinterVillage"
	position = ORIGIN
	var room_floor := MeshInstance3D.new()
	room_floor.name = "WinterPlayroomFloor"
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(800, 800)
	room_floor.mesh = floor_plane
	room_floor.material_override = Playroom.wood_finish(Color("c6a47e"), true)
	room_floor.material_override.set_shader_parameter("floor_origin", Vector2(ORIGIN.x, ORIGIN.z))
	room_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(room_floor)
	room_floor.position.y = -1.03
	Playroom.make_room_props(self)

	mat = RollingMat.new()
	add_child(mat)
	mat.show_world(2, 0)
	mat.position = Vector3(0, 0.03, 0)
	mat.finish.set_shader_parameter("printed_toys", false)

	# Continuous ground collider matching Maple Bay.
	TownProps.collider(self, Vector3(0, -0.5, 0), Vector3(160, 1, 160)).add_to_group("winter_snow")

	ice_field = IceField.new()
	add_child(ice_field)
	ice_field.add_zone(
		Rect2(RINK_CENTER.x - RINK_SIZE.x * 0.46, RINK_CENTER.z - RINK_SIZE.y * 0.46, RINK_SIZE.x * 0.92, RINK_SIZE.y * 0.92),
		func(p2: Vector2) -> float: return _rink_slip_at(p2)
	)

	_build_roads()
	_build_boundary()
	_build_village()
	_build_rink()
	_build_bonfire()
	_build_owl_rescue()
	_build_supply_sled()
	_build_hydrants()
	_build_people()
	_build_wildlife()
	_build_snowfall()

	hide()
	process_mode = Node.PROCESS_MODE_DISABLED

func _build_roads() -> void:
	var roads := Node3D.new()
	roads.name = "WinterRoads"
	add_child(roads)
	var asphalt := ShaderMaterial.new()
	asphalt.shader = preload("res://shaders/ground.gdshader")
	asphalt.set_shader_parameter("base_color", Color("6e818c"))
	asphalt.set_shader_parameter("grain_scale", 18.0)
	asphalt.set_shader_parameter("variation", 0.06)

	var segments := [
		[Vector3(-12, 0.032, 0), Vector3(136, 0.05, 8.8)],      # West entry -> village centre -> east plaza
		[Vector3(8, 0.032, 0), Vector3(8.4, 0.05, 76)],         # Central north-south road
		[Vector3(-42, 0.032, 0), Vector3(8.0, 0.05, 72)],       # West loop road
		[Vector3(38, 0.032, 0), Vector3(8.0, 0.05, 68)],        # East lodge & pine grove road
		[Vector3(-2, 0.032, -34), Vector3(88, 0.05, 7.6)],      # North lane (rink <-> cocoa lodge)
		[Vector3(-2, 0.032, 34), Vector3(88, 0.05, 7.6)],       # South lane (sled corridor <-> owl pine)
	]
	for seg in segments:
		var slab := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		slab.mesh = box
		slab.position = seg[0]
		slab.scale = seg[1]
		slab.material_override = asphalt
		slab.set_meta("assembly_group", 2)
		roads.add_child(slab)
	# Crisp white-cream lane dashes along the west entry road.
	for x in range(-76, 48, 5):
		if absf(x - 8) < 6 or absf(x + 42) < 6 or absf(x - 38) < 6: continue
		var dash := TownProps.box(roads, Vector3(x, 0.062, 0), Vector3(1.6, 0.018, 0.14), Color("eaf3f7"))
		dash.set_meta("batch_static", true)
	TownProps.batch_decorations(roads)

func _build_boundary() -> void:
	var blocks := Node3D.new()
	blocks.name = "BoundaryBlocks"
	add_child(blocks)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9412
	var finishes: Array[ShaderMaterial] = []
	for tone in ["d9c7ad", "cbb18e", "e3d5be", "5f8ea8", "7ea7b8", "c96c5b"]:
		finishes.append(Playroom.wood_finish(Color(tone), false, finishes.size() > 2))
	for side in [-1, 1]:
		for axis in 2:
			var at := -82.0
			while at < 82.0:
				# Open west entrance at x = -81, z in [-8, 8] to connect back to Maple Bay.
				if axis == 0 and side == -1 and at >= -8.0 and at < 8.0:
					at = 8.0
				var end := -8.0 if axis == 0 and side == -1 and at < -8.0 else 82.0
				var length := minf(rng.randf_range(5.0, 11.0), end - at)
				if end - at - length < 1.6: length = end - at
				var height := rng.randf_range(2.6, 4.2)
				var p := Vector3(side * 81, height * 0.5, at + length * 0.5) if axis == 0 else Vector3(at + length * 0.5, height * 0.5, side * 81)
				var dims := Vector3(3.0, height, length - 0.1) if axis == 0 else Vector3(length - 0.1, height, 3.0)
				var block := TownProps.box(blocks, p, dims, Color.WHITE)
				block.material_override = finishes[rng.randi_range(0, finishes.size() - 1)]
				block.rotation.y = rng.randf_range(-0.025, 0.025)
				block.set_meta("batch_static", true)
				at += length
			if axis == 1:
				_boundary_collider(Vector3(0, 3, side * 81), Vector3(164, 6, 3))
			elif side == 1:
				_boundary_collider(Vector3(81, 3, 0), Vector3(3, 6, 164))
			else:
				for z in [-44, 44]:
					_boundary_collider(Vector3(-81, 3, z), Vector3(3, 6, 72))
	# Turned wooden border beams framing the west entrance passage.
	for side in [-1, 1]:
		_boundary_collider(Vector3(-74.5, 1.5, side * 6.4), Vector3(13.0, 3.0, 3.0))
		for piece in 2:
			var block := TownProps.box(blocks, Vector3(-78.0 + piece * 6.5, 1.45, side * 6.4), Vector3(6.2, 2.9, 2.8), Color.WHITE)
			block.material_override = finishes[(piece + (1 if side > 0 else 0)) % 3]
			block.set_meta("batch_static", true)
	TownProps.batch_decorations(blocks)

func _boundary_collider(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Playroom.WALL_LAYER
	body.add_to_group("wooden_boundary")
	add_child(body)
	body.position = at
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	col.shape = box
	body.add_child(col)

func _build_village() -> void:
	var scenery := Node3D.new()
	scenery.name = "WinterBuildings"
	add_child(scenery)

	# Snow-capped village cottages and the Cozy Cocoa Lodge.
	var buildings := [
		[Vector3(48, 0, -44), Color("bd6252"), "COCOA LODGE"],
		[Vector3(-52, 0, -34), Color("76a3a1"), "FROST COTTAGE"],
		[Vector3(-56, 0, 20), Color("dd987d"), "PINE BAKERY"],
		[Vector3(56, 0, 12), Color("c1ae83"), "TIMBER CHALET"],
		[Vector3(-14, 0, 56), Color("76a3a1"), "SOUTH CABIN"],
		[Vector3(20, 0, -54), Color("dd987d"), "NORTH CABIN"],
	]
	for spec in buildings:
		_snow_house(scenery, spec[0], spec[1], spec[2])

	# Cozy cocoa stand next to the bonfire plaza.
	_cocoa_stand(scenery, Vector3(49, 0, -20))

	# Snow-dusted wooden benches around the village square & rink.
	for spec in [
		[Vector3(-12, 0, -24), PI * 0.5],
		[Vector3(22, 0, -10), 0.0],
		[Vector3(-8, 0, 12), PI],
	]:
		var parts := TownProps.bench(scenery, spec[0], float(spec[1]))
		var bench_prop := BreakableProp.from_parts(self, game, "bench", to_global(spec[0]), parts, Vector3(2.9, 1.3, 0.9), Vector3.UP * 0.65, 1.5)
		props.append(bench_prop)

	# Warm golden winter streetlamps (breakable props).
	for p in [Vector3(-56, 0, -7), Vector3(-28, 0, -7), Vector3(-2, 0, -7), Vector3(24, 0, -7), Vector3(-2, 0, 26), Vector3(24, 0, 26), Vector3(-34, 0, 26)]:
		var lamp := Node3D.new()
		lamp.set_meta("toy_arrival", "drop")
		lamp.position = p
		scenery.add_child(lamp)
		TownProps.cylinder(lamp, Vector3.UP * 2.1, 0.08, 4.2, Color("3c525e"))
		TownProps.box(lamp, Vector3(0, 4.15, 0), Vector3(0.75, 0.24, 0.65), Color("ffebb3"))
		TownProps.ball(lamp, Vector3(0, 4.35, 0), Vector3(0.72, 0.16, 0.62), Color("f2f7fa"))
		props.append(BreakableProp.from_parts(self, game, "lamp", to_global(p), [lamp], Vector3(0.8, 4.4, 0.8), Vector3.UP * 2.2, 0.55))

	# Cheerful breakable snowmen scattered in yards!
	for spec in [
		[Vector3(-52, 0, -14), Color("d46454")],
		[Vector3(-10, 0, -40), Color("5898a8")],
		[Vector3(24, 0, 12), Color("e2a64f")],
		[Vector3(-50, 0, 38), Color("b86e8a")],
		[Vector3(52, 0, 34), Color("5a9478")],
	]:
		var man := _build_snowman(scenery, spec[0], spec[1])
		props.append(BreakableProp.from_parts(self, game, "snowman", to_global(spec[0]), [man], Vector3(1.5, 2.5, 1.5), Vector3.UP * 1.25, 0.85))

	# Wooden snow fences along outer meadow bends.
	for spec in [
		[Vector3(-64, 0, -20), 0.0],
		[Vector3(62, 0, -6), PI * 0.5],
		[Vector3(-28, 0, 56), 0.0],
	]:
		var fence := _build_snow_fence(scenery, spec[0], float(spec[1]))
		props.append(BreakableProp.from_parts(self, game, "snow_fence", to_global(spec[0]), [fence], Vector3(6.6, 1.3, 0.5), Vector3.UP * 0.65, 1.8))

	# Frosted evergreen pine groves planted clear of roads, missions & buildings.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4109
	var planted: Array[Vector3] = [OWL_TREE]
	for _attempt in 400:
		if planted.size() >= 44: break
		var p := Vector3(rng.randf_range(-71, 71), 0, rng.randf_range(-71, 71))
		if absf(p.z) < 10.5 and p.x < 54: continue
		if absf(p.x - 8) < 10.0 and absf(p.z) < 42: continue
		if absf(p.x + 42) < 9.5 and absf(p.z) < 40: continue
		if absf(p.x - 38) < 9.5 and absf(p.z) < 38: continue
		if absf(p.z + 34) < 9.5 and p.x > -48 and p.x < 46: continue
		if absf(p.z - 34) < 10.0 and p.x > -48 and p.x < 46: continue
		if p.distance_to(RINK_CENTER) < 17.5: continue
		if p.distance_to(BONFIRE_POS) < 12.5: continue
		if p.distance_to(OWL_TREE) < 11.0: continue
		if p.distance_to(SLED_START) < 11.0 or p.distance_to(SLED_GOAL) < 11.0: continue
		var clear := true
		for b in buildings:
			if p.distance_to(b[0]) < 12.0: clear = false; break
		if not clear: continue
		for other in planted:
			if p.distance_to(other) < 6.4: clear = false; break
		if not clear: continue
		planted.append(p)
		var size := rng.randf_range(0.95, 1.45)
		var pine := _build_pine_tree(scenery, p, size)
		props.append(BreakableProp.tree_from_parts(self, game, to_global(p), [pine], size))

	# Festive winter bunting over the rink and cocoa plaza.
	ToyBunting.build(scenery, RINK_CENTER + Vector3(-9.5, 0, -7.8), RINK_CENTER + Vector3(9.5, 0, -7.8))
	ToyBunting.build(scenery, Vector3(26, 0, -34), Vector3(46, 0, -34))

	# West exit signpost pointing back to Maple Bay!
	var sign_root := TownProps.toy_group(scenery, Vector3(-68, 0, -7.5), "drop", "MapleSignpost")
	TownProps.cylinder(sign_root, Vector3.UP * 1.4, 0.13, 2.8, Color("8a684b"))
	TownProps.box(sign_root, Vector3(0, 2.45, 0), Vector3(3.4, 0.72, 0.18), Color("4f7c91"))
	var sign_txt := TownProps.label(sign_root, Vector3(0, 2.45, 0.12), "← MAPLE BAY", 22)
	sign_txt.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_txt.pixel_size = 0.018

func _snow_house(parent: Node3D, pos: Vector3, color: Color, title: String) -> void:
	TownProps.house(parent, pos, color, title, 5.0)
	var cap := TownProps.toy_group(parent, pos, "grow", "SnowRoofCap")
	# Crisp snow blanket resting along the gable ridge.
	var roof_a := TownProps.box(cap, Vector3(0, 4.95, -1.25), Vector3(8.5, 0.36, 3.6), Color("f1f6fa"))
	roof_a.rotation.x = -0.34
	var roof_b := TownProps.box(cap, Vector3(0, 4.95, 1.25), Vector3(8.5, 0.36, 3.6), Color("f1f6fa"))
	roof_b.rotation.x = 0.34
	TownProps.box(cap, Vector3(0, 5.52, 0), Vector3(8.55, 0.28, 0.65), Color("f7fbfe"))

func _cocoa_stand(parent: Node3D, at: Vector3) -> void:
	var stand := TownProps.toy_group(parent, at, "grow", "CocoaStand")
	TownProps.box(stand, Vector3(0, 1.3, 0), Vector3(6.4, 2.6, 4.6), Color("9d6b4e"), true)
	TownProps.box(stand, Vector3(0, 3.4, 0), Vector3(7.4, 0.42, 6.0), Color("c45e4c"))
	TownProps.box(stand, Vector3(0, 3.72, 0), Vector3(7.45, 0.28, 6.05), Color("f2f7fb"))
	TownProps.box(stand, Vector3(-3.3, 1.75, 0), Vector3(1.1, 0.22, 4.8), Color("ebd8b4"))
	for z in [-1.2, 0.0, 1.2]:
		TownProps.cylinder(stand, Vector3(-3.3, 2.05, z), 0.16, 0.34, Color("d46b57"))
		TownProps.ball(stand, Vector3(-3.3, 2.26, z), Vector3(0.26, 0.12, 0.26), Color("f8f2e4"))
	var sign := TownProps.label(stand, Vector3(-3.3, 3.05, 0), "HOT COCOA", 22)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.rotation.y = -PI * 0.5
	sign.pixel_size = 0.016

func _build_pine_tree(parent: Node3D, pos: Vector3, size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "WinterPine"
	root.set_meta("toy_kind", "GardenTree")
	root.set_meta("toy_arrival", "drop")
	parent.add_child(root)
	root.position = pos
	var art := Node3D.new()
	art.scale = Vector3.ONE * size
	root.add_child(art)
	TownProps.cylinder(art, Vector3(0, 1.0, 0), 0.26, 2.0, Color("7d5a42"), 0.20)
	var tiers := [
		[Vector3(0, 2.35, 0), 1.65, 1.8, Color("417464")],
		[Vector3(0, 3.55, 0), 1.30, 1.6, Color("4b8270")],
		[Vector3(0, 4.65, 0), 0.90, 1.4, Color("56907d")],
	]
	for t in tiers:
		TownProps.cylinder(art, t[0], t[1], t[2], t[3], 0.08)
		# Crisp frosted snow rim on each pine tier!
		TownProps.cylinder(art, t[0] + Vector3(0, t[2] * 0.18, 0), t[1] * 0.72, t[2] * 0.56, Color("eef5f9"), 0.06)
	TownProps.soften_toy_shine(art)
	TownProps.collider(root, Vector3(0, 1.25, 0), Vector3(0.48, 2.5, 0.48) * size)
	return root

func _build_snowman(parent: Node3D, pos: Vector3, scarf_col: Color) -> Node3D:
	var man := TownProps.toy_group(parent, pos, "drop", "Snowman")
	var snow := Color("f2f7fa")
	TownProps.ball(man, Vector3(0, 0.56, 0), Vector3(1.22, 1.08, 1.22), snow)
	TownProps.ball(man, Vector3(0, 1.34, 0), Vector3(0.92, 0.84, 0.92), snow)
	TownProps.ball(man, Vector3(0, 1.98, 0), Vector3(0.66, 0.64, 0.66), snow)
	# Scarf, carrot nose, coal buttons & eyes, top hat and twig arms.
	ToyModels._torus(man, Vector3(0, 1.66, 0), 0.20, 0.34, scarf_col)
	TownProps.box(man, Vector3(0.20, 1.42, -0.34), Vector3(0.16, 0.42, 0.08), scarf_col)
	var carrot := TownProps.cylinder(man, Vector3(0, 1.98, -0.44), 0.06, 0.30, Color("e68245"), 0.01)
	carrot.rotation.x = -PI * 0.5
	for side in [-1, 1]:
		TownProps.ball(man, Vector3(side * 0.14, 2.08, -0.29), Vector3.ONE * 0.08, Color("2d3b42"))
		var twig := TownProps.cylinder(man, Vector3(side * 0.68, 1.44, 0), 0.04, 0.78, Color("765740"))
		twig.rotation.z = side * 1.15
	for y in [1.14, 1.36, 1.54]:
		TownProps.ball(man, Vector3(0, y, -0.44), Vector3.ONE * 0.08, Color("2d3b42"))
	TownProps.cylinder(man, Vector3(0, 2.30, 0), 0.42, 0.08, Color("384954"))
	TownProps.cylinder(man, Vector3(0, 2.52, 0), 0.27, 0.42, Color("384954"))
	TownProps.cylinder(man, Vector3(0, 2.36, 0), 0.285, 0.09, scarf_col)
	TownProps.soften_toy_shine(man)
	return man

func _build_snow_fence(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var fence := TownProps.toy_group(parent, pos, "drop", "SnowFence")
	fence.rotation.y = yaw
	for x in [-2.8, -1.4, 0.0, 1.4, 2.8]:
		TownProps.box(fence, Vector3(x, 0.62, 0), Vector3(0.18, 1.24, 0.18), Color("c9ad8a"))
	for y in [0.42, 0.96]:
		TownProps.box(fence, Vector3(0, y, 0), Vector3(6.2, 0.14, 0.10), Color("d9c09d"))
	TownProps.box(fence, Vector3(0, 1.07, 0), Vector3(6.1, 0.09, 0.14), Color("f1f6fa"))
	return fence

func _build_rink() -> void:
	var rink := Node3D.new()
	rink.name = "VillageSkatingRink"
	add_child(rink)
	rink.position = RINK_CENTER
	var hw := RINK_SIZE.x * 0.5
	var hh := RINK_SIZE.y * 0.5

	# Snow-packed base bed.
	TownProps.box(rink, Vector3(0, 0.025, 0), Vector3(RINK_SIZE.x, 0.04, RINK_SIZE.y), Color("dde8ef"))
	# Low wooden dasher boards with an open drive-in entrance on the east side!
	var board_col := Color("d6b286")
	var trim_col := Color("4f89a3")
	for side in [-1, 1]:
		TownProps.box(rink, Vector3(0, 0.42, side * hh), Vector3(RINK_SIZE.x + 0.5, 0.84, 0.42), board_col, true)
		TownProps.box(rink, Vector3(0, 0.86, side * hh), Vector3(RINK_SIZE.x + 0.55, 0.12, 0.48), trim_col)
	TownProps.box(rink, Vector3(-hw, 0.42, 0), Vector3(0.42, 0.84, RINK_SIZE.y), board_col, true)
	TownProps.box(rink, Vector3(-hw, 0.86, 0), Vector3(0.48, 0.12, RINK_SIZE.y + 0.05), trim_col)
	# East wall split for a 6.4m wide drive-in rink entrance.
	for side in [-1, 1]:
		TownProps.box(rink, Vector3(hw, 0.42, side * 5.2), Vector3(0.42, 0.84, 3.6), board_col, true)
		TownProps.box(rink, Vector3(hw, 0.86, side * 5.2), Vector3(0.48, 0.12, 3.65), trim_col)

	# 4x3 freezeable rink tiles that grow shiny blue ice as you spray them!
	var cols := 4
	var rows := 3
	var tile_w := (RINK_SIZE.x - 1.2) / float(cols)
	var tile_d := (RINK_SIZE.y - 1.2) / float(rows)
	for ix in cols:
		for iz in rows:
			var cx := -((RINK_SIZE.x - 1.2) * 0.5) + (ix + 0.5) * tile_w
			var cz := -((RINK_SIZE.y - 1.2) * 0.5) + (iz + 0.5) * tile_d
			var sheet := MeshInstance3D.new()
			var plane := BoxMesh.new()
			plane.size = Vector3(tile_w + 0.18, 0.032, tile_d + 0.18)
			sheet.mesh = plane
			var ice_mat := StandardMaterial3D.new()
			ice_mat.albedo_color = Color(0.64, 0.90, 0.99, 0.0)
			ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice_mat.roughness = 0.08
			ice_mat.metallic = 0.08
			ice_mat.metallic_specular = 0.95
			ice_mat.clearcoat_enabled = true
			ice_mat.clearcoat = 0.95
			ice_mat.clearcoat_roughness = 0.06
			sheet.material_override = ice_mat
			sheet.position = Vector3(cx, 0.055, cz)
			sheet.scale = Vector3(0.01, 1.0, 0.01)
			sheet.visible = false
			sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rink.add_child(sheet)
			rink_tiles.append({
				"local": RINK_CENTER + Vector3(cx, 0.06, cz),
				"mesh": sheet,
				"mat": ice_mat,
				"freeze": 0.0,
				"radius": maxf(tile_w, tile_d) * 0.72,
			})

	# Three cheerful skaters who wait beside the rink until it freezes, then glide!
	var skater_shirts := [Color("d97762"), Color("689fb2"), Color("e2b25a")]
	var skater_accents := [Color("f3e5c5"), Color("d97762"), Color("5b9682")]
	for i in 3:
		var skater := _make_person(RINK_CENTER + Vector3(-hw - 2.2, 0.12, -4.0 + i * 4.0), skater_shirts[i], "winter_skater", skater_accents[i], true)
		skater.name = "WinterSkater%d" % i
		skater.rotation.y = -PI * 0.5
		skaters.append(skater)

func _rink_slip_at(p2: Vector2) -> float:
	if rink_done: return 0.95
	var best := 0.0
	for tile in rink_tiles:
		if tile.freeze <= 0.05: continue
		var d := p2.distance_to(Vector2(tile.local.x, tile.local.z))
		if d < tile.radius:
			best = maxf(best, float(tile.freeze))
	return best

func _build_bonfire() -> void:
	var pit := TownProps.toy_group(self, BONFIRE_POS, "drop", "WinterBonfire")
	# Stone fire ring + stacked glowing logs.
	for i in 10:
		var a := i * TAU / 10.0
		TownProps.ball(pit, Vector3(cos(a) * 1.45, 0.25, sin(a) * 1.45), Vector3(0.75, 0.48, 0.65), Color("8e979e"))
	for i in 4:
		var log_mesh := TownProps.cylinder(pit, Vector3(0, 0.42, 0), 0.20, 2.2, Color("6e4a35"))
		log_mesh.rotation = Vector3(0.45, i * PI * 0.5, 0.35)
	bonfire_fire = ToyFire.new()
	bonfire_fire.name = "WinterBonfireFire"
	bonfire_fire.game = game
	bonfire_fire.water_required = 1.0 / 0.38
	pit.add_child(bonfire_fire)

func _build_owl_rescue() -> void:
	var pine := _build_pine_tree(self, OWL_TREE, 1.30)
	owl_tree_prop = BreakableProp.tree_from_parts(self, game, to_global(OWL_TREE), [pine], 1.30)
	owl_tree_prop.locked = true
	props.append(owl_tree_prop)
	# Snow-dusted horizontal perch branch for Snowball.
	TownProps.box(self, OWL_BRANCH, Vector3(0.30, 0.24, 3.0), Color("7d5a42"))
	TownProps.box(self, OWL_BRANCH + Vector3(0, 0.14, 0), Vector3(0.28, 0.10, 2.8), Color("f1f6fa"))
	owl = ToyModels.build_owl(self, OWL_PERCH)
	owl.rotation.y = PI
	owl_home = owl.global_position
	owl_ladder_event = LadderEvent.new()
	owl_ladder_event.name = "SnowyOwlLadderEvent"
	owl_ladder_event.availability = func() -> bool: return active and not game.paused and not owl_rescue_running and not owl_rescued
	owl_ladder_event.activated.connect(_on_owl_ladder_reached)
	owl.add_child(owl_ladder_event)

func _build_supply_sled() -> void:
	# Flagged delivery corridor along z = 34 from x = -26 to x = 14.
	var lane := Node3D.new()
	lane.name = "SledCorridor"
	add_child(lane)
	for x in [-24, -14, -4, 6, 14]:
		for side in [-1, 1]:
			var post := TownProps.toy_group(lane, Vector3(x, 0, 34 + side * 4.4), "drop", "SledPost")
			TownProps.cylinder(post, Vector3.UP * 0.75, 0.10, 1.5, Color("9a7452"))
			TownProps.box(post, Vector3(0, 1.32, 0), Vector3(0.14, 0.38, 0.56), Color("d46b57") if x == 14 else Color("5f99ad"))

	# Glowing delivery pad at SLED_GOAL.
	sled_goal_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.85
	torus.outer_radius = 3.15
	sled_goal_ring.mesh = torus
	sled_goal_ring.material_override = TownProps.material(Color("f0c659"), true)
	sled_goal_ring.position = SLED_GOAL + Vector3.UP * 0.10
	sled_goal_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sled_goal_ring)
	var pad_label := TownProps.label(self, SLED_GOAL + Vector3(0, 3.2, -3.5), "DELIVERY PAD", 24)
	pad_label.pixel_size = 0.02

	# Heavy painted wooden winter supply sled (RigidBody3D).
	sled = RigidBody3D.new()
	sled.name = "WinterSupplySled"
	sled.mass = 9.0
	sled.collision_layer = 2
	sled.collision_mask = 19
	sled.axis_lock_linear_y = true
	sled.axis_lock_linear_z = true
	sled.lock_rotation = true
	sled.can_sleep = false
	sled.continuous_cd = true
	sled.contact_monitor = true
	sled.max_contacts_reported = 4
	sled.linear_damp = 0.35
	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.04
	pmat.bounce = 0.02
	sled.physics_material_override = pmat
	add_child(sled)
	sled.position = SLED_START

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.6, 2.2, 2.9)
	col.shape = shape
	col.position.y = 1.15
	sled.add_child(col)

	# Sled runners, deck and festive supply crates.
	for z in [-1.15, 1.15]:
		TownProps.box(sled, Vector3(0, 0.14, z), Vector3(4.6, 0.18, 0.22), Color("536975"))
		var curl := TownProps.box(sled, Vector3(2.38, 0.36, z), Vector3(0.55, 0.18, 0.22), Color("536975"))
		curl.rotation.z = 0.72
		for x in [-1.5, 0.0, 1.4]:
			TownProps.box(sled, Vector3(x, 0.42, z), Vector3(0.16, 0.42, 0.16), Color("9a7452"))
	TownProps.box(sled, Vector3(0, 0.66, 0), Vector3(4.3, 0.24, 2.7), Color("c45e4c"))
	TownProps.box(sled, Vector3(-2.05, 1.20, 0), Vector3(0.22, 0.95, 2.6), Color("c45e4c"))
	# Cargo crates & gift parcels!
	TownProps.box(sled, Vector3(-0.7, 1.32, -0.45), Vector3(1.5, 1.15, 1.25), Color("d9b37c"))
	TownProps.box(sled, Vector3(0.95, 1.22, 0.35), Vector3(1.3, 0.95, 1.15), Color("5c95a6"))
	TownProps.box(sled, Vector3(0.8, 1.15, -0.75), Vector3(0.95, 0.85, 0.85), Color("d97a63"))
	TownProps.box(sled, Vector3(-0.5, 1.48, 0.65), Vector3(1.05, 1.10, 0.92), Color("70a387"))
	# Gold ribbon bands across the crates.
	TownProps.box(sled, Vector3(0.95, 1.23, 0.35), Vector3(1.34, 0.98, 0.16), Color("f0c659"))
	TownProps.box(sled, Vector3(0.8, 1.16, -0.75), Vector3(0.16, 0.88, 0.88), Color("f0c659"))

func _build_hydrants() -> void:
	for p in HYDRANT_POINTS:
		var h := FireHydrant.spawn(self, game, to_global(p))
		hydrants.append(h)
		props.append(h)

func _make_person(at: Vector3, shirt: Color, style: String, accent: Color, walking: bool = false, skin: Color = Color.TRANSPARENT, hair: Color = Color.TRANSPARENT) -> Node3D:
	var person := TownProps.person(self, at, shirt, skin, hair)
	var head := TownProps.articulate_head(person)
	var eyes: Node3D = head.get_node("Eyes")
	var legs: Array[Node3D] = []
	if walking: legs = TownProps.walking_legs(person)
	ToyModels.dress_person(person, style, accent)
	actor_rigs[person] = {
		"head": head,
		"eyes": eyes,
		"left": person.get_node("ArmLeft"),
		"right": person.get_node("ArmRight"),
		"legs": legs,
		"index": actor_rigs.size(),
	}
	return person

func _build_people() -> void:
	# Elsa (rink), Bram (bonfire), Astrid (snowy owl), Torsten (supply sled).
	var specs := [
		[Vector3(-12, 0, -16), Color("f2ebd9"), "elsa", Color("d97762"), Color("edc6a5"), Color("583e32")],
		[Vector3(24, 0, -18), Color("466b56"), "bram", Color("b84b44"), Color("b88160"), Color("b9b7ac")],
		[Vector3(26, 0, 26), Color("6786a1"), "astrid", Color("d9a34a"), Color("6d4834"), Color("2e2826")],
		[Vector3(-34, 0, 26), Color("c99247"), "torsten", Color("354c63"), Color("dfac81"), Color("cfa060")],
	]
	for i in specs.size():
		var s: Array = specs[i]
		var actor := _make_person(s[0], s[1], s[2], s[3], false, s[4], s[5])
		actor.name = NAMES[i]
		PersonalSpace.protect(actor, game.truck)
		people.append(actor)

	# 4 strolling winter villagers around the village square.
	var routes := [
		Vector3(-2, 0, -12),
		Vector3(16, 0, 8),
		Vector3(-30, 0, 10),
		Vector3(22, 0, -40),
	]
	var coats := [Color("6b8ea3"), Color("c4746a"), Color("699481"), Color("c99b59")]
	for i in routes.size():
		var start: Vector3 = routes[i]
		var actor := _make_person(start, coats[i], "winter_villager", coats[(i + 1) % coats.size()], true)
		walkers.append({"actor": actor, "start": start, "phase": i * 1.9, "route_angle": i * 1.6, "legs": actor_rigs[actor].legs})

func _build_wildlife() -> void:
	for i in 4:
		var bird := ToyModels.build_bird(self, i, true)
		bird.center = Vector3(-12, 14.5, -14) if i < 2 else Vector3(28, 14.5, 16)
		bird.radius = 14.0 + i * 1.2
		birds.append(bird)
	var perches := [
		Vector3(-48, 0, -18), Vector3(-12, 0, -42), Vector3(22, 0, -42),
		Vector3(52, 0, -4), Vector3(-52, 0, 12), Vector3(14, 0, 48),
	]
	for i in perches.size():
		var bird := ToyModels.build_bird(self, i + 4, true)
		bird.node.scale = Vector3.ONE * 1.55
		bird.node.position = perches[i] + Vector3.UP * 0.03
		bird.home = bird.node.position
		bird.mode = "ground"
		bird.age = 0.0
		bird.from = bird.home
		bird.escape = bird.home
		bird.open = 0.0
		ground_birds.append(bird)

func _build_snowfall() -> void:
	var flake := SphereMesh.new()
	flake.radius = 0.10
	flake.height = 0.20
	flake.radial_segments = 6
	flake.rings = 4
	var mat_flake := StandardMaterial3D.new()
	mat_flake.albedo_color = Color(0.97, 0.99, 1.0, 0.85)
	mat_flake.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flake.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow_batch = MultiMeshInstance3D.new()
	snow_batch.name = "FallingSnow"
	snow_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_batch.set_meta("assembly_ignore", true)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = flake
	mm.instance_count = 140
	snow_batch.multimesh = mm
	snow_batch.material_override = mat_flake
	snow_batch.custom_aabb = AABB(Vector3(-85, -1, -85), Vector3(170, 32, 170))
	add_child(snow_batch)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2027
	for i in 140:
		snow_motes.append({
			"pos": Vector3(rng.randf_range(-74, 74), rng.randf_range(0.5, 22.0), rng.randf_range(-74, 74)),
			"speed": rng.randf_range(1.6, 2.9),
			"phase": rng.randf_range(0, TAU),
			"size": rng.randf_range(0.75, 1.35),
		})

func setup_camera_interests() -> void:
	game.camera_framing.add(self, "WinterRink", RINK_CENTER + Vector3.UP * 0.5, Vector3(9.5, 2.0, 7.5), func() -> bool: return active and (not rink_done or game.rewards.waiting_for("ELSA")), 16, 30)
	game.camera_framing.add(self, "WinterBonfire", BONFIRE_POS + Vector3.UP * 1.4, Vector3(2.5, 2.2, 2.5), func() -> bool: return active and (not bonfire_done or game.rewards.waiting_for("BRAM")), 12, 26)
	game.camera_framing.add(owl, "SnowyOwl", Vector3.UP * 0.6, Vector3(1.0, 1.0, 1.0), func() -> bool: return active and not owl_rescued and game.dialogue_actor != people[2], 12, 26)
	game.camera_framing.add(sled, "WinterSled", Vector3.UP * 1.0, Vector3(3.0, 2.0, 2.5), func() -> bool: return active and (not sled_done or game.rewards.waiting_for("TORSTEN")), 14, 28)

func sample_slip(world_pos: Vector3) -> float:
	if not active: return 0.0
	return ice_field.slip_at(world_pos - ORIGIN)

func activate() -> void:
	game.truck.slip_sampler = sample_slip
	resume_bodies()
	active = true
	process_mode = Node.PROCESS_MODE_INHERIT
	show()

func deactivate() -> void:
	game.truck.slip_sampler = Callable()
	game.truck.surface_slip = 0.0
	suspend_bodies()
	active = false
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED

func suspend_bodies() -> void:
	if not suspended_bodies.is_empty(): return
	for body in props:
		if not is_instance_valid(body): continue
		suspended_bodies.append({"body": body, "freeze": body.freeze, "velocity": body.linear_velocity, "angular": body.angular_velocity})
		body.freeze = true
	if is_instance_valid(sled):
		suspended_bodies.append({"body": sled, "freeze": sled.freeze, "velocity": sled.linear_velocity, "angular": sled.angular_velocity})
		sled.freeze = true

func resume_bodies() -> void:
	for saved in suspended_bodies:
		if not is_instance_valid(saved.body): continue
		saved.body.freeze = saved.freeze
		saved.body.linear_velocity = saved.velocity
		saved.body.angular_velocity = saved.angular
	suspended_bodies.clear()

func water_hit(point: Vector3, amount: float) -> bool:
	var local := point - ORIGIN
	var consumed := false

	# 1. Bonfire extinguishing.
	if not bonfire_done and local.distance_to(BONFIRE_POS + Vector3.UP * 1.6) < 2.4:
		if bonfire_fire.apply_water(amount):
			consumed = true
			if bonfire_fire.progress >= 1.0:
				bonfire_done = true
				game.rewards.celebrate("winter_bonfire", ORIGIN + BONFIRE_POS + Vector3.UP * 1.2, "BRAM", "Phew! That bonfire was trying to roast the whole village. Thank you! Hot cocoa on the house!")

	# 2. Freeze village skating rink tiles.
	if not rink_done and absf(local.x - RINK_CENTER.x) < RINK_SIZE.x * 0.52 and absf(local.z - RINK_CENTER.z) < RINK_SIZE.y * 0.52 and local.y < 1.3:
		var touched := false
		for tile in rink_tiles:
			if tile.freeze >= 1.0: continue
			if Vector2(local.x - tile.local.x, local.z - tile.local.z).length() < tile.radius * 1.15:
				tile.freeze = minf(1.0, float(tile.freeze) + amount * 2.4)
				_update_rink_tile(tile)
				touched = true
		if touched:
			consumed = true
			if ice_field.freeze_sound_cooldown <= 0.0:
				ice_field.freeze_sound_cooldown = 0.35
				game.sounds.play("ice_freeze", point, 0.72, 0.25)
			var total := 0.0
			for tile in rink_tiles: total += float(tile.freeze)
			rink_progress = total / float(rink_tiles.size())
			if rink_progress >= 0.96:
				rink_progress = 1.0
				rink_done = true
				for tile in rink_tiles:
					tile.freeze = 1.0
					_update_rink_tile(tile)
				game.rewards.celebrate("winter_rink", ORIGIN + RINK_CENTER + Vector3.UP * 0.8, "ELSA", "Smooth as glass! Look at the skaters go — thank you for freezing our village rink!")

	# 3. Everywhere water lands on ground/snow freezes into a slippery ice patch!
	# Inside the sled delivery corridor, ice patches stay permanent so the player
	# can lay a full track before pushing the sled.
	if local.y < 0.85:
		var in_sled_lane := local.x >= -30.0 and local.x <= 16.0 and absf(local.z - 34.0) <= 4.5
		var grew := ice_field.deposit(local, amount, in_sled_lane, 0.068 if _on_road(local) else 0.048)
		if grew and ice_field.freeze_sound_cooldown <= 0.0:
			ice_field.freeze_sound_cooldown = 0.42
			game.sounds.play("ice_freeze", point, 0.58, 0.30)

	return consumed

func _on_road(local: Vector3) -> bool:
	if absf(local.z) < 4.8 and local.x < 56: return true
	if absf(local.x - 8) < 4.6 and absf(local.z) < 39: return true
	if absf(local.x + 42) < 4.5 and absf(local.z) < 37: return true
	if absf(local.x - 38) < 4.5 and absf(local.z) < 35: return true
	if absf(local.z + 34) < 4.2 and local.x > -46 and local.x < 42: return true
	if absf(local.z - 34) < 4.2 and local.x > -46 and local.x < 42: return true
	return false

func _update_rink_tile(tile: Dictionary) -> void:
	var f: float = tile.freeze
	var sheet: MeshInstance3D = tile.mesh
	sheet.visible = f > 0.02
	sheet.scale = Vector3(lerpf(0.25, 1.0, f), 1.0, lerpf(0.25, 1.0, f))
	(tile.mat as StandardMaterial3D).albedo_color = Color(0.66, 0.91, 0.99, clampf(f * 0.82, 0.0, 0.82))

func aim_target(origin: Vector3, requested: Vector3) -> Variant:
	var aim := Vector3(requested.x - origin.x, 0, requested.z - origin.z).normalized()
	if aim.length() < 0.1: return null
	var targets: Array[Dictionary] = []
	if not bonfire_done:
		targets.append({"point": ORIGIN + BONFIRE_POS + Vector3.UP * 1.6, "radius": 4.6})
	if not rink_done:
		for tile in rink_tiles:
			if tile.freeze < 0.98:
				targets.append({"point": ORIGIN + tile.local, "radius": 3.8})
	var best: Variant = null
	var best_score := INF
	for target in targets:
		var pt: Vector3 = target.point
		var planar := Vector3(pt.x - origin.x, 0, pt.z - origin.z)
		var ahead := planar.dot(aim)
		if planar.length() > FireEngine.AIM_RANGE or ahead <= 0 or planar.normalized().dot(aim) < cos(deg_to_rad(42)): continue
		var err := (planar - aim * ahead).length()
		if err > float(target.radius): continue
		var score := err + Vector2(pt.x - requested.x, pt.z - requested.z).length() * 0.15
		if score < best_score and game.truck.shot_is_clear(origin, pt):
			best_score = score
			best = pt
	return best

func _physics_process(dt: float) -> void:
	if not active or game.paused or game.travel.active: return
	if is_instance_valid(sled):
		sled.freeze = game.paused or sled_done
	# Refill from the nearest winter hydrant (broken hydrants still refill at 70% speed).
	var refill_source: BreakableProp = null
	var refill_dist := 6.75
	for h in hydrants:
		if not is_instance_valid(h): continue
		var d: float = game.truck.global_position.distance_to(h.home.origin)
		if game.truck.water < game.truck.tank_capacity and d < refill_dist:
			refill_source = h
			refill_dist = d
	game.refill_hose.update(refill_source, dt)
	if game.refill_hose.active:
		game.truck.water = minf(game.truck.tank_capacity, game.truck.water + game.refill_hose.refill_rate() * dt)

	_update_sled(dt)

func _update_sled(dt: float) -> void:
	if sled_done or not is_instance_valid(sled): return
	# Sample ice beneath the sled and just ahead of its runners!
	var under := ice_field.slip_at(sled.position)
	var front := ice_field.slip_at(sled.position + Vector3(2.4, 0, 0))
	var ahead := ice_field.slip_at(sled.position + Vector3(4.2, 0, 0))
	sled_slip = maxf(under, maxf(front * 0.95, ahead * 0.7))
	# On dry snow the sled resists pushing heavily; on player-frozen ice it glides!
	var resistance := lerpf(92.0, 6.0, smoothstep(0.15, 0.65, sled_slip))
	var vx := sled.linear_velocity.x
	if absf(vx) > 0.001:
		sled.apply_central_force(Vector3(-signf(vx) * minf(absf(vx) * sled.mass / maxf(dt, 0.001), resistance), 0, 0))
	# If the truck is pushing the rear of the sled on dry snow, note it so Torsten can hint.
	var rel: Vector3 = (game.truck.global_position - ORIGIN) - sled.position
	if rel.x < -2.0 and rel.x > -6.5 and absf(rel.z) < 2.2 and sled.get_colliding_bodies().has(game.truck):
		if sled_slip < 0.25:
			sled_pushed_dry = true
		elif game.truck.drive_input().length() > 0.15 or game.truck.linear_velocity.x > 0.5:
			# Extra smooth icy glide assist when pushing on an iced track.
			sled.apply_central_force(Vector3(38.0 * sled_slip, 0, 0))
	# Clamp sled inside corridor X bounds.
	if sled.position.x < -30.0:
		sled.position.x = -30.0
		sled.linear_velocity.x = maxf(0.0, sled.linear_velocity.x)
	if sled.position.x >= SLED_GOAL.x - 2.2:
		sled_done = true
		sled.position.x = SLED_GOAL.x
		sled.linear_velocity = Vector3.ZERO
		sled.freeze = true
		if is_instance_valid(sled_goal_ring): sled_goal_ring.hide()
		game.rewards.celebrate("winter_sled", ORIGIN + SLED_GOAL + Vector3.UP * 1.4, "TORSTEN", "That slid like a dream! Clever trick freezing the track — thank you! Cocoa supplies delivered!")

func _process(dt: float) -> void:
	if not active or game.paused or game.travel.active: return
	animation_clock += dt
	if is_instance_valid(sled_goal_ring) and sled_goal_ring.visible:
		sled_goal_ring.scale = Vector3.ONE * (1.0 + sin(animation_clock * 3.0) * 0.06)
	_update_people(dt)
	_update_walkers(dt)
	_update_skaters(dt)
	_update_birds(dt)
	_update_snowfall(dt)
	if not owl_rescued and not owl_rescue_running and is_instance_valid(owl):
		owl_hoot_timer -= dt
		if owl_hoot_timer <= 0.0:
			owl_hoot_timer = randf_range(8.5, 13.5)
			game.sounds.play("owl", owl.global_position, 0.72, 2.0)

func _update_people(dt: float) -> void:
	for i in people.size():
		var actor := people[i]
		if actor.get_meta("mission_celebrating", false) or actor.get_meta("spray_reacting", false): continue
		if not TownProps.near_view(game.camera, actor.global_position, 3): continue
		var rig: Dictionary = actor_rigs[actor]
		var toward: Vector3 = game.truck.global_position - actor.global_position
		var greeting := toward.length() < 12.0
		rig.right.rotation = Vector3(2.15 + sin(animation_clock * 4.2 + i) * 0.30 if greeting else 0.07 * sin(animation_clock * 0.8 + i), 0, 0.065)
		if greeting:
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-toward.x, -toward.z), 1.0 - exp(-3.0 * dt))
		rig.eyes.scale.y = 0.08 if fmod(animation_clock + i * 0.73, 4.3) < 0.10 else 1.0
		if i == 2 and owl_rescued and owl.get_parent() == actor:
			rig.left.rotation = Vector3(1.15, 0, -0.065)

func _update_walkers(dt: float) -> void:
	for walker in walkers:
		var actor: Node3D = walker.actor
		if actor.get_meta("spray_reacting", false): continue
		var next_angle: float = walker.route_angle + dt * 0.34
		var next_pos: Vector3 = to_global(walker.start + Vector3(sin(next_angle) * 3.2, 0, cos(next_angle) * 2.2))
		var moving := actor.global_position.distance_to(game.truck.global_position) >= 4.8
		if moving:
			walker.route_angle = next_angle
			walker.phase += dt * 5.8
		var angle: float = walker.route_angle
		var bob := TownProps.pose_walk(actor, walker.legs, walker.phase, moving)
		actor.position = walker.start + Vector3(sin(angle) * 3.2, bob, cos(angle) * 2.2)
		if moving:
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-cos(angle) * 3.2, sin(angle) * 2.2), 1.0 - exp(-6.0 * dt))

func _update_skaters(dt: float) -> void:
	for i in skaters.size():
		var skater := skaters[i]
		if skater.get_meta("spray_reacting", false): continue
		var rig: Dictionary = actor_rigs[skater]
		if rink_done:
			# Graceful figure-8 / oval glide across the newly frozen village rink!
			var phase := animation_clock * (0.62 + i * 0.09) + i * TAU / 3.0
			var target := RINK_CENTER + Vector3(cos(phase) * (5.6 - i * 0.8), 0.15, sin(phase * (2.0 if i == 1 else 1.0)) * (3.8 - i * 0.4))
			var prev := skater.position
			skater.position = skater.position.lerp(target, 1.0 - exp(-3.5 * dt))
			var vel := skater.position - prev
			vel.y = 0
			if vel.length() > 0.002:
				skater.rotation.y = lerp_angle(skater.rotation.y, atan2(-vel.x, -vel.z), 1.0 - exp(-6.0 * dt))
			var glide := sin(animation_clock * 3.6 + i * 1.4)
			rig.legs[0].rotation.x = glide * 0.42
			rig.legs[1].rotation.x = -glide * 0.42
			rig.left.rotation = Vector3(-0.35 - glide * 0.42, 0, -0.065)
			rig.right.rotation = Vector3(0.35 + glide * 0.42, 0, 0.065)
		else:
			# Waiting eagerly beside the boards, waving gently to keep warm.
			rig.right.rotation = Vector3(0.30 + sin(animation_clock * 2.5 + i) * 0.22, 0, 0.065)
		rig.eyes.scale.y = 0.08 if fmod(animation_clock + i * 0.9, 4.1) < 0.10 else 1.0

func _update_birds(dt: float) -> void:
	for bird in birds:
		var a: float = animation_clock * 0.24 + float(bird.phase)
		var p: Vector3 = bird.center + Vector3(cos(a) * float(bird.radius), sin(animation_clock * 0.7 + float(bird.phase)) * 1.1, sin(a) * float(bird.radius) * 0.65)
		bird.node.position = p
		bird.node.rotation.y = atan2(sin(a), -cos(a) * 0.65)
		_pose_bird(bird, 1.0, animation_clock * 13.0 + float(bird.phase))
	var truck_local: Vector3 = game.truck.global_position - ORIGIN
	for bird in ground_birds:
		bird.age += dt
		var node: Node3D = bird.node
		var dist := Vector2(node.position.x - truck_local.x, node.position.z - truck_local.z).length()
		if bird.mode != "flee" and dist < 8.5:
			startle_bird(bird, game.truck.global_position)
		if bird.mode == "flee":
			bird.open = move_toward(float(bird.open), 1.0, dt * 5.0)
			var t := clampf(float(bird.age) / 2.0, 0.0, 1.0)
			node.position = (bird.from as Vector3).lerp(bird.escape, smoothstep(0.25, 1.0, t))
			node.position.y = lerpf(float(bird.from.y), 14.5, smoothstep(0.0, 0.65, t))
			node.rotation.y = lerp_angle(node.rotation.y, atan2(bird.from.x - bird.escape.x, bird.from.z - bird.escape.z), 1.0 - exp(-7.0 * dt))
			if t >= 1.0 and bird.age > 4.5 and truck_local.distance_to(bird.home) > 14.0:
				bird.mode = "land"
				bird.from = node.position
				bird.age = 0.0
			_pose_bird(bird, float(bird.open), animation_clock * 18.0 + float(bird.phase))
		elif bird.mode == "land":
			var t := clampf(float(bird.age) / 2.2, 0.0, 1.0)
			bird.open = move_toward(float(bird.open), 0.0 if t > 0.85 else 1.0, dt * 5.0)
			node.position = (bird.from as Vector3).lerp(bird.home, smoothstep(0.0, 0.6, t))
			node.position.y = lerpf(float(bird.from.y), float(bird.home.y), smoothstep(0.45, 1.0, t))
			if t >= 1.0:
				bird.mode = "ground"
				bird.age = 0.0
			_pose_bird(bird, float(bird.open), animation_clock * 18.0 + float(bird.phase))
		else:
			bird.open = move_toward(float(bird.open), 0.0, dt * 5.0)
			_pose_bird(bird, float(bird.open), 0.0)

func startle_bird(bird: Dictionary, away_from_world: Vector3) -> void:
	if bird.mode == "flee": return
	var node: Node3D = bird.node
	game.sounds.play("bird", node.global_position, 0.82, 0.35)
	bird.mode = "flee"
	bird.age = 0.0
	bird.from = node.position
	var away := node.position - (away_from_world - ORIGIN)
	away.y = 0
	if away.length() < 0.1: away = Vector3(1, 0, 0)
	bird.escape = Vector3(clampf(node.position.x + away.normalized().x * 14.0, -68, 68), 14.5, clampf(node.position.z + away.normalized().z * 14.0, -68, 68))

func _pose_bird(bird: Dictionary, open: float, flap: float) -> void:
	bird.body.rotation.x = 0.12 * open
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		bird.feathers[i].position = Vector3(side * 0.01, -0.02, 0.045).lerp(Vector3(side * 0.20, 0, 0), open)
		bird.feathers[i].scale = Vector3(0.065, 0.18, 0.31).lerp(Vector3(0.45, 0.05, 0.22), open)
		bird.wings[i].rotation.z = -side * sin(flap) * 0.8 * open
		bird.legs[i].rotation.x = lerpf(0.0, -1.1, open)

func _update_snowfall(dt: float) -> void:
	if not is_instance_valid(snow_batch): return
	var mm := snow_batch.multimesh
	for i in snow_motes.size():
		var m := snow_motes[i]
		var p: Vector3 = m.pos
		p.y -= float(m.speed) * dt
		p.x += sin(animation_clock * 0.9 + float(m.phase)) * 0.65 * dt
		p.z += cos(animation_clock * 0.7 + float(m.phase)) * 0.45 * dt
		if p.y < 0.1:
			p.y = 22.0
			p.x = wrapf(p.x, -74.0, 74.0)
			p.z = wrapf(p.z, -74.0, 74.0)
		m.pos = p
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * float(m.size)), p))

# --- Owl Ladder Rescue ---
func _on_owl_ladder_reached(engine: FireEngine) -> void:
	if owl_rescue_running or owl_rescued: return
	if game.dialogue_active: game.end_dialogue()
	owl_rescue_running = true
	game.sounds.play("owl", owl.global_position, 1.0, 0.5)
	engine.enabled = false
	engine.charge = 0
	engine.linear_velocity = Vector3.ZERO
	engine.angular_velocity = Vector3.ZERO
	engine.freeze = true
	engine.ladder_busy = true

	var start := owl.global_position
	var tip := engine.ladder_tip.global_position + Vector3.UP * 0.06
	var base := engine.ladder.global_position + Vector3.UP * 0.08
	var astrid := people[2]
	var perch_arm := astrid.global_transform * Vector3(-0.45, 1.38, -0.35)
	var wl: Node3D = owl.get_node_or_null("WingLeft")
	var wr: Node3D = owl.get_node_or_null("WingRight")
	owl.look_at(base, Vector3.UP)
	owl_rescue_tween = create_tween()
	owl_rescue_tween.tween_method(func(t: float) -> void:
		owl.global_position = start.lerp(tip, t) + Vector3.UP * sin(t * PI) * 0.75
		if wl and wr:
			wl.rotation.z = -absf(sin(t * TAU * 4.0)) * 0.9
			wr.rotation.z = absf(sin(t * TAU * 4.0)) * 0.9, 0.0, 1.0, 0.55)
	owl_rescue_tween.tween_method(func(t: float) -> void:
		owl.global_position = tip.lerp(base, t) + Vector3.UP * absf(sin(t * TAU * 5.0)) * 0.08
		if wl and wr:
			wl.rotation.z = -absf(sin(t * TAU * 5.0)) * 0.55
			wr.rotation.z = absf(sin(t * TAU * 5.0)) * 0.55, 0.0, 1.0, 1.35)
	owl_rescue_tween.tween_callback(func() -> void:
		owl.look_at(Vector3(astrid.global_position.x, owl.global_position.y, astrid.global_position.z)))
	owl_rescue_tween.tween_method(func(t: float) -> void:
		owl.global_position = base.lerp(perch_arm, t) + Vector3.UP * sin(t * PI) * 1.15
		owl.scale = Vector3.ONE * lerpf(1.0, 0.78, t)
		if wl and wr:
			wl.rotation.z = -absf(sin(t * TAU * 5.0)) * 0.95
			wr.rotation.z = absf(sin(t * TAU * 5.0)) * 0.95, 0.0, 1.0, 0.85)
	owl_rescue_tween.tween_callback(func() -> void:
		if wl and wr:
			wl.rotation.z = 0.0
			wr.rotation.z = 0.0
		owl.reparent(astrid)
		owl.position = Vector3(-0.45, 1.38, -0.35)
		owl.rotation = Vector3.ZERO
		owl_rescued = true
		owl_rescue_running = false
		if is_instance_valid(owl_tree_prop): owl_tree_prop.locked = false
		engine.freeze = false
		engine.release_ladder()
		game.rewards.celebrate("winter_owl", astrid.global_position + Vector3.UP * 1.4, "ASTRID", "Welcome back, Snowball! Thank you for bringing our little snowy owl safely down from the pine!"))

# --- Winter Conversations ---
func proximity_talk() -> void:
	if game.dialogue_control.waiting_for_phone or game.dialogue_active or owl_rescue_running: return
	for i in people.size():
		if game.rewards.waiting_for(NAMES[i]): continue
		var d: float = game.truck.global_position.distance_to(people[i].global_position)
		if d > 11.0: chatter_latches.erase(i)
		if d < 7.5 and not chatter_latches.has(i) and game.truck.linear_velocity.length() < 5.0:
			if not attention_text(i).is_empty(): continue
			talk_to_person(i, false)
			break

func attention_text(index: int) -> String:
	if index < 0 or index >= people.size() or game.rewards.waiting_for(NAMES[index]): return ""
	if game.dialogue_control.has_spoken(people[index]): return ""
	var needs: bool = [not rink_done, not bonfire_done, not owl_rescued, not sled_done][index]
	return "Oh, help please!" if needs else ""

func talk_to_person(index: int, manual: bool = true) -> bool:
	if index < 0 or index >= people.size() or game.paused or owl_rescue_running: return false
	if not manual: return false
	var words: String
	var subtitle: String
	var needs: bool = [not rink_done, not bonfire_done, not owl_rescued, not sled_done][index]
	match index:
		0:
			subtitle = "SKATING RINK"
			words = "The rink is sparkling! Try taking the fire engine onto the ice for a spin!" if rink_done else "Welcome to Frostpine Hollow! It's so chilly here that water freezes right where you spray it — watch out, it's slippery! Could you hose down our wooden rink to lay down a fresh sheet of ice?"
		1:
			subtitle = "COCOA LODGE"
			words = "Warm cocoa, zero runaway sparks! Thank you again, Unit 04." if bonfire_done else "Our winter bonfire got a bit carried away! Spray down the flames before the lodge roof melts — just watch your wheels on the ice your hose makes!"
		2:
			subtitle = "PINE GROVE"
			words = "Snowball is cosy on my shoulder now. Thank you for the gentle rescue!" if owl_rescued else "Snowball our snowy owl flew up into that frosted pine and got her scarf snagged! Press {interact} to extend your ladder and bring its tip close to her."
		3:
			subtitle = "SLED DELIVERY"
			words = "Cocoa crates safe at the lodge! That icy shortcut worked wonders." if sled_done else ("This supply sled is way too heavy to push through deep snow! Try spraying water along the snow lane in front of the runners to freeze an ice track, then push it east to the golden pad!" if sled_pushed_dry else "My winter supply sled is stuck fast in the deep snow! It won't budge on dry drifts, but if you spray water ahead of it to lay down slick ice, you can slide it straight east to the delivery pad!")
	game.talk(NAMES[index] + "  /  " + subtitle, words, game.stage, needs and game.dialogue_control.first_briefing("winter_" + NAMES[index]))
	chatter_latches[index] = true
	return true
