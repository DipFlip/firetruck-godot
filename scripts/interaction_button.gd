class_name InteractionButton
extends Control

const CLICK_PERIOD:=.8
const CLICK_HOLD:=.25
var hud: Control
var clock:=0.0
var touch_caption:="TAP"

static func pressed_at(age: float) -> bool:
	return fmod(age,CLICK_PERIOD)<CLICK_HOLD

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_button(self,hud,clock,size*.5,touch_caption)

static func draw_button(canvas: Control, ui: Control, age: float, center: Vector2, touch_text: String="TALK") -> void:
	var pressed:=pressed_at(age)
	var font: Font=ui.bold
	if ControlPrompts.mode==ControlPrompts.Mode.GAMEPAD:
		for offset in [Vector2(-14,0),Vector2(0,-14),Vector2(14,0),Vector2(0,14)]:
			var south: bool=offset.y>0
			var radius:=6.0 if south and pressed else 7.0
			var at: Vector2=center+offset+Vector2(0,2 if south and pressed else 0)
			canvas.draw_circle(at,radius+1.5,FireHUD.INK,true,-1,true)
			canvas.draw_circle(at,radius,FireHUD.ORANGE if south and pressed else FireHUD.TEAL if south else FireHUD.PAPER,true,-1,true)
	else:
		var rect:=Rect2(center-Vector2(37,14)+Vector2(0,3 if pressed else 0),Vector2(74,28))
		if not pressed: canvas.draw_style_box(ui.style(FireHUD.INK,8,false),Rect2(rect.position+Vector2(0,3),rect.size))
		canvas.draw_style_box(ui.style(FireHUD.TEAL if pressed else FireHUD.PAPER,8,false),rect)
		var caption: String=touch_text if ControlPrompts.mode==ControlPrompts.Mode.TOUCH else "Space"
		canvas.draw_string(font,rect.get_center()+Vector2(-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x*.5,(font.get_ascent(16)-font.get_descent(16))*.5),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,FireHUD.INK)
