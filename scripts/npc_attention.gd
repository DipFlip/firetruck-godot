class_name NPCAttention
extends Control

const CLICK_PERIOD:=InteractionButton.CLICK_PERIOD
const CLICK_HOLD:=InteractionButton.CLICK_HOLD
var game: Node3D
var actor_index:=-1
var actor: Node3D
var message:=""
var clock:=0.0
var leaving:=false
var exit_offset:=Vector2.ZERO
var retiring:=false
var retire_clock:=0.0

func _ready() -> void:
	size=Vector2(290,68)
	mouse_filter=Control.MOUSE_FILTER_STOP
	hide()

func _gui_input(event: InputEvent) -> void:
	if DialogueControl.button_press(event):
		game.truck.jump_blocked_until_release=true
		game.truck.pointer_spray_blocked=true
		game.truck.charge=0
		game._talk_to_npc(actor_index,true)
		accept_event()

func _process(dt: float) -> void:
	if not game.travel: return
	if game.paused or game.loading or game.in_main_menu or game.dialogue_active or game.dialogue_control.waiting_for_phone or game.rescue_running or game.rewards.controls_locked() or game.intro.active or game.travel.active or game.travel.in_race and (game.travel.race.running or game.travel.race.challenge.active or game.travel.race.challenge.controls_locked()) or not game.travel.in_race and game.pool_basin.contains_truck():
		hide()
		return
	var actors: Array[Node3D]=game._npc_actors()
	var selected:=-1
	var nearest:=8.0
	# Keep an existing bubble until the player has clearly driven away.
	if actor_index>=0 and actor_index<actors.size() and actors[actor_index]==actor and not game.npc_attention_text(actor_index).is_empty() and game.npc_in_view(actor) and game.truck.global_position.distance_to(actor.global_position)<10.5:
		selected=actor_index
	else:
		for i in actors.size():
			if game.npc_attention_text(i).is_empty() or not game.npc_in_view(actors[i]): continue
			var distance: float=game.truck.global_position.distance_to(actors[i].global_position)
			if distance<nearest:
				nearest=distance
				selected=i
	if selected<0:
		# Driving out of range or view retires the existing prompt smoothly.
		# Accepting its conversation still hides it immediately above.
		if visible and is_instance_valid(actor) and actor.is_visible_in_tree() and not game.npc_attention_text(actor_index).is_empty():
			if not retiring:
				retiring=true
				retire_clock=0
				if not leaving:
					exit_offset=position-game.camera.unproject_position(actor.global_position+Vector3.UP*2.8)
				leaving=true
			retire_clock+=dt
			var head: Vector2=game.camera.unproject_position(actor.global_position+Vector3.UP*2.8)
			position=position.lerp(head+exit_offset,1-exp(-9*dt))
			pivot_offset=size*.5
			scale=scale.lerp(Vector2.ONE*.45,1-exp(-9*dt))
			if game.npc_in_view(actor): modulate.a=1-smoothstep(0,.4,retire_clock)
			if not game.hud.get_viewport_rect().intersects(get_global_rect().grow(32)) or modulate.a<=.001:
				actor_index=-1
				actor=null
				hide()
			queue_redraw()
			return
		actor_index=-1
		actor=null
		hide()
		return
	var fresh:=not visible or selected!=actor_index or actor!=actors[selected]
	if fresh:
		clock=0
		leaving=false
		scale=Vector2.ONE
	retiring=false
	modulate.a=1 if fresh else lerpf(modulate.a,1,1-exp(-9*dt))
	actor_index=selected
	actor=actors[selected]
	message=game.npc_attention_text(selected)
	clock+=dt
	var head: Vector2=game.camera.unproject_position(actor.global_position+Vector3.UP*2.8)
	var low:=Vector2(12,82)
	var high:=Vector2(maxf(12,game.hud.size.x-size.x-12),maxf(82,game.hud.size.y-size.y-12))
	var preferred:=head-Vector2(size.x*.5,size.y+20)
	var target:=preferred.clamp(low,high)
	var truck_rect: Rect2=game.hud.truck_screen_rect()
	var actor_rect: Rect2=game.npc_screen_rect(actor)
	var above:=Vector2(preferred.x,minf(truck_rect.position.y,actor_rect.position.y)-size.y-16)
	var best_score:=INF
	for candidate in [preferred,above,head+Vector2(30,-size.y*.5),head-Vector2(size.x+30,size.y*.5)]:
		var at: Vector2=candidate.clamp(low,high)
		var rect:=Rect2(at,size)
		var score: float=at.distance_to(preferred)
		if rect.intersects(truck_rect): score+=10000+rect.intersection(truck_rect).get_area()
		if rect.intersects(actor_rect): score+=10000+rect.intersection(actor_rect).get_area()
		if score<best_score:
			best_score=score
			target=at
	var departure:=SpeechFrame.departure_blend(head,game.hud.size)
	if departure>.001:
		if not leaving:
			exit_offset=(target if fresh else position)-head
			leaving=true
		target=target.lerp(head+exit_offset,departure)
	else: leaving=false
	position=target if fresh else position.lerp(target,1-exp(-9*dt))
	pivot_offset=size*.5
	scale=scale.lerp(Vector2.ONE*lerpf(1,.45,departure),1-exp(-9*dt))
	show()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor): return
	draw_style_box(game.hud.style(FireHUD.PAPER,22),Rect2(Vector2.ZERO,size))
	var head: Vector2=get_global_transform().affine_inverse()*game.camera.unproject_position(actor.global_position+Vector3.UP*2.8)
	if not Rect2(Vector2.ZERO,size).has_point(head):
		var base:=head.clamp(Vector2(24,24),size-Vector2(24,24))
		if head.y>size.y: base.y=size.y-1
		elif head.y<0: base.y=1
		elif head.x>size.x: base.x=size.x-1
		else: base.x=1
		var tangent: Vector2=(head-base).normalized().orthogonal()*9
		var tip: Vector2=base+(head-base).limit_length(26)
		var tail:=PackedVector2Array([base-tangent,tip,base+tangent])
		draw_colored_polygon(tail,FireHUD.PAPER)
		draw_polyline(tail,FireHUD.INK,3,true)
	var font: Font=game.hud.bold
	var pad:=ControlPrompts.mode==ControlPrompts.Mode.GAMEPAD
	var text_start:=82.0 if pad else 102.0
	var text_center:=Vector2((text_start+size.x-16)*.5,size.y*.5)
	draw_string(font,text_center+Vector2(-font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x*.5,(font.get_ascent(18)-font.get_descent(18))*.5),message,HORIZONTAL_ALIGNMENT_LEFT,-1,18,FireHUD.INK)
	InteractionButton.draw_button(self,game.hud,clock,Vector2(44 if pad else 53,34))
