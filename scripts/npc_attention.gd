class_name NPCAttention
extends Control

const CLICK_PERIOD := InteractionButton.CLICK_PERIOD
const CLICK_HOLD := InteractionButton.CLICK_HOLD
const FULL_SIZE := Vector2(290, 68)
const BADGE_SIZE := Vector2(48, 48)
const FULL_TAIL_HEIGHT := 15.0
const BADGE_TAIL_HEIGHT := 11.0
const TALK_ENTER_RADIUS := 8.5
const TALK_HOLD_RADIUS := 10.5
const BADGE_RADIUS := 14.5

var game: Node3D
var actor_index := -1
var actor: Node3D
var message := ""
var clock := 0.0
var compact := false
var expand := 0.0
var pop_in := 1.0
var active_slot := 0
var mode_lock := 0.0
var retiring := false
var retire_clock := 0.0
var head_local_x := 24.0

func _ready() -> void:
	size = Vector2(FULL_SIZE.x, FULL_SIZE.y + FULL_TAIL_HEIGHT)
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
			retire_clock += dt
			compact = true
			expand = lerpf(expand, 0.0, 1.0 - exp(-12.0 * dt))
			_place_above_head(game.camera.unproject_position(actor.global_position + Vector3.UP * 2.85), game.hud.size)
			pivot_offset = Vector2(head_local_x, size.y)
			var fade := 1.0 - smoothstep(0.0, 0.28, retire_clock)
			scale = Vector2.ONE * lerpf(0.62, 1.0, fade)
			modulate.a = fade
			if not game.hud.get_viewport_rect().intersects(get_global_rect().grow(32)) or modulate.a <= 0.001:
				actor_index = -1
				actor = null
				hide()
			queue_redraw()
			return
		actor_index = -1
		actor = null
		hide()
		return

	var fresh := not visible or selected != actor_index or actor != actors[selected]
	actor_index = selected
	actor = actors[selected]
	message = game.npc_attention_text(selected)

	var dist: float = game.truck.global_position.distance_to(actor.global_position)
	var head: Vector2 = game.camera.unproject_position(actor.global_position + Vector3.UP * 2.85)
	var view: Vector2 = game.hud.size

	# Decide compact "!" badge vs expanded "[Space] ..." prompt with hysteresis.
	var within_talk: bool = dist <= (TALK_HOLD_RADIUS if not compact else TALK_ENTER_RADIUS)
	var head_inside_margin := head.x >= 96.0 and head.x <= view.x - 96.0 and head.y >= 100.0 and head.y <= view.y - 36.0
	var full_fits: bool = within_talk and head_inside_margin and view.x >= FULL_SIZE.x + 48.0
	var want_compact: bool = not full_fits

	if fresh:
		clock = 0.0
		compact = want_compact
		expand = 0.0 if compact else 1.0
		pop_in = 0.0
		mode_lock = 0.0
	elif want_compact != compact and mode_lock <= 0.0:
		compact = want_compact
		mode_lock = 0.30

	retiring = false
	clock += dt
	pop_in = minf(1.0, pop_in + dt * 5.5)

	var target_expand := 0.0 if compact else 1.0
	if absf(expand - target_expand) < 0.004:
		expand = target_expand
	else:
		expand = lerpf(expand, target_expand, 1.0 - exp(-11.5 * dt))

	_place_above_head(head, view)

	var departure := SpeechFrame.departure_blend(head, view)
	var ease_pop := smoothstep(0.0, 1.0, pop_in)
	modulate.a = ease_pop * lerpf(1.0, 0.85, departure)
	pivot_offset = Vector2(head_local_x, size.y)
	scale = Vector2.ONE * lerpf(0.80, 1.0, ease_pop) * lerpf(1.0, 0.72, departure)
	show()
	queue_redraw()

func _place_above_head(head: Vector2, view: Vector2) -> void:
	var e := smoothstep(0.0, 1.0, expand)
	var body_w := lerpf(BADGE_SIZE.x, FULL_SIZE.x, e)
	var body_h := lerpf(BADGE_SIZE.y, FULL_SIZE.y, e)
	var tail_h := lerpf(BADGE_TAIL_HEIGHT, FULL_TAIL_HEIGHT, e)
	size = Vector2(body_w, body_h + tail_h)

	var bob := sin(clock * 3.8) * lerpf(2.2, 0.7, e)
	var gap := lerpf(9.0, 11.0, e)
	var clamped_x := clampf(head.x - body_w * 0.5, 16.0, maxf(16.0, view.x - body_w - 16.0))
	var clamped_y := clampf(head.y - body_h - tail_h - gap + bob, 74.0, maxf(74.0, view.y - body_h - tail_h - 16.0))
	position = Vector2(clamped_x, clamped_y)
	head_local_x = clampf(head.x - clamped_x, 22.0, maxf(22.0, body_w - 22.0))

