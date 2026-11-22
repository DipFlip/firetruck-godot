class_name IceField
extends Node3D

# Continuous organic ice sheet formed whenever water hits snow or cold roads
# in Frostpine Hollow. Uses a 256x256 world-space scalar field rendered in one
# draw call via ice_sheet.gdshader so sprayed puddles merge seamlessly and grow
# horizontally as more water is added, with 1:1 matching slip physics.

const GRID := 256
const HALF_EXTENT := 78.0
const CELL_SIZE := (HALF_EXTENT * 2.0) / float(GRID)
const BASE_LIFETIME := 48.0
const FADE_SECONDS := 5.0
const UPLOAD_INTERVAL := 0.035

var field := PackedFloat32Array()
var life_field := PackedFloat32Array()
var perm_field := PackedByteArray()
var tex_bytes := PackedByteArray()
var active_cells: Dictionary = {}
var image: Image
var mask_texture: ImageTexture
var sheet_mesh: MeshInstance3D
var dirty := false
var upload_cooldown := 0.0
var freeze_sound_cooldown := 0.0
var static_zones: Array[Dictionary] = []

func _ready() -> void:
	name = "IceField"
	var count := GRID * GRID
	field.resize(count)
	field.fill(0.0)
	life_field.resize(count)
	life_field.fill(0.0)
	perm_field.resize(count)
	perm_field.fill(0)
	tex_bytes.resize(count)
	tex_bytes.fill(0)

	image = Image.create_from_data(GRID, GRID, false, Image.FORMAT_R8, tex_bytes)
	mask_texture = ImageTexture.create_from_image(image)

	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_EXTENT * 2.0, HALF_EXTENT * 2.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ice_sheet.gdshader")
	mat.set_shader_parameter("ice_mask", mask_texture)

	sheet_mesh = MeshInstance3D.new()
	sheet_mesh.name = "IceSheetMesh"
	sheet_mesh.mesh = plane
	sheet_mesh.material_override = mat
	sheet_mesh.position = Vector3(0.0, 0.072, 0.0)
	sheet_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet_mesh.custom_aabb = AABB(Vector3(-82, -1, -82), Vector3(164, 4, 164))
	add_child(sheet_mesh)

func add_zone(rect: Rect2, slip_fn: Callable) -> void:
	static_zones.append({"rect": rect, "slip": slip_fn})

func _world_to_grid(x: float, z: float) -> Vector2:
	var gx := ((x + HALF_EXTENT) / (HALF_EXTENT * 2.0)) * float(GRID) - 0.5
	var gz := ((z + HALF_EXTENT) / (HALF_EXTENT * 2.0)) * float(GRID) - 0.5
	return Vector2(gx, gz)

func _organic_bias(ix: int, iz: int) -> float:
	# Gentle deterministic directional bias so growing ice spreads organically rather than in rigid circles.
	var a := sin(float(ix) * 0.53 + float(iz) * 0.31) * cos(float(ix) * 0.27 - float(iz) * 0.49)
	var b := sin(float(ix) * 1.17 - float(iz) * 0.89)
	return 1.0 + a * 0.22 + b * 0.10

