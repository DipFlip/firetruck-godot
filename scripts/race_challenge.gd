class_name RaceChallenge
extends Node3D

const NPC_INDEX:=3
const GRID_BACK:=6.0
const MAX_SPEED:=17.25
var race: ToyRaceTrack
var game: Node3D
var opponent: RaceRival
var awards: RaceAwards
var wheels: Array[Node3D]=[]
var choices: HBoxContainer
var yes_button: Button
var no_button: Button
var overlay: Control
var countdown_label: Label
var result_panel: Panel
var result_label: Label
var fade: ColorRect
var selected_yes:=true
var offering:=false
var active:=false
var staging:=false
var result_open:=false
var has_raced:=false
var countdown:=0.0
var elapsed:=0.0
var rival_distance:=0.0
var rival_speed:=0.0
var rival_finish:=-1.0
var player_finish:=-1.0
var start_distance:=0.0
var course_length:=0.0
var wheel_angle:=0.0

func controls_locked() -> bool:
	return staging or result_open or offering

func telemetry() -> Dictionary:
	return {"ceremony":awards.active,"ceremony_won":awards.won,"rival_collision":opponent.collision_layer,"rival_avoiding":opponent.avoiding,"rival_progress":opponent.progress,"offering":offering,"staging":staging,"active":active,"result":result_open,"countdown":countdown_label.text,"elapsed":elapsed,"rival_finish":rival_finish,"player_finish":player_finish,"rival_position":[opponent.position.x,opponent.position.y,opponent.position.z],"choice_rect":[choices.global_position.x,choices.global_position.y,choices.size.x,choices.size.y],"result_text":result_label.text}

func _ready() -> void:
	name="PodiumChallenge"
	start_distance=RaceCourse.distances[RaceCourse.GATE_INDICES[0]*RaceCourse.STEPS]
	course_length=RaceCourse.distances[-1]
	_build_car()
	awards=RaceAwards.new()
	awards.challenge=self
	awards.game=game
	awards.race=race
	add_child(awards)
	choices=HBoxContainer.new()
	choices.add_theme_constant_override("separation",12)
	game.hud.dialogue_panel.add_child(choices)
	yes_button=_button(choices,"Yes, let's race!",func(): accept())
	no_button=_button(choices,"Maybe later",func(): decline())
	choices.hide()
	overlay=Control.new()
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.hud.add_child(overlay)
	fade=ColorRect.new()
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color=Color(0.08,.16,.2,0)
	overlay.add_child(fade)
	countdown_label=game.hud.words(overlay,Rect2(),"",72,Color("fff3d4"),true)
	countdown_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_color_override("font_outline_color",FireHUD.INK)
	countdown_label.add_theme_constant_override("outline_size",10)
	result_panel=game.hud.panel(overlay,Rect2(),FireHUD.PAPER)
	result_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	result_label=game.hud.words(result_panel,Rect2(),"",22,FireHUD.INK,true)
	result_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var buttons:=HBoxContainer.new()
	buttons.name="ResultButtons"
	buttons.add_theme_constant_override("separation",12)
	result_panel.add_child(buttons)
	_button(buttons,"Race again",func(): accept())
	_button(buttons,"Keep exploring",func(): dismiss_result())
	result_panel.hide()
	overlay.hide()

func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button:=Button.new()
	button.text=caption
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y=44
	button.add_theme_font_override("font",game.hud.bold)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",FireHUD.INK)
	button.add_theme_stylebox_override("normal",game.hud.style(Color("d0e8ef"),12,false))
	button.add_theme_stylebox_override("hover",game.hud.style(Color("f5c79c"),12,false))
	button.add_theme_stylebox_override("pressed",game.hud.style(FireHUD.ORANGE,12,false))
	button.pressed.connect(func():
		game.truck.pointer_spray_blocked=true
		game.truck.jump_blocked_until_release=true
		action.call())
	parent.add_child(button)
	return button

func offer() -> void:
	if active or staging or result_open: return
	offering=true
	selected_yes=true
	game.talk("QUINN  /  PODIUM RACER","Fancy a friendly race? One lap through all three gates and over Sky Bridge. First back to START wins! Would you like to challenge me?",game.stage,true)
	choices.show()
	_select(true)
	game.hud._resize_dialogue()

