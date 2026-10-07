class_name Barbecue
extends Node3D

var town: LittleTown

func _ready() -> void:
	name="KettleBarbecue"
	set_meta("toy_arrival","drop")
	position=TownLayout.FIRE
	# Replace the two old stacked drums, keeping the fire target unchanged.
	for child in town.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh and (child.position.distance_to(position+Vector3.UP*.7)<.01 or child.position.distance_to(position+Vector3.UP*1.35)<.01):
			town.remove_child(child)
			child.queue_free()
	var charcoal:=Color("354653")
	var steel:=Color("bdced0")
	var red:=Color("b64e42")
	# Rounded kettle, open grate and hinged domed lid.
	TownProps.ball(self,Vector3(0,1.03,0),Vector3(2.10,.9,2.10),red)
	TownProps.cylinder(self,Vector3(0,1.36,0),1.04,.10,charcoal)
	TownProps.cylinder(self,Vector3(0,1.415,0),.91,.035,Color("202e37"))
	for z in range(-7,8):
		var offset:=z*.115
		var width:=sqrt(maxf(0,.90*.90-offset*offset))*2
		TownProps.box(self,Vector3(0,1.45,offset),Vector3(width,.035,.027),steel)
	for x in [-.28,.26]:
		var sausage:=TownProps.cylinder(self,Vector3(x,1.51,-.18),.095,.48,Color("d89864"))
		sausage.rotation.x=PI/2
		for z in [-.27,-.1]: TownProps.box(self,Vector3(x,1.585,z),Vector3(.13,.018,.034),Color("8d5340"))
	var lid:=Node3D.new()
	add_child(lid)
	lid.position=Vector3(0,1.4,-.97)
	lid.rotation.x=deg_to_rad(-72)
	TownProps.ball(lid,Vector3(0,.04,.92),Vector3(2.10,.85,2.10),red)
	TownProps.cylinder(lid,Vector3(0,-.19,.92),1.04,.045,charcoal)
	TownProps.box(lid,Vector3(0,.50,.90),Vector3(.48,.09,.10),charcoal)
	for x in [-.19,.19]: TownProps.box(lid,Vector3(x,.40,.90),Vector3(.045,.20,.045),steel)
	TownProps.cylinder(lid,Vector3(.43,.42,.86),.13,.025,steel)
	for x in [-.07,0,.07]: TownProps.ball(lid,Vector3(.43+x,.44,.86),Vector3(.033,.01,.033),charcoal)
	for p in [Vector3(-.65,.58,.52),Vector3(.65,.58,.52),Vector3(0,.57,-.64)]:
		var leg:=TownProps.cylinder(self,p,.045,1.05,steel)
		leg.rotation.z=p.x*.30
		leg.rotation.x=-p.z*.30
	for x in [-.77,.77]:
		var wheel:=TownProps.cylinder(self,Vector3(x,.23,.67),.22,.10,charcoal)
		wheel.rotation.z=PI/2
		TownProps.ball(self,Vector3(x*1.075,.23,.67),Vector3(.035,.11,.11),steel)
	TownProps.cylinder(self,Vector3(0,.48,0),.50,.045,steel)
	TownProps.box(self,Vector3(1.37,1.23,.0),Vector3(.55,.065,.78),Color("b98256"))
	TownProps.box(self,Vector3(1.08,1.01,0),Vector3(.05,.48,.4),charcoal)
	TownProps.collider(self,Vector3(0,.7,0),Vector3(1.75,1.4,1.75))
	TownProps.merge_fixed_geometry(self,[],"barbecue")