func _draw() -> void:
	if not is_instance_valid(actor): return
	var e := smoothstep(0.0, 1.0, expand)
	var body_w := size.x
	var tail_h := lerpf(BADGE_TAIL_HEIGHT, FULL_TAIL_HEIGHT, e)
	var body_h := maxf(20.0, size.y - tail_h)
	var corner_r := minf((body_h - 4.0) * 0.5, lerpf(22.0, 28.0, e))
	var tail_hw := lerpf(9.0, 15.5, e)

	var path := _unified_bubble_outline(body_w, body_h, corner_r, head_local_x, tail_h, tail_hw)
	var shadow := PackedVector2Array()
	for v in path:
		shadow.append(v + Vector2(0.0, 4.0))
	draw_colored_polygon(shadow, Color(FireHUD.INK, 0.22))
	draw_colored_polygon(path, FireHUD.PAPER)
	var stroke := PackedVector2Array(path)
	stroke.append(path[0])
	draw_polyline(stroke, FireHUD.INK, 3.0, true)

	# Crossfade cleanly between the compact "!" and the expanded "[Space] ..." content.
	var badge_alpha := 1.0 - smoothstep(0.04, 0.42, e)
	if badge_alpha > 0.01:
		var c := Vector2(body_w * 0.5, body_h * 0.5)
		var col := Color(FireHUD.ORANGE, badge_alpha)
		draw_line(c + Vector2(0, -10.5), c + Vector2(0, 1.2), col, 5.2, true)
		draw_circle(c + Vector2(0, -10.5), 2.6, col, true, -1, true)
		draw_circle(c + Vector2(0, 1.2), 2.4, col, true, -1, true)
		draw_circle(c + Vector2(0, 8.8), 3.1, col, true, -1, true)

	var full_alpha := smoothstep(0.45, 0.94, e)
	if full_alpha > 0.01:
		var font: Font = game.hud.bold
		var pad := ControlPrompts.mode == ControlPrompts.Mode.GAMEPAD
		var text_start := 82.0 if pad else 102.0
		var text_center := Vector2((text_start + body_w - 16.0) * 0.5, body_h * 0.5)
		var text_size := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var ink := Color(FireHUD.INK, full_alpha)
		draw_string(font, text_center + Vector2(-text_size.x * 0.5, (font.get_ascent(18) - font.get_descent(18)) * 0.5), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		if full_alpha > 0.25:
			var prev_mod := Color(1, 1, 1, full_alpha)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# Draw button gently scaled in during the tail end of the morph.
			var btn_scale := lerpf(0.86, 1.0, full_alpha)
			var btn_pos := Vector2(44.0 if pad else 53.0, body_h * 0.5)
			draw_set_transform(btn_pos, 0.0, Vector2.ONE * btn_scale)
			InteractionButton.draw_button(self, game.hud, clock, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var _unused := prev_mod

# Builds ONE continuous smooth rounded silhouette (rounded pill / circle +
# tangentially filleted speech tail with softly rounded tip, zero seams).
static func _unified_bubble_outline(body_w: float, body_h: float, radius: float, tail_x: float, tail_h: float, tail_hw: float) -> PackedVector2Array:
	var lo := Vector2(2.0, 2.0)
	var hi := Vector2(body_w - 2.0, body_h - 2.0)
	var r := minf(radius, minf((hi.x - lo.x) * 0.5, (hi.y - lo.y) * 0.5))
	var cx_l := lo.x + r
	var cx_r := hi.x - r
	var cy_t := lo.y + r
	var cy_b := hi.y - r

	var tx := clampf(tail_x, lo.x + maxf(tail_hw + 5.0, r * 0.52), hi.x - maxf(tail_hw + 5.0, r * 0.52))
	var xl := maxf(lo.x + 3.0, tx - tail_hw)
	var xr := minf(hi.x - 3.0, tx + tail_hw)

	var p_right := _bottom_point(xr, cx_l, cx_r, cy_b, hi.y, r)
	var t_right := _bottom_cw_tangent(xr, cx_l, cx_r, r)
	var p_left := _bottom_point(xl, cx_l, cx_r, cy_b, hi.y, r)
	var t_left := _bottom_cw_tangent(xl, cx_l, cx_r, r)

	var path := PackedVector2Array()

	# 1. Bottom-left from p_left around the left side and top to bottom-right.
	if xl > cx_l + 0.05:
		path.append(p_left)
		_append_arc(path, Vector2(cx_l, cy_b), r, PI * 0.5, PI, 12)
	else:
		var ang_l := atan2(p_left.y - cy_b, p_left.x - cx_l)
		_append_arc(path, Vector2(cx_l, cy_b), r, ang_l, PI, 10)

	# Left edge -> Top-left arc -> Top edge -> Top-right arc -> Right edge.
	_append_arc(path, Vector2(cx_l, cy_t), r, PI, PI * 1.5, 12)
	_append_arc(path, Vector2(cx_r, cy_t), r, PI * 1.5, TAU, 12)

	# Bottom-right arc stopping smoothly at p_right.
	if xr < cx_r - 0.05:
		_append_arc(path, Vector2(cx_r, cy_b), r, 0.0, PI * 0.5, 12)
		path.append(p_right)
	else:
		var ang_r := atan2(p_right.y - cy_b, p_right.x - cx_r)
		_append_arc(path, Vector2(cx_r, cy_b), r, 0.0, ang_r, 10)

	# 2. Smoothly filleted Bezier speech tail with softly rounded tip!
	var tip := Vector2(tx, hi.y + tail_h)
	var tip_r := minf(3.0, tail_hw * 0.28)
	var tip_right := tip + Vector2(tip_r, -tip_r * 0.45)
	var tip_left := tip + Vector2(-tip_r, -tip_r * 0.45)
	var lead := tail_hw * 0.56
	_append_cubic(path, p_right, p_right + t_right * lead, tip + Vector2(tip_r * 1.55, -tail_h * 0.34), tip_right, 14)
	_append_cubic(path, tip_right, tip + Vector2(tip_r * 0.45, tip_r * 0.32), tip + Vector2(-tip_r * 0.45, tip_r * 0.32), tip_left, 8)
	_append_cubic(path, tip_left, tip + Vector2(-tip_r * 1.55, -tail_h * 0.34), p_left - t_left * lead, p_left, 14)

	if path.size() > 1 and path[-1].is_equal_approx(path[0]):
		path.resize(path.size() - 1)
	return path

static func _bottom_point(x: float, cx_l: float, cx_r: float, cy_b: float, hi_y: float, r: float) -> Vector2:
	if x > cx_r:
		var dx := clampf(x - cx_r, 0.0, r)
		return Vector2(cx_r + dx, cy_b + sqrt(maxf(0.0, r * r - dx * dx)))
	if x < cx_l:
		var dx := clampf(x - cx_l, -r, 0.0)
		return Vector2(cx_l + dx, cy_b + sqrt(maxf(0.0, r * r - dx * dx)))
	return Vector2(x, hi_y)

static func _bottom_cw_tangent(x: float, cx_l: float, cx_r: float, r: float) -> Vector2:
	if x > cx_r and r > 0.001:
		var dx := clampf(x - cx_r, 0.0, r)
		var dy := sqrt(maxf(0.0, r * r - dx * dx))
		return Vector2(-dy, dx).normalized()
	if x < cx_l and r > 0.001:
		var dx := clampf(x - cx_l, -r, 0.0)
		var dy := sqrt(maxf(0.0, r * r - dx * dx))
		return Vector2(-dy, dx).normalized()
	return Vector2(-1.0, 0.0)

static func _append_arc(path: PackedVector2Array, center: Vector2, r: float, a0: float, a1: float, steps: int) -> void:
	for i in range(steps + 1):
		var a := lerpf(a0, a1, float(i) / float(steps))
		var pt := center + Vector2(cos(a), sin(a)) * r
		if path.is_empty() or not path[-1].is_equal_approx(pt):
			path.append(pt)

static func _append_cubic(path: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> void:
	for i in range(1, steps + 1):
		path.append(p0.bezier_interpolate(p1, p2, p3, float(i) / float(steps)))
