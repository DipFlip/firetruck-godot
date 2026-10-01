class_name FireHUD
extends Control

const INK := Color("294754")
const PAPER := Color("eff8fc")
const MUTED := Color("688a9b")
const TEAL := Color("51b5cc")
const ORANGE := Color("ec806c")
var game: Node3D
# Mission labels remain hidden data sinks for mission/debug tooling.
var mission_label: Label
var detail_label: Label
var heading_label: Label
var water_label: Label
var speed_label: Label
var location_label: Label
var prompt_label: Label
var dialogue_panel: SpeechFrame
var speaker_label: Label
var dialogue_label: Label
var footer: Label
var toast_label: Label
var pause_panel: Panel
var pause_help: Label
var portrait: TextureRect
var continue_label: Label
var font: Font
var bold: FontVariation
var time := 0.0
var text_clock := 0.0
var char_count := 0
var full_text := ""
var speaker_key := "DISPATCH"
var voice: AudioStreamPlayer
var syllables: Array[AudioStreamWAV] = []
var voice_random := RandomNumberGenerator.new()
var talk_tween: Tween
var map_open := false
var toast_panel: Panel
var prompt_panel: Panel
var hud_group: Control
var portrait_atlas := preload("res://assets/portraits/neighbours.png")
var shown_water := 1.0
var water_activity:=0.0
var water_empty_time:=0.0
var water_gauge_scale:=1.0
var water_gauge_offset:=Vector2.ZERO
var radio_idle := 0.0
var auto_close_delay := -1.0
var touch_mode:=false
var touch_portrait:=false
var last_window_size:=Vector2i.ZERO
var dialogue_layout_width:=-1.0
var bubble_slot:=-1
var bubble_detach_blend:=0.0
const BUBBLE_MOVE_TIME:=.7
var bubble_position_ready:=false
var bubble_move_from:=Vector2.ZERO
var bubble_follow_target:=Vector2.ZERO
var bubble_move_elapsed:=BUBBLE_MOVE_TIME
var dialogue_text:=""
var dialogue_pages: Array[String]=[]
var page_index:=0
var dialogue_font_size:=19

func style(color: Color, radius: int = 20, shadow: bool = true) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(3)
	s.border_color=INK
	if shadow:
		s.shadow_color=Color(.10,.20,.27,.25)
		s.shadow_size=2
		s.shadow_offset=Vector2(0,5)
	return s

func panel(parent: Node, rect: Rect2, color: Color, radius: int = 20) -> Panel:
	var p:=Panel.new()
	parent.add_child(p)
	p.position=rect.position
	p.size=rect.size
	p.add_theme_stylebox_override("panel",style(color,radius))
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return p

