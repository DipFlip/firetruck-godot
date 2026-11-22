class_name NPCAttention
extends Control

const CLICK_PERIOD := InteractionButton.CLICK_PERIOD
const CLICK_HOLD := InteractionButton.CLICK_HOLD
const FULL_SIZE := Vector2(290, 68)
const BADGE_SIZE := Vector2(48, 48)
const TALK_ENTER_RADIUS := 8.5
const TALK_HOLD_RADIUS := 10.5
const BADGE_RADIUS := 14.5

var game: Node3D
var actor_index := -1
var actor: Node3D
var message := ""
var clock := 0.0
var compact := false
var active_slot := -1
var slot_lock := 0.0
var mode_lock := 0.0
var leaving := false
var exit_offset := Vector2.ZERO
var retiring := false
var retire_clock := 0.0

func _ready() -> void:
	size = FULL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func _gui_input(event: InputEvent) -> void:
	if DialogueControl.button_press(event):
		game.truck.jump_blocked_until_release = true
		game.truck.pointer_spray_blocked = true
		game.truck.charge = 0
		game._talk_to_npc(actor_index, true)
		accept_event()

func _process(dt: float) -> void:
	if not game.travel: return
	if game.paused or game.loading or game.in_main_menu or game.dialogue_active or game.dialogue_control.waiting_for_phone or game.rescue_running or (game.travel.winter and game.travel.winter.owl_rescue_running) or game.rewards.controls_locked() or game.intro.active or game.travel.active or game.travel.in_race and (game.travel.race.running or game.travel.race.challenge.active or game.travel.race.challenge.controls_locked()) or (not game.travel.in_race and not game.travel.in_winter and game.pool_basin.contains_truck()):
		hide()
		return

	slot_lock = maxf(0.0, slot_lock - dt)
	mode_lock = maxf(0.0, mode_lock - dt)

	var actors: Array[Node3D] = game._npc_actors()
	var selected := -1
	var nearest := BADGE_RADIUS
	if actor_index >= 0 and actor_index < actors.size() and actors[actor_index] == actor and not game.npc_attention_text(actor_index).is_empty() and game.npc_in_view(actor) and game.truck.global_position.distance_to(actor.global_position) < BADGE_RADIUS + 1.5:
		selected = actor_index
	else:
		for i in actors.size():
			if game.npc_attention_text(i).is_empty() or not game.npc_in_view(actors[i]): continue
			var distance: float = game.truck.global_position.distance_to(actors[i].global_position)
			if distance < nearest:
				nearest = distance
				selected = i

	if selected < 0:
		if visible and is_instance_valid(actor) and actor.is_visible_in_tree() and not game.npc_attention_text(actor_index).is_empty():
			if not retiring:
				retiring = true
				retire_clock = 0.0
				if not leaving:
					exit_offset = position - game.camera.unproject_position(actor.global_position + Vector3.UP * 2.8)
				leaving = true
			retire_clock += dt
			var retire_head: Vector2 = game.camera.unproject_position(actor.global_position + Vector3.UP * 2.8)
			position = position.lerp(retire_head + exit_offset, 1.0 - exp(-9.0 * dt))
			pivot_offset = size * 0.5
			scale = scale.lerp(Vector2.ONE * 0.45, 1.0 - exp(-9.0 * dt))
			if game.npc_in_view(actor): modulate.a = 1.0 - smoothstep(0.0, 0.35, retire_clock)
			if not game.hud.get_viewport_rect().intersects(get_global_rect().grow(32)) or modulate.a <= 0.001:
				actor_index = -1
				actor = null
				active_slot = -1
				hide()
			queue_redraw()
			return
		actor_index = -1
		actor = null
		active_slot = -1
		hide()
		return

	var fresh := not visible or selected != actor_index or actor != actors[selected]
	if fresh:
		clock = 0.0
		leaving = false
		scale = Vector2.ONE
		active_slot = -1
		slot_lock = 0.0
		mode_lock = 0.0
	retiring = false
	modulate.a = 1.0 if fresh else lerpf(modulate.a, 1.0, 1.0 - exp(-9.0 * dt))
	actor_index = selected
	actor = actors[selected]
	message = game.npc_attention_text(selected)
	clock += dt

	var dist: float = game.truck.global_position.distance_to(actor.global_position)
	var head: Vector2 = game.camera.unproject_position(actor.global_position + Vector3.UP * 2.85)
	var view: Vector2 = game.hud.size
	var low := Vector2(16, 84)
	var high := Vector2(maxf(16, view.x - FULL_SIZE.x - 16), maxf(84, view.y - FULL_SIZE.y - 16))
	var truck_rect: Rect2 = game.hud.truck_screen_rect()
	var actor_rect: Rect2 = game.npc_screen_rect(actor)

	# Evaluate stable candidate slots for the full prompt bubble.
	var preferred := head - Vector2(FULL_SIZE.x * 0.5, FULL_SIZE.y + 20)
	var above := Vector2(preferred.x, minf(truck_rect.position.y, actor_rect.position.y) - FULL_SIZE.y - 16)
	var right_slot := head + Vector2(34, -FULL_SIZE.y * 0.5)
	var left_slot := head - Vector2(FULL_SIZE.x + 34, FULL_SIZE.y * 0.5)
	var candidates: Array[Vector2] = [preferred, above, right_slot, left_slot]

	var best_slot := 0
	var best_score := INF
	var best_target := preferred.clamp(low, high)
	var current_score := INF
	var current_target := best_target

	for idx in candidates.size():
		var raw: Vector2 = candidates[idx]
		var at: Vector2 = raw.clamp(low, high)
		var rect := Rect2(at, FULL_SIZE)
		# Penalize edge clamping, drift from preferred anchor, and overlaps.
		var clamp_shift := at.distance_to(raw)
		var score := at.distance_to(preferred) + clamp_shift * 3.0
		if rect.intersects(truck_rect):
			score += 10000.0 + rect.intersection(truck_rect).get_area()
		if rect.intersects(actor_rect):
			score += 10000.0 + rect.intersection(actor_rect).get_area()
		# Hysteresis bonus keeps the chosen slot steady while driving past.
		if idx == active_slot:
			current_score = score
			current_target = at
			score -= 180.0
		if score < best_score:
			best_score = score
			best_slot = idx
			best_target = at

	# Keep the existing slot during the cooldown unless it becomes obstructed.
	var chosen_slot := best_slot
	var chosen_target := best_target
	if not fresh and active_slot >= 0 and slot_lock > 0.0 and current_score < 9000.0:
		chosen_slot = active_slot
		chosen_target = current_target
	elif chosen_slot != active_slot:
		active_slot = chosen_slot
		slot_lock = 0.45

	# Decide whether the full bubble fits cleanly and comfortably on screen,
	# or whether to show the calm compact "!" exclamation badge instead.
	var within_talk: bool = dist <= (TALK_HOLD_RADIUS if not compact else TALK_ENTER_RADIUS)
	var head_inside_margin := head.x >= 110.0 and head.x <= view.x - 110.0 and head.y >= 105.0 and head.y <= view.y - 44.0
	var full_fits: bool = within_talk and head_inside_margin and best_score < 9000.0 and view.x >= FULL_SIZE.x + 48.0
	var want_compact: bool = not full_fits
	if fresh:
		compact = want_compact
	elif want_compact != compact and mode_lock <= 0.0:
		compact = want_compact
		mode_lock = 0.35

	var target: Vector2
	if compact:
		size = BADGE_SIZE
		var badge_low := Vector2(12, 74)
		var badge_high := Vector2(maxf(12, view.x - BADGE_SIZE.x - 12), maxf(74, view.y - BADGE_SIZE.y - 12))
		target = (head - Vector2(BADGE_SIZE.x * 0.5, BADGE_SIZE.y + 14)).clamp(badge_low, badge_high)
	else:
		size = FULL_SIZE
		target = chosen_target

	var departure := SpeechFrame.departure_blend(head, view)
	if departure > 0.001:
		if not leaving:
			exit_offset = (target if fresh else position) - head
			leaving = true
		target = target.lerp(head + exit_offset, departure)
	else:
		leaving = false

	if fresh:
		position = target
	elif position.distance_to(target) > (2.0 if compact else 5.0):
		var smooth := 1.0 - exp(-(11.0 if compact else 6.5) * dt)
		position = position.lerp(target, smooth)

	pivot_offset = size * 0.5
	scale = scale.lerp(Vector2.ONE * lerpf(1.0, 0.55, departure), 1.0 - exp(-9.0 * dt))
	show()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor): return
	if compact:
		_draw_badge()
		return
	draw_style_box(game.hud.style(FireHUD.PAPER, 22), Rect2(Vector2.ZERO, size))
	var head: Vector2 = get_global_transform().affine_inverse() * game.camera.unproject_position(actor.global_position + Vector3.UP * 2.85)
	if not Rect2(Vector2.ZERO, size).has_point(head):
		var base := head.clamp(Vector2(24, 24), size - Vector2(24, 24))
		if head.y > size.y: base.y = size.y - 1
		elif head.y < 0: base.y = 1
		elif head.x > size.x: base.x = size.x - 1
		else: base.x = 1
		var tangent: Vector2 = (head - base).normalized().orthogonal() * 9
		var tip: Vector2 = base + (head - base).limit_length(26)
		var tail := PackedVector2Array([base - tangent, tip, base + tangent])
		draw_colored_polygon(tail, FireHUD.PAPER)
		draw_polyline(tail, FireHUD.INK, 3, true)
	var font: Font = game.hud.bold
	var pad := ControlPrompts.mode == ControlPrompts.Mode.GAMEPAD
	var text_start := 82.0 if pad else 102.0
	var text_center := Vector2((text_start + size.x - 16) * 0.5, size.y * 0.5)
	draw_string(font, text_center + Vector2(-font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x * 0.5, (font.get_ascent(18) - font.get_descent(18)) * 0.5), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, FireHUD.INK)
	InteractionButton.draw_button(self, game.hud, clock, Vector2(44 if pad else 53, 34))

func _draw_badge() -> void:
	var c := size * 0.5
	var bob := sin(clock * 4.5) * 2.0
	var center := c + Vector2(0, bob)
	var r := 20.0
	# Soft drop shadow + crisp circular badge with a bold coral "!".
	draw_circle(center + Vector2(0, 3), r + 1.5, Color(FireHUD.INK, 0.24), true, -1, true)
	var pointer := PackedVector2Array([center + Vector2(-7, r - 4), center + Vector2(0, r + 7), center + Vector2(7, r - 4)])
	draw_colored_polygon(pointer, FireHUD.INK)
	draw_circle(center, r + 2.5, FireHUD.INK, true, -1, true)
	draw_circle(center, r - 0.5, FireHUD.PAPER, true, -1, true)
	draw_line(center + Vector2(0, -10.5), center + Vector2(0, 1.5), FireHUD.ORANGE, 5.0, true)
	draw_circle(center + Vector2(0, -10.5), 2.5, FireHUD.ORANGE, true, -1, true)
	draw_circle(center + Vector2(0, 1.5), 2.3, FireHUD.ORANGE, true, -1, true)
	draw_circle(center + Vector2(0, 9.0), 3.0, FireHUD.ORANGE, true, -1, true)