func deposit(local_point: Vector3, amount: float, permanent: bool = false, _floor_y: float = 0.055) -> bool:
	if local_point.y > 0.85 or absf(local_point.x) > 77.0 or absf(local_point.z) > 77.0:
		return false
	var g := _world_to_grid(local_point.x, local_point.z)
	var cx := clampi(roundi(g.x), 1, GRID - 2)
	var cz := clampi(roundi(g.y), 1, GRID - 2)
	var center_val := field[cz * GRID + cx]

	# Water spreads further horizontally as more water pools onto an already-wet spot!
	var spread_world := lerpf(1.85, 3.75, clampf(center_val * 1.05, 0.0, 1.0))
	var rad_cells := ceili(spread_world / CELL_SIZE)
	var strength := clampf(amount * 5.2, 0.06, 0.48)
	var grew := false

	var min_x := maxi(1, cx - rad_cells)
	var max_x := mini(GRID - 2, cx + rad_cells)
	var min_z := maxi(1, cz - rad_cells)
	var max_z := mini(GRID - 2, cz + rad_cells)

	for iz in range(min_z, max_z + 1):
		var dz := (float(iz) - g.y) * CELL_SIZE
		for ix in range(min_x, max_x + 1):
			var dx := (float(ix) - g.x) * CELL_SIZE
			var eff_r := spread_world * _organic_bias(ix, iz)
			var dist_sq := dx * dx + dz * dz
			if dist_sq >= eff_r * eff_r: continue
			var falloff := 1.0 - sqrt(dist_sq) / eff_r
			var add := strength * falloff * falloff * 2.4
			var idx := iz * GRID + ix
			var prev := field[idx]
			var next := minf(1.0, prev + add)
			if next - prev > 0.008:
				grew = true
			field[idx] = next
			life_field[idx] = BASE_LIFETIME
			if permanent:
				perm_field[idx] = 1
			active_cells[idx] = true
			tex_bytes[idx] = clampi(roundi(next * 255.0), 0, 255)

	# Horizontal overflow diffusion: saturated cells spill outward into neighboring snow
	# so continuous spraying steadily widens the frozen ice sheet organically!
	if center_val > 0.45:
		for iz in range(min_z, max_z + 1):
			for ix in range(min_x, max_x + 1):
				var idx := iz * GRID + ix
				var v := field[idx]
				if v <= 0.62: continue
				var spill := (v - 0.62) * 0.26
				for n_off in [1, -1, GRID, -GRID]:
					var n_idx := idx + int(n_off)
					var nv := field[n_idx]
					if nv < v - 0.04:
						var next_n := minf(1.0, nv + spill)
						field[n_idx] = next_n
						life_field[n_idx] = maxf(life_field[n_idx], BASE_LIFETIME)
						if permanent:
							perm_field[n_idx] = 1
						active_cells[n_idx] = true
						tex_bytes[n_idx] = clampi(roundi(next_n * 255.0), 0, 255)
						if next_n - nv > 0.008:
							grew = true

	if grew or center_val > 0.0:
		dirty = true
	return grew

func _sample_field(x: float, z: float) -> float:
	if absf(x) > HALF_EXTENT or absf(z) > HALF_EXTENT:
		return 0.0
	var g := _world_to_grid(x, z)
	var x0 := clampi(floori(g.x), 0, GRID - 2)
	var z0 := clampi(floori(g.y), 0, GRID - 2)
	var fx := clampf(g.x - float(x0), 0.0, 1.0)
	var fz := clampf(g.y - float(z0), 0.0, 1.0)
	var i00 := z0 * GRID + x0
	var v0 := lerpf(field[i00], field[i00 + 1], fx)
	var v1 := lerpf(field[i00 + GRID], field[i00 + GRID + 1], fx)
	return lerpf(v0, v1, fz)

func slip_at(local_point: Vector3) -> float:
	var best := 0.0
	var p2 := Vector2(local_point.x, local_point.z)
	for zone in static_zones:
		if (zone.rect as Rect2).has_point(p2):
			best = maxf(best, float(zone.slip.call(p2)))
	var v := _sample_field(local_point.x, local_point.z)
	if v > 0.16:
		best = maxf(best, smoothstep(0.18, 0.68, v))
	return clampf(best, 0.0, 1.0)

func patch_count() -> int:
	var frozen := 0
	for idx in active_cells:
		if field[int(idx)] >= 0.22:
			frozen += 1
	return frozen

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
	upload_cooldown = maxf(0.0, upload_cooldown - dt)

	var expired: Array[int] = []
	for key in active_cells:
		var idx := int(key)
		if perm_field[idx] != 0: continue
		var rem := life_field[idx] - dt
		life_field[idx] = rem
		if rem <= 0.0:
			field[idx] = 0.0
			tex_bytes[idx] = 0
			expired.append(idx)
			dirty = true
		elif rem < FADE_SECONDS:
			var fade := clampf(rem / FADE_SECONDS, 0.0, 1.0)
			var shown := clampi(roundi(field[idx] * fade * 255.0), 0, 255)
			if tex_bytes[idx] != shown:
				tex_bytes[idx] = shown
				dirty = true
	for idx in expired:
		active_cells.erase(idx)

	if dirty and upload_cooldown <= 0.0:
		image.set_data(GRID, GRID, false, Image.FORMAT_R8, tex_bytes)
		mask_texture.update(image)
		dirty = false
		upload_cooldown = UPLOAD_INTERVAL
