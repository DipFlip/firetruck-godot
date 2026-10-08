class_name Playroom
extends Node3D

const WALL_LAYER:=32
const WALL_INNER:=79.6
var walls: Array[StaticBody3D]=[]
var floor_art: MeshInstance3D
var block_sizes: Array[Vector3]=[]
var painted_blocks:=0
var room_props: Node3D

func _ready() -> void:
	name="Playroom"
	var floor_finish:=wood_finish(Color("c6a47e"),true)
	floor_finish.set_shader_parameter("cut_pool",true)
	floor_finish.set_shader_parameter("pool_hole",Vector4(TownLayout.POOL.x-4.4,TownLayout.POOL.z-2.4,TownLayout.POOL.x+4.4,TownLayout.POOL.z+2.4))
	floor_art=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(800,800)
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
	blocks.name="BoundaryBlocks"
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
				if axis==1 and side==-1 and along>=-8.0 and along<8.0:
					along=8.0
				var end:=NorthlineRailway.TRACK_Z-4.7 if axis==0 and along<NorthlineRailway.TRACK_Z-4.7 else 82.0
				if axis==1 and side==-1 and along< -8.0: end=-8.0
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
	room_props=make_room_props(self)

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

static func make_room_props(parent: Node3D) -> Node3D:
	var room:=Node3D.new()
	room.name="RoomFurnitureAndForgottenToys"
	room.set_meta("room_backdrop",true)
	parent.add_child(room)
	room.position.y=-1.03
	var back_wall:=MeshInstance3D.new()
	back_wall.name="StarryWallpaper"
	var wallpaper_plane:=QuadMesh.new()
	wallpaper_plane.size=Vector2(600,180)
	back_wall.mesh=wallpaper_plane
	var wallpaper:=ShaderMaterial.new()
	wallpaper.shader=preload("res://shaders/star_wallpaper.gdshader")
	back_wall.material_override=wallpaper
	back_wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(back_wall)
	back_wall.position=Vector3(0,90,-154)
	TownProps.box(room,Vector3(0,3,-152),Vector3(600,6,4),Color("d9ba91"))
	var west_wall:=MeshInstance3D.new()
	west_wall.name="WestStarryWallpaper"
	west_wall.mesh=wallpaper_plane
	west_wall.material_override=wallpaper
	west_wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(west_wall)
	west_wall.position=Vector3(-154,90,0)
	west_wall.rotation.y=PI/2
	TownProps.box(room,Vector3(-152,3,0),Vector3(4,6,600),Color("d9ba91"))
	# A child's room uses larger objects than the little traffic-mat town.
	var drawers:=Node3D.new()
	room.add_child(drawers)
	drawers.position=Vector3(-124,0,-115)
	TownProps.box(drawers,Vector3(0,33,0),Vector3(52,66,31),Color("b99369"))
	TownProps.box(drawers,Vector3(0,67,0),Vector3(56,3,35),Color("d9b990"))
	for y in [12,33,54]:
		TownProps.box(drawers,Vector3(0,y,16),Vector3(47,18,2),Color("ead5b0"))
		for x in [-14,14]: TownProps.ball(drawers,Vector3(x,y,18),Vector3(3.4,3.4,3),Color("749c9c"))
	# A low upholstered chair, with visible wooden legs and an uneven cushion.
	var chair:=Node3D.new()
	room.add_child(chair)
	chair.position=Vector3(123,0,-107)
	chair.rotation.y=-.25
	for x in [-19,19]:
		for z in [-18,18]: TownProps.box(chair,Vector3(x,16,z),Vector3(5,32,5),Color("bc9870"))
	TownProps.box(chair,Vector3(0,33,0),Vector3(48,10,46),Color("557e8b"))
	TownProps.box(chair,Vector3(0,39,2),Vector3(42,5,38),Color("7dabb4"))
	TownProps.box(chair,Vector3(0,62,-20),Vector3(48,49,8),Color("557e8b"))
	TownProps.box(chair,Vector3(0,62,-15.7),Vector3(39,37,2),Color("7dabb4"))
	for x in [-24,24]: TownProps.box(chair,Vector3(x,47,1),Vector3(6,9,43),Color("bc9870"))
	# Basketball seams are mesh rings, so they remain attached to the ball.
	var ball:=Node3D.new()
	room.add_child(ball)
	ball.position=Vector3(119,12.1,60)
	ball.rotation=Vector3(.3,.2,.6)
	TownProps.ball(ball,Vector3.ZERO,Vector3.ONE*24,Color("cf7841"))
	for angle in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(0,0,PI/2)]:
		var seam:=MeshInstance3D.new()
		var ring:=TorusMesh.new()
		ring.inner_radius=11.88
		ring.outer_radius=12.13
		ring.rings=48
		ring.ring_segments=8
		seam.mesh=ring
		seam.material_override=TownProps.material(Color("67452f"))
		ball.add_child(seam)
		seam.rotation=angle
	# A mismatched pair of sneakers, left just outside the western edge.
	for i in 2:
		var shoe:=Node3D.new()
		room.add_child(shoe)
		shoe.position=Vector3(-119-i*12,0,51-i*20)
		shoe.rotation.y=.4-i*.9
		TownProps.box(shoe,Vector3(0,2,0),Vector3(28,4,12),Color("e9dfc9"))
		TownProps.ball(shoe,Vector3(5,5,0),Vector3(19,8,11),Color("799ca5"))
		TownProps.box(shoe,Vector3(-7,7.5,0),Vector3(10,13,11),Color("799ca5"))
		TownProps.ball(shoe,Vector3(-7,14,0),Vector3(8,1.4,8),Color("394b55"))
		TownProps.box(shoe,Vector3(9,4,0),Vector3(9,3,12),Color("e9dfc9"))
		for x in [-2,1,4,7]: TownProps.box(shoe,Vector3(x,9-.16*x,0),Vector3(.65,.65,7),Color("f5eddb"))
	var bin:=Node3D.new()
	room.add_child(bin)
	bin.position=Vector3(-118,0,-51)
	bin.name="OpenWastepaperBasket"
	var basket:=TownProps.cylinder(bin,Vector3(0,14,0),9.5,28,Color("81968e"),12)
	var hollow:=basket.mesh.duplicate() as CylinderMesh
	hollow.cap_top=false
	hollow.radial_segments=48
	basket.mesh=hollow
	var finish:=TownProps.material(Color("81968e")).duplicate() as StandardMaterial3D
	finish.cull_mode=BaseMaterial3D.CULL_DISABLED
	basket.material_override=finish
	TownProps.cylinder(bin,Vector3(0,.5,0),9.3,1,Color("425b55"))
	var rim:=MeshInstance3D.new()
	var ring:=TorusMesh.new()
	ring.inner_radius=11.3
	ring.outer_radius=12.7
	rim.mesh=ring
	rim.material_override=TownProps.material(Color("afbeb0"))
	bin.add_child(rim)
	rim.position.y=28
	for i in 20:
		var angle:=i*TAU/20
		var bottom:=Vector3(cos(angle)*9.6,1,sin(angle)*9.6)
		var top:=Vector3(cos(angle)*11.95,27,sin(angle)*11.95)
		var rib:=TownProps.cylinder(bin,(bottom+top)*.5,.22,bottom.distance_to(top),Color("93a79e"))
		rib.quaternion=Quaternion(Vector3.UP,(top-bottom).normalized())

	for i in 4:
		var paper:=TownProps.box(bin,Vector3(-4+i*2.8,11+i*2,-2+sin(i)*3),Vector3(6,5,5),Color("f0e4ca"))
		paper.rotation=Vector3(i*.8,i*1.2,i*.4)

	# An old wooden pull train and a teddy, away from either town's exit.
	for i in 3:
		var toy:=Node3D.new()
		room.add_child(toy)
		toy.position=Vector3(20+i*23,0,115+i*2)
		toy.rotation.y=-.12
		TownProps.box(toy,Vector3(0,6,0),Vector3(20,6,11),Color("c18059"))
		TownProps.box(toy,Vector3(-4,12,0),Vector3(9,8,10),Color("5f9497") if i==0 else Color("cda55e"))
		if i==0: TownProps.cylinder(toy,Vector3(5,13,0),2,9,Color("5f9497"))
		for x in [-6,6]:
			for z in [-6,6]:
				var wheel:=TownProps.cylinder(toy,Vector3(x,3,z),3,1.7,Color("495c62"))
				wheel.rotation.x=PI/2
	var teddy:=Node3D.new()
	room.add_child(teddy)
	teddy.position=Vector3(118,0,-9)
	teddy.rotation.y=-.4
	TownProps.ball(teddy,Vector3(0,9,0),Vector3(13,17,9),Color("b98b5c"))
	TownProps.ball(teddy,Vector3(0,20,0),Vector3(13,12,11),Color("b98b5c"))
	for x in [-5,5]:
		TownProps.ball(teddy,Vector3(x,25,0),Vector3(5,5,4),Color("b98b5c"))
		TownProps.ball(teddy,Vector3(x,3,4),Vector3(6,6,9),Color("b98b5c"))
		TownProps.ball(teddy,Vector3(x*1.5,12,0),Vector3(5,11,5),Color("b98b5c"))
		TownProps.ball(teddy,Vector3(x*.5,21,5),Vector3.ONE*1.1,Color("3d4241"))
	TownProps.ball(teddy,Vector3(0,18,5.2),Vector3(6,4,3),Color("dec298"))
	TownProps.ball(teddy,Vector3(0,19,7),Vector3(2,1.5,1),Color("3d4241"))
	TownProps.merge_fixed_geometry(room,[],"room_decor")
	return room
