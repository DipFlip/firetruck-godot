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

	# --- 2. Injection-Molded Toy Character Geometry ---
	var test_person := TownProps.person(game, Vector3(0, -40, 0), Color("ecb354"))
	var left_arm: Node3D = test_person.get_node("ArmLeft")
	var arm_meshes := left_arm.find_children("*", "MeshInstance3D", true, false)
	check(arm_meshes.size() >= 2 and arm_meshes.all(func(m: MeshInstance3D): return m.mesh is ArrayMesh and not (m.mesh is SphereMesh)),
		"Character arms and hands use injection-molded cylindrical ArrayMeshes instead of stretched ovals")
	var leg_meshes := test_person.get_children().filter(func(c: Node): return c is MeshInstance3D and absf(absf((c as Node3D).position.x) - 0.22) < 0.02 and (c as Node3D).position.y > 0.25)
	check(leg_meshes.size() == 2 and leg_meshes.all(func(m: MeshInstance3D): return m.mesh is ArrayMesh and m.get_meta("sdf_kind", "") == "cylinder"),
		"Character legs use smooth filleted molded cylinders with no sharp box corners")
	test_person.queue_free()

	# --- 3. Stable NPCAttention + Compact "!" Badge ---
	game.set_process(false)
	game.travel.set_process(false)
	game.stage = 1
	var attention: NPCAttention = game.dialogue_control.attention
	var maya: Node3D = game.town.people[0]
	# Medium distance (12 m): shows compact "!" badge!
	game.truck.global_position = maya.global_position + Vector3(0, 0.855, 12.0)
	game.truck.reset_physics_interpolation()
	game.camera.position = maya.global_position + game.gameplay_camera_offset()
	game.camera.look_at(maya.global_position)
	attention._process(0.1)
	check(attention.visible and attention.compact and attention.size == NPCAttention.BADGE_SIZE,
		"Approaching an NPC at medium range displays the calm compact '!' exclamation badge")
	# Close distance with open screen room (6 m): shows full prompt bubble!
	game.truck.global_position = maya.global_position + Vector3(0, 0.855, 6.0)
	game.truck.reset_physics_interpolation()
	attention.mode_lock = 0.0
	attention._process(0.1)
	check(attention.visible and not attention.compact and attention.size.is_equal_approx(NPCAttention.FULL_SIZE),
		"Driving within talk range with clear room displays the full talk prompt")
	# Moving slightly while inside slot_lock keeps the chosen slot rock steady!
	var locked_slot := attention.active_slot
	for step in 5:
		game.truck.global_position += Vector3(0.45, 0, -0.15)
		game.truck.reset_physics_interpolation()
		attention._process(0.05)
	check(attention.active_slot == locked_slot,
		"Slot hysteresis prevents the prompt bubble from wobbling/flipping while driving past")
	# When NPC is pushed near the screen edge, falls back to compact "!" badge!
	var edge_shift: Vector3 = game.camera.global_basis.x * 18.5
	game.camera.position = maya.global_position + edge_shift + game.gameplay_camera_offset()
	game.camera.look_at(maya.global_position + edge_shift)
	attention.mode_lock = 0.0
	attention._process(0.1)
	check(attention.visible and attention.compact and attention.size.is_equal_approx(NPCAttention.BADGE_SIZE),
		"When the full bubble would clip the screen edge, it collapses cleanly to the compact '!' badge")

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