func words(parent: Node, rect: Rect2, value: String, size_px: int, color: Color = INK, heavy: bool = false) -> Label:
	var l := Label.new()
	parent.add_child(l)
	l.position=rect.position
	l.size=rect.size
	l.text=value
	l.add_theme_font_override("font",bold if heavy else font)
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var regular:=FontVariation.new()
	regular.base_font=preload("res://assets/fonts/Nunito.ttf")
	regular.variation_opentype={"weight":600.0}
	font=regular
	bold=FontVariation.new()
	bold.base_font=regular.base_font
	bold.variation_opentype={"weight":850.0}
	hud_group=Control.new()
	add_child(hud_group)
	hud_group.hide()
	mission_label=words(hud_group,Rect2(),"",20)
	detail_label=words(hud_group,Rect2(),"",15)
	heading_label=words(hud_group,Rect2(),"",12)
	water_label=words(hud_group,Rect2(),"",12)
	speed_label=words(hud_group,Rect2(),"",12)
	location_label=words(hud_group,Rect2(),"",12)
	prompt_panel=panel(self,Rect2(450,807,540,42),PAPER,18)
	prompt_label=words(prompt_panel,Rect2(16,6,508,28),"",15,INK,true)
	prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_panel=panel(self,Rect2(440,109,560,46),PAPER,18)
	toast_label=words(toast_panel,Rect2(15,7,530,30),"",16,INK,true)
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	footer=words(self,Rect2(350,865,960,25),"WASD drive   ·   CLICK hose   ·   E ladder   ·   SPACE hop / talk   ·   ESC help",12,INK,true)
	footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_outline_color",PAPER)
	footer.add_theme_constant_override("outline_size",4)
	dialogue_panel=SpeechFrame.new()
	add_child(dialogue_panel)
	dialogue_panel.size=Vector2(540,200)
	dialogue_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame:=style(PAPER,26)
	frame.border_width_left=5
	frame.border_width_right=5
	frame.border_width_top=5
	frame.border_width_bottom=5
	frame.corner_radius_top_right=16
	frame.corner_radius_bottom_left=16
	dialogue_panel.add_theme_stylebox_override("panel",frame)
	speaker_label=words(dialogue_panel,Rect2(149,6,342,29),"",18,INK,true)
	speaker_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	speaker_label.clip_text=true
	portrait=TextureRect.new()
	dialogue_panel.add_child(portrait)
	portrait.position=Vector2(30,48)
	portrait.size=Vector2(88,88)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var sh:=Shader.new()
	sh.code="""shader_type canvas_item;
uniform vec2 region_start=vec2(0.0);
uniform vec2 region_size=vec2(0.5);
uniform vec2 bob=vec2(0.0);
uniform float tilt=0.0;
void fragment(){
 vec2 local=(UV-region_start)/region_size;
 float mask=1.0-smoothstep(0.48,0.50,length(local-vec2(0.5)));
 vec2 p=(local-vec2(0.5))*0.90-bob;
 p=mat2(vec2(cos(tilt),-sin(tilt)),vec2(sin(tilt),cos(tilt)))*p+vec2(0.5);
 vec4 c=texture(TEXTURE,region_start+clamp(p,vec2(0.005),vec2(0.995))*region_size);
 COLOR=vec4(c.rgb,c.a*mask);
}"""
	var mat:=ShaderMaterial.new()
	mat.shader=sh
	portrait.material=mat
	dialogue_label=words(dialogue_panel,Rect2(148,46,363,116),"",19,INK)
	dialogue_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.visible_characters_behavior=TextServer.VC_CHARS_AFTER_SHAPING
	dialogue_label.add_theme_constant_override("line_spacing",0)
	continue_label=words(dialogue_panel,Rect2(148,171,363,23),"SPACE  ·  continue",12,MUTED,true)
	continue_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_panel.hide()
	pause_panel=panel(self,Rect2(446,163,548,568),PAPER,26)
	words(pause_panel,Rect2(37,30,470,46),"Take a little breather.",30,INK,true)
	pause_help=words(pause_panel,Rect2(38,91,475,425),"WASD     Drive toward that side of the screen\nMouse + click     Aim and spray\nArrow keys     Directional spray\nHold Space, release     A springy little hop\nShift     Brake / brace against the hose\nE     Extend / retract ladder\nSpace / Enter     Continue a conversation\nSpace / click a neighbour     Say hello\nTab     Open the town map\nPark by a hydrant to refill\nR     Recover at the station\nM     Music on / off\n\nEsc     Back to the neighbourhood",18,INK)
	pause_panel.hide()
	voice=AudioStreamPlayer.new()
	voice.volume_db=-17
	add_child(voice)
	_make_syllables()

func begin_dialogue(speaker: String, text: String) -> void:
	var next_speaker:=speaker.get_slice("  /",0)
	if next_speaker!=speaker_key or not dialogue_panel.visible: bubble_detach_blend=0.0
	speaker_key=next_speaker
	dialogue_panel.phone_mode=speaker_key=="DISPATCH"
	portrait.show()
	auto_close_delay=6.0 if dialogue_panel.phone_mode else -1.0
	var names: Dictionary={"DISPATCH":"Captain Robin","MAYA":"Maya","LEO":"Leo","JUNE":"June","OLIVER":"Oliver"}
	speaker_label.text=names.get(speaker_key,speaker_key.capitalize())
	var cells: Dictionary={"DISPATCH":Vector2i(0,0),"MAYA":Vector2i(1,0),"LEO":Vector2i(0,1),"JUNE":Vector2i(1,1)}
	var cell: Vector2i=cells.get(speaker_key,Vector2i.ZERO)
	var atlas:=AtlasTexture.new()
	atlas.atlas=portrait_atlas
	var half:=portrait_atlas.get_size()/2
	atlas.region=Rect2(Vector2(cell)*half,half)
	portrait.texture=preload("res://assets/portraits/oliver.png") if speaker_key=="OLIVER" else atlas
	portrait.material.set_shader_parameter("region_start",Vector2.ZERO if speaker_key=="OLIVER" else Vector2(cell)*.5)
	portrait.material.set_shader_parameter("region_size",Vector2.ONE if speaker_key=="OLIVER" else Vector2.ONE*.5)
	portrait.material.set_shader_parameter("bob",Vector2.ZERO)
	dialogue_text=text
	page_index=0
	full_text=text
	dialogue_label.text=text
	dialogue_label.visible_characters=0
	char_count=0
	text_clock=0
	radio_idle=0
	dialogue_layout_width=-1
	if not dialogue_panel.visible: bubble_position_ready=false
	_reflow_dialogue()
	dialogue_panel.show()
	dialogue_panel.modulate.a=0
	if talk_tween: talk_tween.kill()
	talk_tween=create_tween()
	talk_tween.tween_property(dialogue_panel,"modulate:a",1.0,.18)
	_position_dialogue()

