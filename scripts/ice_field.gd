class_name IceField
extends Node3D

# Grid-backed glossy ice patches formed whenever water hits snow or cold roads
# in Frostpine Hollow. Rendered through one MultiMeshInstance3D (1 draw call)
# and queried in O(1) by FireEngine and the winter supply sled for slip physics.

const MAX_PATCHES := 360
const CELL_SIZE := 2.2
const BASE_LIFETIME := 48.0
const FADE_SECONDS := 5.0

var patches: Array[Dictionary] = []
var cell_map: Dictionary = {}
var batch: MultiMeshInstance3D
var dirty := false
var freeze_sound_cooldown := 0.0
var static_zones: Array[Dictionary] = []

func _ready() -> void:
	name = "IceField"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.04
	disc.height = 0.028
	disc.radial_segments = 16
	disc.rings = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.92, 0.99, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.09
	mat.metallic = 0.06
	mat.metallic_specular = 0.92
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.90
	mat.clearcoat_roughness = 0.08
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true

	batch = MultiMeshInstance3D.new()
	batch.name = "IcePatchBatch"
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = disc
	mm.instance_count = MAX_PATCHES
	mm.visible_instance_count = 0
	batch.multimesh = mm
	batch.material_override = mat
	batch.custom_aabb = AABB(Vector3(-82, -1, -82), Vector3(164, 4, 164))
	add_child(batch)

func add_zone(rect: Rect2, slip_fn: Callable) -> void:
	static_zones.append({"rect": rect, "slip": slip_fn})

func deposit(local_point: Vector3, amount: float, permanent: bool = false, floor_y: float = 0.055) -> bool:
	if local_point.y > 0.85 or absf(local_point.x) > 77.0 or absf(local_point.z) > 77.0:
		return false
	var cell := Vector2i(floori(local_point.x / CELL_SIZE), floori(local_point.z / CELL_SIZE))
	var grew := false
	if cell_map.has(cell):
		var patch: Dictionary = patches[int(cell_map[cell])]
		var prev := float(patch.strength)
		patch.strength = minf(1.0, prev + amount * 3.8)
		patch.life = BASE_LIFETIME
		if permanent: patch.permanent = true
		grew = patch.strength - prev > 0.015
		dirty = true
	else:
		var slot := _allocate_slot()
		if slot < 0: return false
		var jitter := Vector2(sin(cell.x * 12.7 + cell.y * 31.1), cos(cell.x * 23.3 - cell.y * 17.9)) * 0.25
		var pos := Vector3(local_point.x + jitter.x, floor_y, local_point.z + jitter.y)
		var patch := {
			"cell": cell,
			"pos": pos,
			"strength": clampf(0.32 + amount * 6.0, 0.32, 1.0),
			"life": BASE_LIFETIME,
			"permanent": permanent,
			"yaw": fposmod(cell.x * 1.7 + cell.y * 2.9, TAU),
			"squash": 0.84 + fposmod(absf(cell.x * 0.37 + cell.y * 0.61), 0.32),
		}
		if slot < patches.size():
			cell_map.erase(patches[slot].cell)
			patches[slot] = patch
		else:
			patches.append(patch)
		cell_map[cell] = slot
		grew = true
		dirty = true
	return grew

func _allocate_slot() -> int:
	if patches.size() < MAX_PATCHES:
		return patches.size()
	# Recycle the oldest non-permanent patch.
	var best := -1
	var min_life := INF
	for i in patches.size():
		if patches[i].permanent: continue
		if patches[i].life < min_life:
			min_life = patches[i].life
			best = i
	return best

func slip_at(local_point: Vector3) -> float:
	var best := 0.0
	var p2 := Vector2(local_point.x, local_point.z)
	for zone in static_zones:
		if (zone.rect as Rect2).has_point(p2):
			best = maxf(best, float(zone.slip.call(p2)))
	var cx := floori(local_point.x / CELL_SIZE)
	var cz := floori(local_point.z / CELL_SIZE)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not cell_map.has(key): continue
			var patch: Dictionary = patches[int(cell_map[key])]
			var fade := 1.0 if patch.permanent else clampf(patch.life / FADE_SECONDS, 0.0, 1.0)
			if fade <= 0.01: continue
			var radius := lerpf(1.15, 2.35, float(patch.strength))
			var dist := p2.distance_to(Vector2(patch.pos.x, patch.pos.z))
			if dist < radius:
				var coverage := smoothstep(radius, radius * 0.35, dist)
				best = maxf(best, coverage * float(patch.strength) * fade)
	return clampf(best, 0.0, 1.0)

func patch_count() -> int:
	return patches.size()

func coverage_in_rect(rect: Rect2, samples_x: int = 8, samples_z: int = 3) -> float:
	var covered := 0.0
	var total := float(samples_x * samples_z)
	for ix in samples_x:
		for iz in samples_z:
			var x := lerpf(rect.position.x, rect.end.x, (ix + 0.5) / float(samples_x))
			var z := lerpf(rect.position.y, rect.end.y, (iz + 0.5) / float(samples_z))
			if slip_at(Vector3(x, 0.0, z)) >= 0.30:
				covered += 1.0
	return covered / maxf(1.0, total)

func _process(dt: float) -> void:
	freeze_sound_cooldown = maxf(0.0, freeze_sound_cooldown - dt)
	var expired := false
	for i in range(patches.size() - 1, -1, -1):
		var patch: Dictionary = patches[i]
		if patch.permanent: continue
		patch.life -= dt
		if patch.life <= 0.0:
			cell_map.erase(patch.cell)
			patches.remove_at(i)
			expired = true
		elif patch.life < FADE_SECONDS:
			dirty = true
	if expired:
		cell_map.clear()
		for i in patches.size():
			cell_map[patches[i].cell] = i
		dirty = true
	if dirty:
		_rebuild_batch()
		dirty = false

func _rebuild_batch() -> void:
	var mm := batch.multimesh
	var count := mini(patches.size(), MAX_PATCHES)
	mm.visible_instance_count = count
	for i in count:
		var patch: Dictionary = patches[i]
		var fade := 1.0 if patch.permanent else clampf(patch.life / FADE_SECONDS, 0.0, 1.0)
		var r := lerpf(1.05, 2.25, float(patch.strength)) * lerpf(0.75, 1.0, fade)
		var basis := Basis(Vector3.UP, float(patch.yaw)).scaled(Vector3(r, 1.0, r * float(patch.squash)))
		mm.set_instance_transform(i, Transform3D(basis, patch.pos))
		var tint := Color(0.84, 0.96, 1.0, 1.0).lerp(Color(0.68, 0.90, 0.99, 1.0), float(patch.strength))
		tint.a = fade * (0.62 + 0.34 * float(patch.strength))
		mm.set_instance_color(i, tint)
