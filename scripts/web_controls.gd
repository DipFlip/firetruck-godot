class_name WebControls
extends Node

var game: Node3D
var state: JavaScriptObject
var jump_down:=false
var sequences: Dictionary={}
var last_view:=Vector2.ZERO
var last_talking:=false
var telemetry_clock:=0.0

func _ready() -> void:
	process_physics_priority=-100
	if OS.has_feature("web"):
		state=JavaScriptBridge.get_interface("firetruckTouch")
	else: set_physics_process(false)

func _physics_process(_dt: float) -> void:
	if state==null: return
	if bool(state.testing):
		telemetry_clock+=_dt
		if telemetry_clock>.2:
			telemetry_clock=0
			state.telemetry=JSON.stringify({"speed":game.truck.linear_velocity.length(),"water":game.truck.water,"ladder":game.truck.ladder_deployed,"charge":game.truck.charge,"height":game.truck.position.y,"paused":game.paused,"talking":game.dialogue_active,"fps":Engine.get_frames_per_second()})
	game.hud.touch_mode=bool(state.enabled)
	game.hud.touch_portrait=bool(state.portrait)
	var view:=Vector2(float(state.width),float(state.height))
	if view!=last_view and view.x>0 and view.y>0:
		last_view=view
		get_window().content_scale_size=logical_size(view)
		get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	if int(state.cancel)!=int(sequences.get("cancel",0)):
		sequences.cancel=int(state.cancel)
		game.truck.charge=0
		Input.action_release("jump")
		jump_down=false
	game.truck.touch_drive=Vector2(float(state.driveX),float(state.driveY)).limit_length(1)
	game.truck.touch_aim=Vector2(float(state.aimX),float(state.aimY)).limit_length(1)
	for action in ["ladder","pause","map","recover"]:
		var sequence:=int(state[action])
		if sequence!=int(sequences.get(action,0)):
			sequences[action]=sequence
			_send("interact" if action=="ladder" else action)
	var pressed:=bool(state.jump)
	if pressed!=jump_down:
		jump_down=pressed
		if pressed:
			Input.action_press("jump")
			_send("jump")
		else: Input.action_release("jump")
	if game.dialogue_active!=last_talking:
		last_talking=game.dialogue_active
		JavaScriptBridge.eval("window.firetruckDialogue(%s)" % ("true" if last_talking else "false"))

func _send(action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=true
	game._unhandled_input(event)

# CSS pixels (not the high-DPI backing buffer) determine readable HUD sizes.
# Both dimensions contribute; extra height no longer makes a narrow screen tiny.
static func logical_size(view: Vector2) -> Vector2i:
	var ui_scale:=clampf(minf(view.x/1000.0,view.y/700.0),.85,1.5)
	return Vector2i((view/ui_scale).round())