func _reflow_dialogue() -> void:
	var width:=minf(540,size.x-32)
	if (touch_mode and size.x>size.y) or (size.x>size.y*1.5 and size.y<650): width=minf(width,size.x*.34)
	var layout_key:=Vector2(width,size.y)
	if dialogue_panel.get_meta("layout_key",Vector2.ZERO)==layout_key and dialogue_layout_width==width: return
	dialogue_panel.set_meta("layout_key",layout_key)
	dialogue_layout_width=width
	dialogue_panel.size.x=width
	var compact:=width<440
	# On narrow screens the avatar shares the header, freeing the full width
	# for the complete message instead of pushing a few words onto another page.
	var left:=24.0 if compact else 148.0
	var text_width:=width-left-24
	portrait.position=Vector2(22,17) if compact else Vector2(30,48)
	portrait.size=Vector2(54,54) if compact else Vector2(88,88)
	dialogue_panel.portrait_center=Vector2(49,44) if compact else Vector2(74,92)
	dialogue_panel.portrait_radius=33 if compact else 53
	dialogue_panel.divider_start=91 if compact else left
	speaker_label.position=Vector2(92,20) if compact else Vector2(left+1,6)
	speaker_label.size.x=width-speaker_label.position.x-24
	dialogue_label.position=Vector2(left,72 if compact else 46)
	dialogue_label.size.x=text_width
	continue_label.position.x=left
	continue_label.size.x=text_width
	var extra:=104.0 if compact else 86.0
	var max_height:=maxf(174,size.y*(.52 if size.x<size.y and size.y<450 else (.58 if size.x<size.y else (.50 if touch_mode else .62))))
	dialogue_font_size=19
	while dialogue_font_size>15 and font.get_multiline_string_size(dialogue_text,HORIZONTAL_ALIGNMENT_LEFT,text_width,dialogue_font_size).y+extra+4>max_height:
		dialogue_font_size-=1
	dialogue_label.add_theme_font_size_override("font_size",dialogue_font_size)
	dialogue_pages.assign([dialogue_text])
	page_index=0
	full_text=dialogue_text
	dialogue_label.text=full_text
	_resize_dialogue()
	# Rotation/reflow keeps the current reveal position.
	dialogue_label.visible_characters=char_count

func _resize_dialogue() -> void:
	var compact:=dialogue_panel.size.x<440
	var text_height:=font.get_multiline_string_size(full_text,HORIZONTAL_ALIGNMENT_LEFT,dialogue_label.size.x,dialogue_font_size).y+4
	# Labels may retain their old minimum height until text is reshaped at the
	# end of a frame. Reapply this after a font/width change so rotation can shrink.
	dialogue_label.size.y=maxf(50 if compact else 93,text_height)
	dialogue_panel.size.y=maxf(174,dialogue_label.size.y+(104 if compact else 86))
	continue_label.position.y=dialogue_panel.size.y-28

func truck_screen_rect() -> Rect2:
	# Cover the cab, body and wheels in their interpolated rendered position.
	var transform: Transform3D=game.truck.get_global_transform_interpolated()
	var bounds:=Rect2(game.camera.unproject_position(transform.origin),Vector2.ZERO)
	for x in [-1.45,1.45]:
		for y in [-.85,2.7]:
			for z in [-2.7,2.7]:
				bounds=bounds.expand(game.camera.unproject_position(transform*Vector3(x,y,z)))
	return bounds.grow(8 if size.x<size.y and size.y<450 else 14)

