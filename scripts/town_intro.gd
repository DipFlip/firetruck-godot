class_name TownIntro
extends Node

const LENGTH:=6.0
var game: Node3D
var active:=false
var clock:=0.0
var shot:=0
var overlay: Control
var shade: ColorRect
var title: TownTitle

func _ready() -> void:
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(overlay)
	shade=ColorRect.new()
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.color=Color("203d48")
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title=TownTitle.new()
	overlay.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()

func start() -> void:
	if active: return
	clock=0
	active=true
	game.end_dialogue()
	game.truck.freeze=true
	game.truck.enabled=false
	game.truck.charge=0
	game.camera.far=450
	overlay.show()
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(true)")
	update(0)

func update(dt: float) -> void:
	clock+=dt
	if clock>=LENGTH: finish(); return
	shot=mini(2,int(clock/2))
	var t:=fmod(clock,2)/2
	var flight:=smoothstep(0,1,t)
	var focus: Vector3
	var offset: Vector3
	match shot:
		0:
			focus=Vector3(-5,1,-5).lerp(Vector3(4,1,3),flight)
			offset=Vector3(116,125,117).cubic_interpolate(Vector3(73,120,148),Vector3(130,128,94),Vector3(44,120,159),flight)
			var aspect: float=game.hud.size.x/maxf(1,game.hud.size.y)
			game.camera.size=maxf(155,225/aspect)-smoothstep(0,1,t)*5
		1:
			focus=TownLayout.DOG+Vector3.UP*.7
			offset=Vector3(11,7.4,6).cubic_interpolate(Vector3(5.5,6.8,11.5),Vector3(13,8,1),Vector3(1,6,13),flight)
			focus+=Vector3(-.7,0,.1).lerp(Vector3(.6,.15,-.2),flight)
			game.camera.size=10.5
		2:
			focus=game.railway.engine.position+Vector3(0,1.3,0)
			offset=Vector3(18,10,11).cubic_interpolate(Vector3(9,7.5,19),Vector3(22,11,4),Vector3(3,7,21),flight)
			game.camera.size=19
	title.reveal=smoothstep(.3,3.5,clock)
	title.opacity=smoothstep(.2,.7,clock)*(1-smoothstep(5.4,LENGTH,clock))
	title.queue_redraw()
	game.camera.position=focus+offset
	game.camera.look_at(focus)
	game.camera.v_offset=0
	shade.color.a=maxf(1-smoothstep(0,.10,t),smoothstep(.90,1,t)) if shot<2 else 1-smoothstep(0,.10,t)

func finish() -> void:
	if not active: return
	active=false
	overlay.hide()
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(false)")
	game.dog_puddle.clock=.8
	game.town.dog.position=TownLayout.DOG
	game.town.dog.rotation.z=0
	game.life.clear_start_area()
	game.camera_focus=game.truck.position
	game.camera.position=game.truck.position+game.camera_offset
	game.camera.look_at(game.truck.position)
	game.camera.size=25.8
	game.camera.far=250
	game.truck.freeze=false
	game.truck.enabled=true
	game.truck.jump_blocked_until_release=true
	game.truck.pointer_spray_blocked=true
	game.truck.charge=0