func hide_offer() -> void:
	offering=false
	choices.hide()

func layout_offer() -> void:
	choices.position=Vector2(18,game.hud.dialogue_panel.size.y-54)
	choices.size=Vector2(game.hud.dialogue_panel.size.x-36,44)

func _select(value: bool) -> void:
	selected_yes=value
	yes_button.add_theme_stylebox_override("normal",game.hud.style(FireHUD.ORANGE if value else Color("d0e8ef"),12,false))
	no_button.add_theme_stylebox_override("normal",game.hud.style(Color("d0e8ef") if value else FireHUD.ORANGE,12,false))

func handle_input(event: InputEvent) -> bool:
	if game.paused: return false
	if offering:
		if event is InputEventJoypadMotion:
			if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_RIGHT_X] and absf(event.axis_value)>.55: _select(event.axis_value<0)
			return true
		if event.is_action_pressed("left") or event.is_action_pressed("ui_left") or event.is_action_pressed("aim_left"): _select(true); return true
		if event.is_action_pressed("right") or event.is_action_pressed("ui_right") or event.is_action_pressed("aim_right"): _select(false); return true
		if DialogueControl.directional(event): return true
		if DialogueControl.button_press(event):
			if event is InputEventMouseButton or event is InputEventScreenTouch:
				if Rect2(no_button.global_position,no_button.size).has_point(event.position): _select(false)
				elif Rect2(yes_button.global_position,yes_button.size).has_point(event.position): _select(true)
			if selected_yes: accept()
			else: decline()
			return true
	return controls_locked() and DialogueControl.button_press(event)

func decline() -> void:
	if game.paused: return
	hide_offer()
	game.talk("QUINN  /  PODIUM RACER","No rush! Come back anytime and challenge me when you're ready.",game.stage)

func accept() -> void:
	if game.paused or not race.active or active or staging: return
	hide_offer()
	game.end_dialogue()
	result_open=false
	result_panel.hide()
	staging=true
	countdown=0
	elapsed=0
	rival_distance=0
	rival_speed=0
	rival_finish=-1
	player_finish=-1
	game.hud.map_open=false
	race.running=false
	race.checkpoint=0
	race.checkpoint_flag.hide()
	game.truck.freeze=true
	game.truck.enabled=false
	game.truck.spray_requested=false
	game.truck.spraying=false
	game.truck.charge=0
	game.truck.linear_velocity=Vector3.ZERO
	game.truck.angular_velocity=Vector3.ZERO
	countdown_label.text=""
	overlay.show()
	fade.color.a=0

func _place_grid() -> void:
	var pose:=course_pose(start_distance-GRID_BACK,2.4)
	game.truck.reset_truck()
	game.truck.global_position=ToyRaceTrack.ORIGIN+pose.origin+Vector3.UP*.8
	game.truck.heading=pose.basis.get_euler().y
	game.truck.rotation.y=game.truck.heading
	game.truck.reset_physics_interpolation()
	race.previous=Vector2(pose.origin.x,pose.origin.z)
	race.previous_height=game.truck.global_position.y
	game.camera_framing.reset()
	game.camera_subject=null
	game.camera_requested_subject=null
	game.conversation_blend=0
	game.conversation_pan=0
	game.camera_focus=game.truck.global_position
	game.camera.position=game.camera_focus+game.gameplay_camera_offset()
	game.camera.look_at(game.camera_focus)
	game.camera.size=25.8
	game.camera.v_offset=0
	game.truck.retract_ladder()
	opponent.grid(start_distance-GRID_BACK)
	race.people[NPC_INDEX].hide()