func _position_dialogue(dt: float = 0.0) -> void:
	_reflow_dialogue()
	_resize_dialogue()
	dialogue_panel.scale=Vector2.ONE
	if dialogue_panel.phone_mode:
		var phone_position:=get_viewport_rect().size-dialogue_panel.size-Vector2(26,132)
		if touch_mode: phone_position=Vector2(size.x-dialogue_panel.size.x-18,80)
		_move_dialogue(phone_position,-1,dt)
		dialogue_panel.tail_tip=_phone_center()-Vector2(0,27)-dialogue_panel.position
		dialogue_panel.queue_redraw()
		return
	var actor: Node3D=game.dialogue_actor if is_instance_valid(game.dialogue_actor) else game.truck
	var head: Vector3=actor.global_position+Vector3.UP*(2.85 if game.dialogue_actor else 3.4)
	var screen: Vector2=game.camera.unproject_position(head)
	var card:=dialogue_panel.size
	var view:=get_viewport_rect().size
	var dock:=dialogue_dock_position()
	var separation: float=game.truck.global_position.distance_to(actor.global_position)
	var away:=smoothstep(9.0,17.0,separation)
	bubble_detach_blend=lerpf(bubble_detach_blend,away,1-exp(-dt/.35))
	if bubble_detach_blend<.001: bubble_detach_blend=0
	var margin:=12.0
	var truck_rect:=truck_screen_rect()
	var floating: Vector2=(screen-Vector2(card.x*.5,card.y+28)).clamp(Vector2(margin,80),Vector2(maxf(margin,view.x-card.x-margin),maxf(80,view.y-card.y-margin)))
	# Stay in the clear band below the vehicle. If an above-head balloon
	# would cross the truck, use the space beneath the NPC instead.
	var clear_top:=maxf(80,truck_rect.end.y+16)
	var lower_limit:=maxf(80,view.y-card.y-margin)
	if floating.y<clear_top:
		floating.y=clampf(screen.y+28,minf(clear_top,lower_limit),lower_limit)
	if Rect2(floating,card).grow(8).has_point(screen):
		# When there is no vertical room, settle beside the speaker in the
		# bottom band. The notch must not disappear underneath the card.
		var side_x:=screen.x-card.x-28 if screen.x>view.x*.5 else screen.x+28
		floating.x=clampf(side_x,margin,view.x-card.x-margin)
		if Rect2(floating,card).grow(8).has_point(screen): floating=dock
	var target:=dock.lerp(floating,bubble_detach_blend)
	# Keep a single stable dock instead of scoring and switching among many
	# corners every frame. Detach only through clear screen space.
	var corridor:=Rect2(dock,card).merge(Rect2(target,card))
	if corridor.intersects(truck_rect): target=dock
	_move_dialogue(target,0,dt)
	dialogue_panel.tail_tip=screen-dialogue_panel.position
	dialogue_panel.queue_redraw()

func dialogue_dock_position() -> Vector2:
	return Vector2((size.x-dialogue_panel.size.x)*.5,maxf(80,size.y-dialogue_panel.size.y-44))

func _move_dialogue(target: Vector2, slot: int, dt: float) -> void:
	if not bubble_position_ready:
		# A newly appearing card fades in at its anchor, without flying across town.
		bubble_position_ready=true
		bubble_slot=slot
		bubble_follow_target=target
		dialogue_panel.position=target
		bubble_move_elapsed=BUBBLE_MOVE_TIME
		return
	if slot!=bubble_slot:
		bubble_slot=slot
		bubble_move_from=dialogue_panel.position
		bubble_follow_target=target
		bubble_move_elapsed=0
	# Follow ordinary camera/speaker motion gently as well as slot changes.
	bubble_follow_target=bubble_follow_target.lerp(target,1-exp(-6*dt))
	if bubble_move_elapsed<BUBBLE_MOVE_TIME:
		bubble_move_elapsed=minf(BUBBLE_MOVE_TIME,bubble_move_elapsed+dt)
		var t:=bubble_move_elapsed/BUBBLE_MOVE_TIME
		dialogue_panel.position=bubble_move_from.lerp(bubble_follow_target,t*t*(3-2*t))
	else:
		dialogue_panel.position=dialogue_panel.position.lerp(bubble_follow_target,1-exp(-7*dt))

