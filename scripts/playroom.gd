class_name Playroom
extends Node3D

const WALL_LAYER:=32
const WALL_INNER:=79.6
var walls: Array[StaticBody3D]=[]
var floor_art: MeshInstance3D
var block_sizes: Array[Vector3]=[]
var painted_blocks:=0

func _ready() -> void:
	name="Playroom"
	var floor_finish:=wood_finish(Color("c6a47e"),true)
	floor_finish.set_shader_parameter("cut_pool",true)
	floor_finish.set_shader_parameter("pool_hole",Vector4(TownLayout.POOL.x-4.4,TownLayout.POOL.z-2.4,TownLayout.POOL.x+4.4,TownLayout.POOL.z+2.4))
	floor_art=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(460,460)
	floor_art.mesh=plane
	floor_art.material_override=floor_finish
	floor_art.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_art)
	floor_art.position.y=-1.03
	# Several timbers, from pale maple to warm cherry, so neighbours rarely match.
	var finishes: Array[ShaderMaterial]=[]
	for tone in ["dcbd8c","d0aa76","e3c79d","c79b67","b98a5c","d8b07c"]: finishes.append(wood_finish(Color(tone)))
	var paint: Array[ShaderMaterial]=[]
	for colour in ["c96959","598eab","d4ac58","699b86"]: paint.append(wood_finish(Color(colour),false,true))
	var rng:=RandomNumberGenerator.new()
	rng.seed=20407
	var blocks:=Node3D.new()
	add_child(blocks)
	# A continuous player-only boundary seals small decorative gaps and train exits.
	for side in [-1,1]:
		_wall(Vector3(side*81,1.2,0),Vector3(2.8,3.6,164.8))
		_wall(Vector3(0,1.2,side*81),Vector3(164.8,3.6,2.8))
		for axis in 2:
			var along:=-82.0
			var index:=0
			var last_finish:=-1
			while along<82.0:
				if axis==0 and along>=NorthlineRailway.TRACK_Z-4.7 and along<NorthlineRailway.TRACK_Z+4.7:
					along=NorthlineRailway.TRACK_Z+4.7
				var end:=NorthlineRailway.TRACK_Z-4.7 if axis==0 and along<NorthlineRailway.TRACK_Z-4.7 else 82.0
				# A mix of long beams, squat cubes and the occasional tall pillar.
				var kind:=rng.randf()
				var length_piece:=rng.randf_range(3.0,3.6) if kind<.18 else rng.randf_range(2.2,2.8) if kind<.26 else rng.randf_range(5.2,12.5)
				length_piece=minf(length_piece,end-along)
				if end-along-length_piece<1.6: length_piece=end-along
				var center:=along+length_piece*.5
				along+=length_piece
				index+=1
				var height:=rng.randf_range(4.2,4.9) if kind>=.18 and kind<.26 else rng.randf_range(2.7,4.0)
				var thickness:=length_piece if kind<.18 else rng.randf_range(2.5,3.4)
				var inset:=rng.randf_range(-.12,.32)
				var p:=Vector3(side*(81+inset),height*.5,center) if axis==0 else Vector3(center,height*.5,side*(81+inset))
				var size:=Vector3(thickness,height,length_piece-.12) if axis==0 else Vector3(length_piece-.12,height,thickness)
				var painted:=rng.randf()<.17
				var block:=TownProps.box(blocks,p,size,Color.WHITE)
				if painted:
					block.material_override=paint[rng.randi_range(0,paint.size()-1)]
					painted_blocks+=1
				else:
					var choice:=rng.randi_range(0,finishes.size()-2)
					if last_finish>=0 and choice>=last_finish: choice+=1
					last_finish=choice
					block.material_override=finishes[choice]
				block.rotation.y=rng.randf_range(-.03,.03)
				block.set_meta("batch_static",true)
				block_sizes.append(size)
				# Now and then a small block is stacked on top, like a child built it.
				if kind>=.26 and length_piece>6.0 and rng.randf()<.16:
					var top_size:=Vector3(rng.randf_range(1.8,2.4),rng.randf_range(1.0,1.5),rng.randf_range(1.8,2.4))
					var offset:=rng.randf_range(-length_piece*.3,length_piece*.3)
					var top_p:=p+Vector3(0,height*.5+top_size.y*.5,0)+(Vector3(0,0,offset) if axis==0 else Vector3(offset,0,0))
					var top:=TownProps.box(blocks,top_p,top_size,Color.WHITE)
					top.material_override=paint[rng.randi_range(0,paint.size()-1)] if rng.randf()<.5 else finishes[rng.randi_range(0,finishes.size()-1)]
					top.rotation.y=rng.randf_range(-.35,.35)
					top.set_meta("batch_static",true)
	for p in [Vector3(-99,.8,40),Vector3(98,.8,13),Vector3(40,.8,98),Vector3(-24,.8,-100)]:
		var block:=TownProps.box(blocks,p,Vector3(rng.randf_range(4,6),1.6,rng.randf_range(2.6,3.4)),Color.WHITE)
		block.material_override=finishes[rng.randi_range(0,finishes.size()-1)]
		block.rotation.y=p.x*.04
		block.set_meta("batch_static",true)
	TownProps.batch_decorations(blocks)

static func wood_finish(color: Color, floorboards: bool=false, painted: bool=false) -> ShaderMaterial:
	var wood:=ShaderMaterial.new()
	wood.shader=preload("res://shaders/wood.gdshader")
	wood.set_shader_parameter("floorboards",floorboards)
	wood.set_shader_parameter("painted",painted)
	wood.set_shader_parameter("timber",color)
	return wood

func _wall(at: Vector3, dimensions: Vector3) -> void:
	var wall:=StaticBody3D.new()
	wall.name="ToyBlockBoundary"
	wall.collision_layer=WALL_LAYER
	wall.collision_mask=1
	wall.add_to_group("wooden_boundary")
	add_child(wall)
	wall.position=at
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=dimensions
	collision.shape=box
	wall.add_child(collision)
	walls.append(wall)
