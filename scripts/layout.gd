class_name TownLayout
extends RefCounted

# One source of truth for mission props, navigation, effects and the map.
const MAYA := Vector3(12,0,-7)
const FIRE := Vector3(49,0,-19)
const LEO := Vector3(46,0,-12)
const DOG := Vector3(-47,0,-9)
const JUNE := Vector3(-49,0,-7)
const POOL := Vector3(22,0,58)
const OLIVER := Vector3(10,0,57)

# Deterministic planting for the editable baked town and future scene rebuilds.
# Mixed grove proposals and open-lawn proposals avoid a circular boundary.
static func woodland_positions() -> Array[Vector3]:
	var rng:=RandomNumberGenerator.new()
	rng.seed=7821
	var planted: Array[Vector3]=[Vector3(17,0,-10),Vector3(-26,0,9),Vector3(-27,0,-10),Vector3(9,0,23),Vector3(27,0,13),Vector3(-10,0,26),Vector3(56,0,-8),Vector3(-49,0,30),Vector3(9,0,46),Vector3(48,0,46),Vector3(-48,0,47)]
	var houses: Array[Vector3]=[Vector3(-15,0,13),Vector3(18,0,19),Vector3(19,0,-20),Vector3(-19,0,-20),Vector3(49,0,18),Vector3(-48,0,18),Vector3(18,0,49),Vector3(-19,0,49),Vector3(-49,0,-22),Vector3(49,0,-29)]
	var groves: Array[Vector3]=[Vector3(-63,0,-58),Vector3(-61,0,61),Vector3(62,0,-61),Vector3(62,0,59),Vector3(-17,0,-53),Vector3(20,0,-54),Vector3(-59,0,0),Vector3(55,0,0),Vector3(-19,0,20),Vector3(18,0,14)]
	var result: Array[Vector3]=[]
	for attempt in 5000:
		var p:=Vector3(rng.randf_range(-74,74),0,rng.randf_range(-74,74))
		if rng.randf()<.65:
			p=groves[rng.randi_range(0,groves.size()-1)]+Vector3(rng.randf_range(-12,12),0,rng.randf_range(-12,12))
		if absf(p.x)>74 or absf(p.z)>74: continue
		var clear:=true
		for road in [-36,0,36]:
			if (absf(p.z)<67 and absf(p.x-road)<9) or (absf(p.x)<67 and absf(p.z-road)<9): clear=false
		for house in houses:
			# The house footprint plus canopy clearance and its front garden/path.
			if absf(p.x-house.x)<8 and p.z>house.z-7 and p.z<house.z+12: clear=false
		for job in [MAYA,LEO,FIRE,DOG,JUNE,POOL,OLIVER]:
			if p.distance_to(job)<11: clear=false
		if p.distance_to(Vector3(-23,0,-10))<6: clear=false # fountain
		for other in planted:
			if p.distance_to(other)<5.8: clear=false
		if not clear: continue
		result.append(p)
		planted.append(p)
		if result.size()==40: break
	return result