func advance_text() -> bool:
	if dialogue_label.visible_characters<full_text.length():
		dialogue_label.visible_characters=full_text.length()
		char_count=full_text.length()
		return false
	return true

func _process(dt: float) -> void:
	if not game or not game.truck: return
	_layout_viewport()
	if not game.paused: time+=dt
	shown_water=lerpf(shown_water,game.truck.water/game.truck.tank_capacity,1-exp(-8*dt))
	if not game.paused:
		water_activity=lerpf(water_activity,1.0 if game.truck.spraying or game.refill_hose.active else 0.0,1-exp(-10*dt))
		water_empty_time=maxf(0,water_empty_time-dt)
		var empty_strength:=sin(PI*clampf(water_empty_time/.45,0,1))
		water_gauge_scale=1+.025*water_activity*(.5+.5*sin(time*TAU*2.1))+.065*empty_strength
		water_gauge_offset=Vector2(sin(time*48)*3.5,sin(time*61)*1.2)*empty_strength
	prompt_panel.visible=not prompt_label.text.is_empty() and not game.dialogue_active and not game.paused
	toast_panel.visible=not toast_label.text.is_empty() and not game.paused and not game.dialogue_active
	footer.visible=not touch_mode and not game.paused and not game.dialogue_active and game.elapsed<28
	if dialogue_panel.visible and not game.paused:
		_position_dialogue(dt)
		text_clock-=dt
		if char_count<full_text.length() and text_clock<=0:
			var ch:=full_text[char_count]
			char_count+=1
			dialogue_label.visible_characters=char_count
			text_clock=.026 if ch not in ".!? ," else .09
			if ch in ".!?": text_clock=.22
			if char_count%2==0 and ch!=" ": _speak()
		var talking:=char_count<full_text.length()
		portrait.material.set_shader_parameter("bob",Vector2(sin(time*8)*.004,sin(time*10)*.008) if talking else Vector2.ZERO)
		portrait.material.set_shader_parameter("tilt",sin(time*7)*.010 if talking else 0.0)
		continue_label.text=("TAP  ·  reveal" if talking else "TAP  ·  continue   ›") if touch_mode else ("SPACE  ·  reveal" if talking else "SPACE  ·  continue   ›")
		if not talking and auto_close_delay>=0:
			radio_idle+=dt
			if radio_idle>auto_close_delay and advance_text(): game.end_dialogue()
	queue_redraw()

func on_empty_spray() -> void:
	water_empty_time=.45

func _layout_viewport() -> void:
	if not OS.has_feature("web") and get_window().size!=last_window_size:
		last_window_size=get_window().size
		get_window().content_scale_size=WebControls.logical_size(Vector2(last_window_size))
		get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	if touch_mode:
		pause_help.text="LEFT STICK     Drive\nRIGHT STICK     Aim and spray\n\nHold JUMP, then release     A springy hop\nTALK     Reveal / continue a conversation\nLADDER     Extend / retract\n\nPark by a hydrant to refill.\nTap a neighbour or their speech bubble.\n\nTap the pause button to return to town."
	prompt_panel.size.x=minf(540,size.x-32)
	prompt_label.size.x=prompt_panel.size.x-32
	prompt_panel.position=Vector2((size.x-prompt_panel.size.x)*.5,size.y-93)
	toast_panel.position=Vector2((size.x-toast_panel.size.x)*.5,85 if touch_mode else 109)
	footer.position=Vector2((size.x-footer.size.x)*.5,size.y-35)
	var pause_scale:=minf(1,minf((size.x-40)/548,(size.y-40)/568))
	pause_panel.scale=Vector2.ONE*pause_scale
	pause_panel.position=(size-pause_panel.size*pause_scale)*.5

func _speak() -> void:
	if syllables.is_empty() or DisplayServer.get_name()=="headless": return
	var pitches: Dictionary={"DISPATCH":1.04,"MAYA":1.32,"LEO":0.8,"JUNE":1.18,"OLIVER":0.96}
	voice.pitch_scale=float(pitches.get(speaker_key,1.0))*voice_random.randf_range(0.91,1.1)
	voice.stream=syllables[voice_random.randi_range(0,syllables.size()-1)]
	voice.play()

