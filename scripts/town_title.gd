class_name TownTitle
extends Control

# A handful of continuous pen strokes, revealed by distance travelled. This
# stays sharp at any phone resolution and looks written, rather than typed.
var strokes: Array[PackedVector2Array]=[]
var is_race_title:=false
var ink_width:=380.0
var total_length:=0.0
var reveal:=0.0
var opacity:=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_build_paths()

func set_race_title() -> void:
	is_race_title=true
	ink_width=740
	_build_paths()

func _build_paths() -> void:
	strokes.clear()
	total_length=0
	var paths: Array=[
		[[0,81],[7,48],[14,12],[23,9],[32,30],[37,63],[43,43],[61,10],[70,7],[66,42],[63,81],[72,83]], # M
		[[83,65],[94,49],[108,51],[110,66],[99,83],[87,83],[83,70],[94,53],[110,52],[107,78],[111,84],[123,74]], # a
		[[128,56],[121,103],[116,117],[115,112],[125,69],[137,52],[150,53],[152,67],[143,81],[130,83],[132,66]], # p
		[[161,80],[177,45],[181,16],[177,12],[170,21],[164,47],[162,73],[168,83],[181,72]], # l
		[[184,68],[202,61],[201,53],[193,51],[184,60],[183,77],[192,84],[210,75]], # e
		[[241,80],[250,45],[258,13],[270,11],[283,18],[281,34],[259,47],[252,47],[273,48],[284,59],[280,73],[264,82],[243,83]], # B
		[[294,65],[305,49],[319,51],[321,66],[310,83],[298,83],[294,70],[305,53],[321,52],[318,78],[322,84],[334,74]], # a
		[[340,54],[335,72],[338,83],[349,78],[360,55],[352,91],[343,113],[332,118],[327,112],[333,101],[353,93],[373,79]], # y
		[[48,96],[121,93],[198,94],[273,95],[323,91]] # understated pen flourish
	]
	if is_race_title:
		paths=paths.slice(0,5)
		var letters: Array=[
			[[0,81],[7,48],[14,12],[23,9],[32,30],[37,63],[43,43],[61,10],[70,7],[66,42],[63,81],[72,83]],
			[[0,67],[7,53],[21,53],[27,66],[20,80],[6,82],[0,71],[7,53],[21,53]],
			[[9,22],[3,70],[4,81],[14,82],[23,73]],
			[[0,67],[7,53],[21,53],[27,66],[20,80],[6,82],[0,71],[7,53],[21,53]],
			[[0,81],[6,52],[11,57],[8,70],[18,53],[28,55],[34,63]],
			[[0,82],[15,12],[29,11],[47,20],[42,39],[20,48],[10,47]],
			[[0,65],[11,49],[25,51],[27,66],[16,83],[4,83],[0,70],[11,53],[27,52],[24,78],[28,84],[40,74]],
			[[0,81],[6,52],[11,57],[8,70],[18,53],[28,55],[34,63]],
			[[0,82],[16,18],[21,11],[25,17],[14,52],[9,75],[18,62],[33,52],[35,58],[19,69],[33,83],[45,77]]]
		var offsets: Array[float]=[239,318,352,384,419,491,546,592,638]
		for i in letters.size():
			var shifted: Array=[]
			for point in letters[i]: shifted.append([point[0]+offsets[i],point[1]])
			paths.append(shifted)
		paths.append([[65,97],[230,94],[434,96],[595,95],[710,91]])

	for path in paths:
		var points:=PackedVector2Array()
		for i in path.size()-1:
			var a:=Vector2(path[maxi(0,i-1)][0],path[maxi(0,i-1)][1])
			var b:=Vector2(path[i][0],path[i][1])
			var c:=Vector2(path[i+1][0],path[i+1][1])
			var d:=Vector2(path[mini(path.size()-1,i+2)][0],path[mini(path.size()-1,i+2)][1])
			for step in 8: points.append(b.cubic_interpolate(c,a,d,float(step)/8))
		points.append(Vector2(path.back()[0],path.back()[1]))
		for i in points.size()-1: total_length+=points[i].distance_to(points[i+1])
		strokes.append(points)

func _draw() -> void:
	if opacity<=0: return
	var remaining:=total_length*reveal
	var pen_scale:=minf(1.2,get_parent().size.x*.68/ink_width)
	var origin:=Vector2((get_parent().size.x-ink_width*pen_scale)/2,minf(get_parent().size.y*.70,get_parent().size.y-125*pen_scale-24))
	for stroke in strokes:
		var visible_points:=PackedVector2Array([origin+stroke[0]*pen_scale])
		for i in stroke.size()-1:
			var length:=stroke[i].distance_to(stroke[i+1])
			if remaining<=0: break
			visible_points.append(origin+stroke[i].lerp(stroke[i+1],minf(1,remaining/maxf(.001,length)))*pen_scale)
			remaining-=length
		if visible_points.size()<2: break
		var shadow:=PackedVector2Array()
		for point in visible_points: shadow.append(point+Vector2(0,2.5)*pen_scale)
		draw_polyline(shadow,Color(.10,.23,.28,.60*opacity),6*pen_scale,true)
		draw_polyline(visible_points,Color(.96,.99,1,opacity),3.3*pen_scale,true)
		for point in [visible_points[0],visible_points[-1]]: draw_circle(point,1.65*pen_scale,Color(.96,.99,1,opacity),true,-1,true)
