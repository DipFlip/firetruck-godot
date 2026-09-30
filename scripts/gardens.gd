class_name TownGardens
extends Node3D

var game: Node3D
var butterflies: Array[Dictionary]=[]
var time:=0.0
var rng:=RandomNumberGenerator.new()
var flower_count:=0

func _ready() -> void:
	rng.seed=931
	var stems: Array[Transform3D]=[]
	var petals: Array[Transform3D]=[]
	var petal_colors: Array[Color]=[]
	var centers: Array[Transform3D]=[]
	var leaves: Array[Transform3D]=[]
	var leaf_colors: Array[Color]=[]
	var foliage: Array[Transform3D]=[]
	var greens: Array[Color]=[]
	var beds: Array[Vector3]=[Vector3(-10,0,19),Vector3(-20,0,20),Vector3(13,0,26),Vector3(23,0,25),Vector3(13,0,-14),Vector3(-13,0,-14),Vector3(-24,0,-14),Vector3(-20,0,-6),Vector3(44,0,-24),Vector3(54,0,-24),Vector3(-44,0,-17),Vector3(12,0,54),Vector3(-13,0,55),Vector3(55,0,25)]
	var palette: Array[Color]=[Color("f369a4"),Color("9562d4"),Color("ffb835"),Color("fbfbf5"),Color("648ae3")]
	for i in beds.size():
		for n in 13:
			var p:=beds[i]+Vector3(rng.randf_range(-1.15,1.15),.1,rng.randf_range(-.65,.65))
			var height:=rng.randf_range(.28,.52)
			stems.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.028,height,.028)),p+Vector3.UP*height*.5))
			var head:=p+Vector3.UP*height
			centers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.095,.065,.095)),head+Vector3.UP*.025))
			for petal in 5:
				var a:=petal*TAU/5
				petals.append(Transform3D(Basis(Vector3.UP,a).scaled(Vector3(.17,.065,.11)),head+Vector3(cos(a)*.115,0,sin(a)*.115)))
				petal_colors.append(palette[i%palette.size()])
			flower_count+=1
		_butterfly(beds[i],palette[(i+2)%palette.size()],i)
	# Low leafy plants around gardens. Individual leaves replace rounded mounds.
	for p in [Vector3(-25,0,11),Vector3(10,0,24),Vector3(27,0,14),Vector3(-26,0,-12),Vector3(55,0,-9),Vector3(-47,0,31),Vector3(9,0,47),Vector3(48,0,47),Vector3(-12,0,24),Vector3(26,0,53)]:
		for i in 14:
			var angle:=i*2.4
			var size:=rng.randf_range(.7,1.2)
			var basis:=Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,-.5)
			foliage.append(Transform3D(basis.scaled_local(Vector3(.16,.07,.64)*size),p+Vector3(sin(angle)*.24,.24+rng.randf()*.2,cos(angle)*.24)))
			greens.append(Color("308c55") if i%2 else Color("56a852"))
	# Scattered, flat fallen leaves stay small and leave driving routes clear.
	for trunk in [Vector3(-26,0,9),Vector3(-27,0,-10),Vector3(9,0,23),Vector3(27,0,13),Vector3(56,0,-8),Vector3(9,0,46),Vector3(48,0,46),Vector3(17,0,-10)]:
		for i in 18:
			var a:=rng.randf()*TAU
			var r:=rng.randf_range(.5,2)
			leaves.append(Transform3D(Basis(Vector3.UP,a).scaled(Vector3(.12,.035,.24)*rng.randf_range(.6,1.1)),trunk+Vector3(cos(a)*r,.12,sin(a)*r)))
			leaf_colors.append([Color("d69449"),Color("a9b74a"),Color("ba6941")][i%3])
	var sphere:=SphereMesh.new()
	sphere.radial_segments=8
	sphere.rings=4
	_batch(sphere,petals,petal_colors,Color.WHITE)
	_batch(sphere,centers,[],Color("ffd04c"))
	_batch(sphere,foliage,greens,Color.WHITE)
	_batch(sphere,leaves,leaf_colors,Color.WHITE)
	var stem:=CylinderMesh.new()
	stem.top_radius=.5
	stem.bottom_radius=.5
	stem.height=1
	stem.radial_segments=5
	_batch(stem,stems,[],Color("3b9858"))

func _batch(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], color: Color) -> void:
	var batch:=MultiMeshInstance3D.new()
	var instances:=MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.use_colors=true
	instances.mesh=mesh
	instances.instance_count=transforms.size()
	for i in transforms.size():
		instances.set_instance_transform(i,transforms[i])
		instances.set_instance_color(i,colors[i] if not colors.is_empty() else color)
	batch.multimesh=instances
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=.85
	batch.material_override=material
	add_child(batch)

func _butterfly(center: Vector3, color: Color, index: int) -> void:
	var butterfly:=Node3D.new()
	add_child(butterfly)
	TownProps.ball(butterfly,Vector3.ZERO,Vector3(.045,.06,.23),Color("39464e"))
	var wings: Array[Node3D]=[]
	for side in [-1,1]:
		var wing:=Node3D.new()
		butterfly.add_child(wing)
		TownProps.ball(wing,Vector3(side*.14,0,-.07),Vector3(.28,.025,.25),color)
		TownProps.ball(wing,Vector3(side*.11,0,.08),Vector3(.20,.025,.19),color.lightened(.18))
		TownProps.ball(wing,Vector3(side*.19,.017,-.09),Vector3(.07,.025,.075),Color("fff9eb"))
		wings.append(wing)
	butterflies.append({"node":butterfly,"wings":wings,"center":center,"phase":index*1.37})

func _process(dt: float) -> void:
	if game.paused: return
	time+=dt
	for b in butterflies:
		var t: float=time*.65+b.phase
		b.node.position=b.center+Vector3(cos(t)*1.15,1.0+sin(t*1.7)*.35,sin(t*1.3)*.8)
		b.node.rotation.y=-t
		b.wings[0].rotation.z=.2+sin(time*24+b.phase)*1.0
		b.wings[1].rotation.z=-b.wings[0].rotation.z
