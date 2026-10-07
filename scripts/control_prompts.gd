class_name ControlPrompts
extends Node

# One place that knows which device the player is using and how each action
# should be shown. Messages refer to actions as tokens such as "{ladder}";
# the HUD resolves them for keyboard, gamepad or touch as the mode changes.
enum Mode {KEYBOARD, GAMEPAD, TOUCH}
signal mode_changed(mode: Mode)

const STICK_DEADZONE:=.22
# Godot's JOY_BUTTON_A/B/X/Y are the south/east/west/north face buttons.
const PAD_BUTTONS:={"jump":JOY_BUTTON_A,"interact":JOY_BUTTON_B,"brake":JOY_BUTTON_X,"map":JOY_BUTTON_Y,"pause":JOY_BUTTON_START,"recover":JOY_BUTTON_BACK,"continue":JOY_BUTTON_A}
const PAD_FACE:={JOY_BUTTON_A:"south",JOY_BUTTON_B:"east",JOY_BUTTON_X:"west",JOY_BUTTON_Y:"north"}
const KEY_NAMES:={"jump":"Space","interact":"E","brake":"Shift","map":"Tab","pause":"Esc","recover":"Recover","continue":"Enter","spray":"click","drive":"WASD","aim":"the mouse"}
const TOUCH_NAMES:={"jump":"'jump'","interact":"'ladder'","brake":"'brake'","map":"'map'","pause":"pause","continue":"'talk'","spray":"the hose stick","drive":"the drive stick","aim":"the hose stick"}
const PAD_STICKS:={"spray":"the right stick","aim":"the right stick","drive":"the left stick"}

static var mode:=Mode.KEYBOARD
var touch_forced:=false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mode=Mode.KEYBOARD
	add_bindings()

static func add_bindings() -> void:
	for action in PAD_BUTTONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var button:=InputEventJoypadButton.new()
		button.button_index=PAD_BUTTONS[action]
		InputMap.action_add_event(action,button)
	# Left stick drives, right stick aims and sprays the cannon.
	var axes:={"left":[JOY_AXIS_LEFT_X,-1.0],"right":[JOY_AXIS_LEFT_X,1.0],"forward":[JOY_AXIS_LEFT_Y,-1.0],"back":[JOY_AXIS_LEFT_Y,1.0],
		"aim_left":[JOY_AXIS_RIGHT_X,-1.0],"aim_right":[JOY_AXIS_RIGHT_X,1.0],"aim_up":[JOY_AXIS_RIGHT_Y,-1.0],"aim_down":[JOY_AXIS_RIGHT_Y,1.0]}
	for action in axes:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action,STICK_DEADZONE)
		var motion:=InputEventJoypadMotion.new()
		motion.axis=axes[action][0]
		motion.axis_value=axes[action][1]
		InputMap.action_add_event(action,motion)
	# The D-pad drives too, for pads with worn sticks.
	var dpad:={"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT,"forward":JOY_BUTTON_DPAD_UP,"back":JOY_BUTTON_DPAD_DOWN}
	for action in dpad:
		var button:=InputEventJoypadButton.new()
		button.button_index=dpad[action]
		InputMap.action_add_event(action,button)

func _input(event: InputEvent) -> void:
	var next:=mode
	if event is InputEventJoypadButton and event.pressed: next=Mode.GAMEPAD
	elif event is InputEventJoypadMotion and absf(event.axis_value)>.5: next=Mode.GAMEPAD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag: next=Mode.TOUCH
	elif event is InputEventKey and event.pressed: next=Mode.KEYBOARD
	elif event is InputEventMouseButton and event.pressed: next=Mode.KEYBOARD
	elif event is InputEventMouseMotion and event.relative.length()>12: next=Mode.KEYBOARD
	if next==Mode.KEYBOARD and touch_forced: next=Mode.TOUCH
	set_mode(next)

func set_mode(next: Mode) -> void:
	if next==mode: return
	mode=next
	mode_changed.emit(mode)

# The browser shell reports touch-capable devices; keep that until a pad is used.
func set_touch_device(touch: bool) -> void:
	if touch==touch_forced: return
	touch_forced=touch
	if touch and mode==Mode.KEYBOARD: set_mode(Mode.TOUCH)
	elif not touch and mode==Mode.TOUCH: set_mode(Mode.KEYBOARD)

# Rich text for one action, e.g. glyph("interact") -> an east-button icon.
static func glyph(action: String, size_px: int=22) -> String:
	match mode:
		Mode.GAMEPAD:
			if PAD_STICKS.has(action): return PAD_STICKS[action]
			var face: String=PAD_FACE.get(PAD_BUTTONS.get(action,-1),"")
			if not face.is_empty(): return "[img=%dx%d]res://assets/ui/pad_%s.svg[/img]" % [size_px,size_px,face]
			return {"pause":"Start","recover":"Select"}.get(action,action)
		Mode.TOUCH: return TOUCH_NAMES.get(action,action)
	return "[b]%s[/b]" % KEY_NAMES.get(action,action)

# Replace "{action}" tokens in a message with the current mode's glyphs.
static func format(text: String, size_px: int=22) -> String:
	if not "{" in text: return text
	var result:=text.replace("[","[lb]")
	for action in KEY_NAMES:
		result=result.replace("{%s}" % action,glyph(action,size_px))
	return result

# Plain text with tokens resolved to names, for logs, tests and sound timing.
static func plain(text: String) -> String:
	var result:=text
	for action in KEY_NAMES:
		var word: String=KEY_NAMES[action]
		if mode==Mode.TOUCH: word=TOUCH_NAMES.get(action,word)
		elif mode==Mode.GAMEPAD: word=PAD_STICKS.get(action,{JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y"}.get(PAD_BUTTONS.get(action,-1),word))
		result=result.replace("{%s}" % action,word)
	return result