func _make_syllables() -> void:
	# Short voiced chirps: glottal harmonics plus a moving vowel formant, not TTS.
	for syllable in range(7):
		var wav:=AudioStreamWAV.new()
		wav.format=AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate=22050
		var data:=PackedByteArray()
		var frames:=int(22050*0.074)
		data.resize(frames*2)
		for i in frames:
			var t:=float(i)/22050
			var u:=float(i)/frames
			var pitch:=185.0+syllable*24.0+sin(u*PI)*46
			var phase:=TAU*pitch*t
			var envelope:=sin(PI*u)*minf(1,u*14)
			var sample: float=(sin(phase)*0.48+sin(phase*2.02)*0.2+sin(phase*3.01)*0.12+sin(TAU*(680+syllable*170)*t)*0.10)*envelope
			data.encode_s16(i*2,int(sample*23000))
		wav.data=data
		syllables.append(wav)

func _draw() -> void:
	if not game or not game.truck: return
	_draw_water()
	if not game.paused:
		if not (OS.has_feature("web") and touch_portrait) or map_open: _draw_map()
		if game.phone_ringing() or (game.dialogue_active and dialogue_panel.phone_mode):
			var phone_center:=_phone_center()
			draw_circle(phone_center+Vector2(0,3),29,Color(INK,.2))
			draw_circle(phone_center,29,INK)
			draw_circle(phone_center,25,PAPER)
			SpeechFrame.draw_phone(self,phone_center,.75,time,game.phone_ringing() or char_count<full_text.length())
		if game.stage>0 and game.stage<4 and game.truck.global_position.distance_to(game.objective())>9:
			_draw_navigation()
		var target: Vector2=game.camera.unproject_position(game.truck.aim_point)
		draw_arc(target,8,0,TAU,32,Color(PAPER,.85),1.8,true)
		draw_circle(target,2,TEAL)
	if game.paused: draw_rect(Rect2(Vector2.ZERO,size),Color(.10,.20,.27,.3))

func _phone_center() -> Vector2:
	if touch_mode:
		return Vector2(size.x-52,80+dialogue_panel.size.y*dialogue_panel.scale.y+51)
	return get_viewport_rect().size-Vector2(66,76)

func _draw_water() -> void:
	var center:=Vector2(size.x*.5,45)+water_gauge_offset
	var gauge_scale:=minf(1,(size.x-148)/344) if touch_mode else 1.0
	draw_set_transform(center,0,Vector2.ONE*gauge_scale*water_gauge_scale)
	center=Vector2.ZERO
	var rect:=Rect2(center+Vector2(-172,-25),Vector2(344,50))
	draw_style_box(style(PAPER,24),rect)
	var inside:=Rect2(center+Vector2(-115,-13),Vector2(264,26))
	draw_style_box(style(Color("284654"),12,false),inside)
	var fill:=inside.grow(-4)
	fill.size.x*=clampf(shown_water,0,1)
	if fill.size.x>.5:
		var s:=style(TEAL,7,false)
		s.set_border_width_all(0)
		draw_style_box(s,fill)
		var shine:=fill.grow(-3)
		shine.size.y=4
		if shine.size.x>0: draw_line(shine.position+Vector2(0,2),shine.position+Vector2(shine.size.x,2),Color("b8eef2"),3,true)
	var drop_center:=center+Vector2(-144,0)
	draw_circle(drop_center,18,INK)
	_drop(drop_center,12,Color("92e0ea") if shown_water>.15 else ORANGE)
	for x in [-160.0,160.0]: draw_circle(center+Vector2(x,0),2.2,Color("8baeba"))
	if game.truck.water<20:
		draw_arc(drop_center,21,-PI/2,PI*1.5,40,Color(ORANGE,.5+sin(time*4)*.25),2,true)

	draw_set_transform(Vector2.ZERO)

func _draw_navigation() -> void:
	var screen: Vector2=game.camera.unproject_position(game.objective()+Vector3.UP*1.6)
	var origin:=size*Vector2(.5,.46)
	var dir: Vector2=(screen-origin).normalized()
	var pos:=origin+dir*185
	if screen.distance_to(origin)<205: pos=screen-dir*32
	var side:=Vector2(-dir.y,dir.x)
	pos+=dir*sin(time*2.8)*3
	var outline:=PackedVector2Array([pos+dir*18,pos-dir*12+side*12,pos-dir*12-side*12])
	draw_colored_polygon(outline,INK)
	var arrow:=PackedVector2Array([pos+dir*13,pos-dir*8+side*8,pos-dir*8-side*8])
	draw_colored_polygon(arrow,ORANGE)
	draw_line(pos+dir*9,pos-dir*1,Color("ffd0c0"),2,true)

