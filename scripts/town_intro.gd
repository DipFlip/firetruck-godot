class_name TownIntro
extends Node

const LENGTH:=24.0
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
	game.truck.hide()
	game.marker.hide()
	game.job_label.hide()
	game.camera.far=450
	overlay.show()
	if OS.has_feature("web"): JavaScriptBridge.eval("window.firetruckIntro(true)")
	if game.travel:
		# The emergency begins after control is handed to the player.
		game.town.fire_amount=0
		for flame in game.town.flames: flame.hide()
		for smoke in game.atmosphere.smoke: smoke.hide()
		for ember in game.atmosphere.embers: ember.hide()
		game.atmosphere.fire_light.light_energy=0
		game.travel.suspend_maple()
		game.travel.set_world_visible(true)
		game.travel.begin_assembly(false)
		game.travel.mat.show_mat(false,1)

	update(0)

func update(dt: float) -> void:
	clock+=dt
	if clock>=LENGTH: finish(); return
	shot=0 if clock<6.5 else 1 if clock<10.5 else 2 if clock<14.5 else 3 if clock<18.5 else 4
	if game.travel:
		game.travel.mat.show_mat(false,RollingMat.rollout_amount(clock))
		game.travel.mat.fade_print(1-smoothstep(19,22.5,clock))
		game.travel.grow_assembly(PlayMatTravel.arrival_progress(clock))
		game.travel.assembly_camera(clock,false)
		if clock>=21.5:
			var t:=smoothstep(21.5,LENGTH,clock)
			var target: Vector3=game.truck.global_position
			var focus:=PlayMatTravel.tour_focus(21.5,false).lerp(target,t)
			game.camera.position=focus+game.travel.handover_offset(Vector3(19,15,22).lerp(game.camera_offset,t),t)
			game.camera.look_at(focus)
			game.camera.size=lerpf(game.travel.tour_lens(21.5,false),25.8,t)
			game.travel.cinematic_shadows(focus)
			game.truck.show()
	title.reveal=smoothstep(4.0,19.0,clock)
	title.opacity=smoothstep(3.4,4.2,clock)*(1-smoothstep(22.0,23.7,clock))
	title.queue_redraw()
	shade.color.a=0

func finish() -> void:
	if not active: return
	active=false
	if game.travel:
		game.travel.finish_assembly()
		game.travel.mat.hide()
		game.travel.set_world_visible(true)
		game.travel.resume_maple()
		game.town.fire_amount=1-game.fire_progress
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
	game.sun.directional_shadow_max_distance=game.gameplay_shadow_distance
	game.truck.show()
	game.truck.freeze=false
	game.truck.enabled=true
	game.truck.jump_blocked_until_release=true
	game.truck.pointer_spray_blocked=true
	game.truck.charge=0