func update(dt: float) -> void:
	if game.paused: return
	if awards.active:
		awards.update(dt)
		return
	if offering and not game.dialogue_active: hide_offer()
	if staging:
		var previous_count:=countdown
		countdown+=dt
		if previous_count<.35 and countdown>=.35: _place_grid()
		fade.color.a=smoothstep(0,.35,countdown)*(1-smoothstep(.4,.75,countdown))
		countdown_label.text=str(3-int(countdown-.85)) if countdown>=.85 and countdown<3.85 else ""
		if countdown>=3.85:
			staging=false
			active=true
			opponent.start_driving()
			game.truck.freeze=false
			game.truck.enabled=true
			game.truck.jump_blocked_until_release=true
			game.truck.pointer_spray_blocked=true
			countdown_label.text="GO!"
		return
	if not active: return
	elapsed+=dt
	countdown_label.text="GO!" if elapsed<.65 else ""
	rival_distance=opponent.progress
	rival_speed=opponent.speed
	if rival_finish<0 and rival_distance>=course_length+GRID_BACK:
		rival_finish=elapsed
		show_result("Quinn wins this time!")

static func course_pose(distance: float, lane: float) -> Transform3D:
	var path:=RaceCourse.points()
	var total:=RaceCourse.distances[-1]
	var along:=fposmod(distance,total)
	var low:=0
	var high:=path.size()-1
	while high-low>1:
		var middle: int=(low+high)/2
		if RaceCourse.distances[middle]<=along: low=middle
		else: high=middle
	var t:=(along-RaceCourse.distances[low])/maxf(.001,RaceCourse.distances[high]-RaceCourse.distances[low])
	var before:=path[posmod(low-1,path.size()-1)]
	var after:=path[(high+1)%(path.size()-1)]
	var forward: Vector3=(path[high]-before).normalized().lerp((after-path[low]).normalized(),t).normalized()
	var right:=forward.cross(Vector3.UP).normalized()
	var up:=right.cross(forward).normalized()
	return Transform3D(Basis(right,up,-forward),path[low].lerp(path[high],t)+right*lane+Vector3.UP*.055)

func finish_player() -> void:
	if not active: return
	player_finish=elapsed
	var won:=rival_finish<0 or player_finish<=rival_finish
	show_result(("You won!" if won else "Quinn wins this time!")+"\nYour time: "+ToyRaceTrack.format_time(player_finish)+"\nCome back anytime and challenge me again!")

func show_result(words: String) -> void:
	has_raced=true
	active=false
	staging=false
	result_open=true
	race.running=false
	race.checkpoint=0
	race.checkpoint_flag.hide()
	result_label.text=words
	countdown_label.text=""
	result_panel.hide()
	overlay.show()
	awards.start(words.begins_with("You won!"))

func dismiss_result() -> void:
	if game.paused: return
	if awards.active:
		awards.finish()
		return
	result_open=false
	overlay.hide()
	result_panel.hide()
	opponent.park()
	race.people[NPC_INDEX].show()
	game.truck.freeze=false
	game.truck.enabled=true
	game.truck.jump_blocked_until_release=true
	game.truck.pointer_spray_blocked=true

func cancel() -> void:
	hide_offer()
	active=false
	staging=false
	awards.cancel()
	result_open=false
	dismiss_result()

func _layout_overlay() -> void:
	countdown_label.position=Vector2(0,game.hud.size.y*.3)
	countdown_label.size=Vector2(game.hud.size.x,100)
	var width:=minf(460,game.hud.size.x-24)
	var text_height:=maxf(128,game.hud.bold.get_multiline_string_size(result_label.text,HORIZONTAL_ALIGNMENT_CENTER,width-40,22).y+8)
	result_panel.size=Vector2(width,text_height+96)
	result_panel.position=(game.hud.size-result_panel.size)*.5
	result_label.position=Vector2(20,20)
	result_label.size=Vector2(width-40,text_height)
	var buttons:=result_panel.get_node("ResultButtons") as HBoxContainer
	buttons.position=Vector2(18,text_height+32)
	buttons.size=Vector2(width-36,44)
	overlay.visible=(staging or active or result_open) and not game.paused

func _process(_dt: float) -> void:
	if staging or active or result_open: _layout_overlay()
	else: overlay.hide()
	awards.animate(_dt)

func _build_car() -> void:
	opponent=RaceRival.new()
	opponent.name="QuinnRaceCar"
	opponent.set_meta("assembly_ignore",true)
	opponent.challenge=self
	add_child(opponent)
	wheels=opponent.wheels