func _drop(pos: Vector2, radius: float, color: Color) -> void:
	var points:=PackedVector2Array([pos+Vector2(0,-radius)])
	for i in range(25):
		var a:=float(i)/24*PI
		points.append(pos+Vector2(cos(a)*radius*.65,sin(a)*radius*.65))
	draw_colored_polygon(points,color)

func _draw_map() -> void:
	var center:=Vector2(126,size.y-126)
	var r:=84.0
	if touch_mode: center=Vector2(92,166); r=62
	if map_open: center=size*.5; r=minf(280,minf(size.x,size.y)*.38)
	draw_circle(center+Vector2(0,7),r+15,Color(INK,.25))
	draw_circle(center,r+16,INK)
	draw_circle(center,r+12,PAPER)
	draw_circle(center,r+7,Color("73a9b7"))
	draw_circle(center,r+3,INK)
	draw_circle(center,r,Color("a8cbb9"))
	for a in [0.0,PI/2,PI,PI*1.5]:
		var rivet:=center+Vector2(cos(a),sin(a))*(r+10)
		draw_circle(rivet,3,INK)
		draw_circle(rivet+Vector2(-.6,-.6),1,PAPER)
	var s:=r/92
	for x in [-36,0,36]:
		for axis in 2:
			var start:=Vector2(x,-62) if axis==0 else Vector2(-62,x)
			var end:=Vector2(x,62) if axis==0 else Vector2(62,x)
			draw_line(center+start.rotated(.50)*s,center+end.rotated(.50)*s,Color("587c87"),9*s,true)
			draw_line(center+start.rotated(.50)*s,center+end.rotated(.50)*s,PAPER,5*s,true)
	for p in [Vector2(-15,13),Vector2(18,19),Vector2(19,-20),Vector2(-19,-20),Vector2(49,18),Vector2(-48,18),Vector2(18,49),Vector2(-19,49),Vector2(-49,-22)]:
		var at: Vector2=center+p.rotated(.5)*s
		draw_style_box(style(Color("6e9290"),2,false),Rect2(at-Vector2(4,3)*s,Vector2(8,6)*s))
	for h in game.town.hydrants:
		var at: Vector2=center+Vector2(h.x,h.z).rotated(.5)*s
		draw_circle(at,3.5*s,INK)
		draw_circle(at,2*s,Color("80e0ed"))
	if game.stage>0 and game.stage<4:
		var at: Vector2=center+Vector2(game.objective().x,game.objective().z).rotated(.5)*s
		draw_circle(at,(7+sin(time*3))*s,Color(ORANGE,.25))
		draw_circle(at,4.5*s,ORANGE)
	for job in [TownLayout.DOG,TownLayout.POOL]: draw_circle(center+Vector2(job.x,job.z).rotated(.5)*s,3*s,Color("a17099"))
	if game.ramps:
		for ramp in game.ramps.ramps:
			var at: Vector2=center+Vector2(ramp.position.x,ramp.position.z).rotated(.5)*s
			draw_line(at+Vector2(-3,2)*s,at+Vector2(3,-2)*s,ORANGE,2*s,true)
	var player: Vector2=center+(Vector2(game.truck.position.x,game.truck.position.z).rotated(.5)*s).limit_length(r-7)
	var dir:=Vector2(-sin(game.truck.heading),-cos(game.truck.heading)).rotated(.5)
	var side:=Vector2(-dir.y,dir.x)
	draw_circle(player,8,INK)
	draw_colored_polygon(PackedVector2Array([player+dir*7,player-dir*4+side*4,player-dir*2,player-dir*4-side*4]),PAPER)
	# Small compass tab is part of the frame rather than a floating label.
	var north:=center+Vector2(0,-1).rotated(.5)*(r+15)
	draw_style_box(style(INK,7,false),Rect2(north-Vector2(14,12),Vector2(28,24)))
	draw_string(bold,north+Vector2(-5,5),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,PAPER)
