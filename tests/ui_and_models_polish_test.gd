extends SceneTree

var game: Node3D
var failures := 0

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + words)
	if not ok: failures += 1

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)

func run() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.intro.finish()
	game.call_timer = 0
	game.stage = 4
	game.truck.use_automation = true
	await frames(4)

	# --- 1. Pause Menu Sound Toggle ---
	game.set_paused(true)
	await frames(2)
	check(game.hud.sound_button != null and game.hud.sound_button.is_visible_in_tree() and game.hud.sound_button.text == "On",
		"Pause menu shows a visible Sound toggle starting in On state")
	check(not game.sound_muted and not AudioServer.is_bus_mute(0), "Master audio bus starts unmuted")
	game.hud.sound_button.pressed.emit()
	check(game.sound_muted and AudioServer.is_bus_mute(0) and game.hud.sound_button.text == "Off",
		"Clicking the Sound toggle mutes all audio and switches label to Off")
	game.hud.sound_button.pressed.emit()
	check(not game.sound_muted and not AudioServer.is_bus_mute(0) and game.hud.sound_button.text == "On",
		"Clicking the Sound toggle again unmutes audio and restores On")
	game.set_paused(false)
	await frames(2)

	# --- 2. Injection-Molded Toy Character Geometry (Single-Piece Hair + Flush Single-Axis Arms) ---
	var test_person := TownProps.person(game, Vector3(0, -40, 0), Color("ecb354"))
	var left_arm: Node3D = test_person.get_node("ArmLeft")
	var arm_meshes := left_arm.find_children("*", "MeshInstance3D", true, false)
	check(arm_meshes.size() >= 2 and arm_meshes.all(func(m: MeshInstance3D): return m.mesh is ArrayMesh and not (m.mesh is SphereMesh)),
		"Character arms and hands use injection-molded cylindrical ArrayMeshes instead of stretched ovals")
	check(absf(left_arm.position.x) <= 0.45 and absf(left_arm.rotation.z) <= 0.08,
		"Character arms sit flush against the torso shoulder for clean single-axis toy rotation")
	var hair_node: MeshInstance3D = test_person.get_node_or_null("Hair")
	check(hair_node != null and hair_node.mesh is ArrayMesh and not (hair_node.mesh is SphereMesh),
		"Character hair is a single sculpted injection-molded ArrayMesh piece with no separate horn spheres")
	var leg_meshes := test_person.get_children().filter(func(c: Node): return c is MeshInstance3D and absf(absf((c as Node3D).position.x) - 0.22) < 0.02 and (c as Node3D).position.y > 0.25)
	check(leg_meshes.size() == 2 and leg_meshes.all(func(m: MeshInstance3D): return m.mesh is ArrayMesh and m.get_meta("sdf_kind", "") == "cylinder"),
		"Character legs use smooth filleted molded cylinders with no sharp box corners")
	test_person.queue_free()

	# --- 3. In-Place Morphing NPCAttention + Unified Rounded Silhouette ---
	game.set_process(false)
	game.travel.set_process(false)
	game.stage = 1
	var attention: NPCAttention = game.dialogue_control.attention
	var maya: Node3D = game.town.people[0]
	# Medium distance (12 m): shows compact "!" badge pinned directly above Maya's head!
	game.truck.global_position = maya.global_position + Vector3(0, 0.855, 12.0)
	game.truck.reset_physics_interpolation()
	game.camera.position = maya.global_position + game.gameplay_camera_offset()
	game.camera.look_at(maya.global_position)
	attention._process(0.1)
	var badge_center_x := attention.position.x + attention.size.x * 0.5
	var head_screen: Vector2 = game.camera.unproject_position(maya.global_position + Vector3.UP * 2.85)
	check(attention.visible and attention.compact and is_equal_approx(attention.size.x, NPCAttention.BADGE_SIZE.x) and absf(badge_center_x - head_screen.x) < 2.0,
		"Approaching an NPC at medium range displays the compact '!' badge pinned centered above their head")
	# Close distance (6 m): smoothly morphs in place above the head without flying in from the side!
	game.truck.global_position = maya.global_position + Vector3(0, 0.855, 6.0)
	game.truck.reset_physics_interpolation()
	attention.mode_lock = 0.0
	attention._process(0.05)
	var mid_center_x := attention.position.x + attention.size.x * 0.5
	check(attention.visible and not attention.compact and attention.expand > 0.1 and attention.expand < 0.95 and absf(mid_center_x - head_screen.x) < 2.0,
		"Transitioning to talk range morphs smoothly in place directly above the NPC's head")
	for step in 12:
		attention._process(0.08)
	var full_center_x := attention.position.x + attention.size.x * 0.5
	check(attention.visible and not attention.compact and is_equal_approx(attention.size.x, NPCAttention.FULL_SIZE.x) and absf(full_center_x - head_screen.x) < 2.0,
		"Full talk prompt finishes expanding symmetrically above the NPC's head with zero sideways fly-in")
	# Verify unified rounded outline has smooth continuous points for both badge and full bubble.
	var badge_outline := NPCAttention._unified_bubble_outline(48.0, 48.0, 22.0, 24.0, 11.0, 9.0)
	var full_outline := NPCAttention._unified_bubble_outline(290.0, 68.0, 28.0, 145.0, 15.0, 15.5)
	check(badge_outline.size() > 60 and full_outline.size() > 60,
		"Both badge and expanded prompt render as one continuous rounded Bezier polygon silhouette")
	# When NPC is pushed near the screen edge, collapses cleanly back to compact "!" badge!
	var edge_shift: Vector3 = game.camera.global_basis.x * 18.5
	game.camera.position = maya.global_position + edge_shift + game.gameplay_camera_offset()
	game.camera.look_at(maya.global_position + edge_shift)
	attention.mode_lock = 0.0
	for step in 12:
		attention._process(0.08)
	check(attention.visible and attention.compact and is_equal_approx(attention.size.x, NPCAttention.BADGE_SIZE.x),
		"When the full bubble would clip the screen edge, it morphs cleanly back to the compact '!' badge")

	# --- 4. Auto-Triggered Conversation: First Click Fast-Forwards, Second Click Closes ---
	game.talk("OLIVER  /  THANK YOU", "It's perfect! Thank you for saving our pool party. You're always welcome for a swim!", game.stage, true)
	check(game.dialogue_active and game.dialogue_control.interrupting and game.hud.char_count < game.hud.full_text.length(),
		"Auto-triggered thank-you starts revealing progressively instead of pre-completing on frame 0")
	# Immediate Space press right as the bubble appears fast-forwards to full text and keeps it OPEN!
	press("jump")
	check(game.dialogue_active and game.hud.char_count == game.hud.full_text.length(),
		"First Space press fast-forwards the conversation to full text without closing it")
	# Second Space press cleanly closes the conversation and restores driving!
	press("jump")
	check(not game.dialogue_active and not game.dialogue_control.interrupting and game.truck.enabled,
		"Second Space press after full reveal cleanly closes the conversation and restores driving")

	# --- 5. Main Menu Return Without Page Reload / Redownload ---
	game.set_paused(true)
	game.return_to_main_menu()
	check(game.in_main_menu and game.hud.main_menu.visible and not game.hud.pause_panel.visible and game.truck.freeze,
		"Returning to Main menu lands directly in the ready Start menu without reloading")
	var shell := FileAccess.get_file_as_string("res://web/shell.html")
	check(not shell.contains("location.reload()"),
		"Web shell Main menu handler re-shows the loaded Start screen without location.reload()")

	game.queue_free()
	await process_frame
	await process_frame
	print("UI & MODELS POLISH CHECKS: ", "ALL PASS" if failures == 0 else str(failures) + " failed")
	quit(0 if failures == 0 else 1)
