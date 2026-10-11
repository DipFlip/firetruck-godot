class_name DialogueControl
extends Node

var game: Node3D
var interrupting:=false
var waiting_for_phone:=false
var phone_clock:=0.0
var briefings: Dictionary={}
var spoken_actors: Dictionary={}
var axes: Dictionary={}
var saved_freeze:=false
var holding:=false
var pickup_prompt: RichTextLabel
var pickup_panel: Panel
var pickup_arrow: TextureRect
var pickup_button: InteractionButton
var attention: NPCAttention

func _ready() -> void:
	attention=NPCAttention.new()
	attention.game=game
	game.hud.add_child(attention)
	pickup_panel=game.hud.panel(game.hud,Rect2(),FireHUD.PAPER)
	pickup_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pickup_panel.hide()
	pickup_prompt=game.hud.rich(pickup_panel,Rect2(),18,FireHUD.INK,true)
	pickup_prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pickup_prompt.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	pickup_prompt.hide()
	pickup_button=InteractionButton.new()
	pickup_button.hud=game.hud
	pickup_panel.add_child(pickup_button)
	pickup_arrow=TextureRect.new()
	pickup_arrow.texture=preload("res://assets/ui/pickup_arrow.svg")
	pickup_arrow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	pickup_arrow.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pickup_arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pickup_panel.add_child(pickup_arrow)

func has_spoken(actor: Node3D) -> bool:
	return spoken_actors.has(actor)

func first_briefing(key: String) -> bool:
	if briefings.has(key): return false
	briefings[key]=true
	return true

func lock() -> void:
	if not holding:
		saved_freeze=game.truck.freeze
		holding=true
	game.truck.enabled=false
	game.truck.freeze=true
	game.truck.charge=0
	game.truck.spraying=false
	game.truck.spray_requested=false
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO

func release() -> void:
	if not holding: return
	holding=false
	game.truck.freeze=saved_freeze or game.paused or game.rescue_running or challenge_locked()
	game.truck.enabled=not game.truck.freeze
	game.truck.input_blocked_until_release=true
	game.truck.jump_blocked_until_release=true
	game.truck.pointer_spray_blocked=true

func challenge_locked() -> bool:
	return game.travel and game.travel.in_race and game.travel.race.challenge.controls_locked()

func begin(is_interrupting: bool) -> void:
	interrupting=is_interrupting
	if interrupting: lock()
	else: release()

func end() -> void:
	interrupting=game.rewards.controls_locked()
	if interrupting: lock()
	elif not waiting_for_phone: release()

func start_phone() -> void:
	if waiting_for_phone: return
	waiting_for_phone=true
	phone_clock=0
	lock()

func update_phone(dt: float) -> void:
	if not waiting_for_phone: start_phone()
	phone_clock+=dt

func pickup() -> void:
	if not waiting_for_phone or phone_clock<1: return
	waiting_for_phone=false
	game.call_timer=0
	pickup_prompt.hide()
	pickup_panel.hide()
	game.talk("DISPATCH  /  INCOMING CALL","Morning, rookie! Quiet shift today... except Maya's cat thinks he's a bird. Follow the arrow to Maple Green. You've got this.",1,true)

static func button_press(event: InputEvent) -> bool:
	if event is InputEventKey: return event.pressed and not event.echo
	if event is InputEventJoypadButton: return event.pressed
	if event is InputEventScreenTouch: return event.pressed
	if event is InputEventMouseButton: return event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]
	if event is InputEventAction: return event.pressed
	return false

static func directional(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion: return true
	if event is InputEventKey and (event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN] or event.physical_keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]): return true
	if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]: return true
	for action in ["left","right","forward","back","ui_left","ui_right","ui_up","ui_down","aim_left","aim_right","aim_up","aim_down"]:
		if event.is_action_pressed(action): return true
	return false

func handle_input(event: InputEvent) -> bool:
	var pressed:=button_press(event)
	if event is InputEventJoypadMotion:
		var was: float=axes.get(event.axis,0.0)
		axes[event.axis]=event.axis_value
		pressed=absf(event.axis_value)>.55 and absf(was)<.3
	if waiting_for_phone:
		if pressed and not directional(event): pickup()
		return pressed or event is InputEventJoypadMotion
	if game.rewards.controls_locked() and not game.dialogue_active:
		return pressed or event is InputEventJoypadMotion
	if not interrupting: return false
	if event is InputEventJoypadMotion and game.travel.in_race and game.travel.race.challenge.offering:
		game.travel.race.challenge.handle_input(event)
		return true
	if not pressed: return event is InputEventJoypadMotion
	if game.travel.in_race and game.travel.race.challenge.offering:
		game.travel.race.challenge.handle_input(event)
	elif not directional(event): game.interact()
	return true

func _process(_dt: float) -> void:
	pickup_panel.visible=waiting_for_phone and phone_clock>=1 and not game.paused and not game.loading
	pickup_prompt.visible=pickup_panel.visible
	if not pickup_prompt.visible: return
	pickup_prompt.text="to pick up"
	pickup_panel.size=Vector2(260,68)
	pickup_button.size=Vector2(90,68)
	pickup_button.clock=phone_clock-1
	pickup_button.queue_redraw()
	pickup_prompt.size=Vector2(126,68)
	pickup_prompt.position=Vector2(96,0)
	pickup_arrow.size=Vector2(28,24)
	pickup_arrow.position=Vector2(222,22)
	var phone: Vector2=game.hud._phone_center()
	pickup_panel.position=Vector2(maxf(12,phone.x-294),phone.y-34)
