class_name PoolBasin
extends Node3D

const FLOOR_Y := -1.30
const EMPTY_Y := -1.23
const FULL_Y := -.12
var game: Node3D
var progress:=0.0

func _ready() -> void:
	name="RecessedPool"
	position=TownLayout.POOL
	# Open the sightline to the rising water; move two foreground trees to
	# the outside of the garden, carrying their trunk colliders with them.
	for art in game.town.foliage:
		var tree: Node3D=art.get_parent()
		if tree.position.z>position.z and tree.position.distance_to(position)<12:
			tree.position+=(tree.position-position).normalized()*8
	# Replace only the prototype's raised pool block, preserving the rest of
	# the editable baked town. Its water reference stays valid for gameplay.
	for child in game.town.get_children():
		if not child is MeshInstance3D: continue
		if child.position.distance_to(TownLayout.POOL+Vector3.UP*.35)<.01 and child.scale.is_equal_approx(Vector3(10,.7,6)):
			game.town.remove_child(child)
			child.queue_free()
		if child.scale.x>150 and child.scale.z>150:
			child.material_override.set_shader_parameter("pool_hole",Vector4(TownLayout.POOL.x-4.4,TownLayout.POOL.z-2.4,TownLayout.POOL.x+4.4,TownLayout.POOL.z+2.4))
			child.material_override.set_shader_parameter("cut_pool",true)
			for body in child.get_children():
				if body is StaticBody3D: body.collision_layer=0
	# Four ground slabs leave a genuine collision opening down into the basin.
	var left:=TownLayout.POOL.x-4.4
	var right:=TownLayout.POOL.x+4.4
	var near:=TownLayout.POOL.z-2.4
	var far:=TownLayout.POOL.z+2.4
	_ground_rect(-80,-80,left,80)
	_ground_rect(right,-80,80,80)
	_ground_rect(left,-80,right,near)
	_ground_rect(left,far,right,80)
	var tiles:=ShaderMaterial.new()
	tiles.shader=preload("res://shaders/pool_tiles.gdshader")
	var floor:=TownProps.box(self,Vector3(0,FLOOR_Y-.06,0),Vector3(8.8,.12,4.8),Color.WHITE,true)
	floor.material_override=tiles
	for side in [-1,1]:
		var wall:=TownProps.box(self,Vector3(side*4.7,-.65,0),Vector3(.6,1.3,6),Color.WHITE,true)
		wall.material_override=tiles
		wall=TownProps.box(self,Vector3(0,-.65,side*2.7),Vector3(8.8,1.3,.6),Color.WHITE,true)
		wall.material_override=tiles
		TownProps.box(self,Vector3(side*4.7,.025,0),Vector3(.64,.10,6.1),Color("e6f1f3"),true)
		TownProps.box(self,Vector3(0,.025,side*2.7),Vector3(8.8,.10,.64),Color("e6f1f3"),true)
		# Dark waterline tiles make the rising depth easy to judge.
		TownProps.box(self,Vector3(side*4.395,-.17,0),Vector3(.02,.09,4.8),Color("427d9c"))
		TownProps.box(self,Vector3(0,-.17,side*2.395),Vector3(8.8,.09,.02),Color("427d9c"))
	TownProps.box(self,Vector3(0,FLOOR_Y+.007,0),Vector3(.42,.02,.42),Color("657f90"))
	for i in 4: TownProps.box(self,Vector3(-.14+i*.095,FLOOR_Y+.020,0),Vector3(.025,.01,.3),Color("b5ced7"))
	# Simple stainless pool ladder, with submerged steps visible as it fills.
	for x in [2.8,3.4]:
		TownProps.cylinder(self,Vector3(x,-.30,-2.28),.035,1.95,Color("c4dbe0"))
		TownProps.box(self,Vector3(x,.65,-2.50),Vector3(.07,.07,.5),Color("c4dbe0"))
	for y in [-1.05,-.65,-.25,.15]: TownProps.box(self,Vector3(3.1,y,-2.27),Vector3(.68,.065,.18),Color("c4dbe0"))
	var water: MeshInstance3D=game.town.pool_water
	water.scale=Vector3(8.76,.035,4.76)
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/basin_water.gdshader")
	water.material_override=material
	set_fill(0)

func _ground_rect(x0: float,z0: float,x1: float,z1: float) -> void:
	TownProps.collider(self,Vector3((x0+x1)*.5,-.5,(z0+z1)*.5)-position,Vector3(x1-x0,1,z1-z0))

func set_fill(value: float) -> void:
	progress=clampf(value,0,1)
	game.town.pool_water.position.y=lerpf(EMPTY_Y,FULL_Y,progress)
	game.town.pool_water.visible=progress>.001
	game.town.pool_water.material_override.set_shader_parameter("depth",progress)

func contains_truck() -> bool:
	var local: Vector3=game.truck.global_position-TownLayout.POOL
	return absf(local.x)<4.7 and absf(local.z)<2.7
