class_name TownIntro
extends Node

const LENGTH:=6.0
var game: Node3D
var active:=false
var clock:=0.0
var shot:=0
var overlay: Control
var caption: Label
var skip: Label
var shade: ColorRect

func _ready() -> void:
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(overlay)
	for bottom in [false,true]:
		var bar:=ColorRect.new()
		bar.color=Color("203d48")
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top=-48 if bottom else 0
		bar.offset_bottom=0 if bottom else 48
	caption=game.hud.words(overlay,Rect2(24,10,340,30),"",16,FireHUD.PAPER,true)
	skip=game.hud.words(overlay,Rect2(),"SPACE · skip",14,FireHUD.PAPER,true)
	skip.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	shade=ColorRect.new()
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.color=Color("203d48")
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()

func start() -> void:
	if active: return
	clock=0
	active=true
	game.end_dialogue()
	game.truck.freeze=true
	game.truck.enabled=false
	game.truck.charge=0
	overlay.show()
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(true)")
	update(0)

func update(dt: float) -> void:
	clock+=dt
	if clock>=LENGTH: finish(); return
	shot=mini(2,int(clock/2))
	var t:=fmod(clock,2)/2
	var focus: Vector3
	var offset: Vector3
	match shot:
		0:
			focus=TownLayout.DOG+Vector3.UP*.7
			offset=Vector3(8,7,10).lerp(Vector3(10,7,8),smoothstep(0,1,t))
			game.camera.size=10.5
			caption.text="BISCUIT'S MORNING SPLASH"
		1:
			focus=game.railway.engine.position+Vector3(0,1.3,0)
			offset=Vector3(14,10,16).lerp(Vector3(12,10,18),smoothstep(0,1,t))
			game.camera.size=19
			caption.text="A QUIET MORNING AT NORTHLINE"
		2:
			focus=game.truck.position
			offset=Vector3(20,24,30).lerp(game.camera_offset,smoothstep(0,1,t))
			game.camera.size=lerpf(31,25.8,smoothstep(0,1,t))
			caption.text="MAPLE BAY · YOUR SHIFT BEGINS"
	game.camera.position=focus+offset
	game.camera.look_at(focus)
	game.camera.v_offset=0
	skip.text="TAP · skip" if game.hud.touch_mode else "SPACE · skip"
	skip.position=Vector2(maxf(12,game.hud.size.x-170),game.hud.size.y-37)
	skip.size=Vector2(145,28)
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
	game.truck.freeze=false
	game.truck.enabled=true
	game.truck.jump_blocked_until_release=true
	game.truck.pointer_spray_blocked=true
	game.truck.charge=0
