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

func place(local: Vector3, heading: float = 0.0) -> void:
	game.truck.global_position = game.truck.world_origin + local
	game.truck.heading = heading
	game.truck.rotation.y = heading
	game.truck.linear_velocity = Vector3.ZERO
	game.truck.angular_velocity = Vector3.ZERO
	game.truck.reset_physics_interpolation()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.call_timer = 0
	game.stage = 4
	game.truck.use_automation = true
	await frames(4)

	# --- 1. Upgraded Toy Models ---
	check(game.town.people.all(func(p: Node3D): return p.has_node("OutfitDetails") and p.find_child("HeadDetails", true, false) != null and p.find_child("Eyebrows", true, false) != null and p.find_child("MouthOpen", true, false) != null),
		"Maple Bay characters have upgraded outfit details, eyebrows and reaction mouths")
	check(game.town.cat.has_node("CatHead") and game.town.cat.has_node("TailPivot") and game.cat_paws.size() == 4,
		"Pippin has the sculpted cat model while preserving all 4 ladder-climb paws")
	check(game.town.dog.has_node("DogHead") and game.town.dog.has_node("TailPivot") and game.town.dog.get_meta("dog_mud_parts", []).size() >= 4,
		"Biscuit has the sculpted dog model with floppy ears, wagging tail and mud patches")
	ToyModels.set_dog_clean(game.town.dog, 1.0)
	check(game.town.dog.get_meta("dog_mud_parts", []).all(func(m: Node3D): return not m.visible),
		"Washing Biscuit smoothly hides all mud patches while keeping sculpted collar & eyes")
	ToyModels.set_dog_clean(game.town.dog, 0.0)
	check(game.life.ground_birds[0].node.find_child("WingTip", true, false) != null,
		"Town birds use the upgraded sculpted songbird model")

	# --- 2. NPC & Animal Water-Spray Reactions (Maple Bay) ---
	var leo: Node3D = game.town.people[1]
	var whoa_before: int = int(game.sounds.counts.get("whoa", 0))
	place(TownLayout.LEO + Vector3(0, 0.85, 6.0))
	await frames(2)
	var hit_leo: bool = game._water_hit(leo.global_position + Vector3.UP * 1.2, 0.02)
	await frames(10)
	check(hit_leo and leo.get_meta("spray_reacting", false) and int(game.sounds.counts.get("whoa", 0)) > whoa_before,
		"Spraying a Maple Bay resident triggers a startled arm-raise reaction and 'whoa' sound")
	check(absf(leo.get_node("ArmLeft").rotation.x) > 0.8 and leo.find_child("MouthOpen", true, false).visible,
		"Startled residents visibly raise their arms and open a surprised mouth")
	await frames(65)
	check(not leo.get_meta("spray_reacting", false),
		"Startled resident returns cleanly to rest pose after the spray reaction finishes")

	var bird: Dictionary = game.life.ground_birds[0]
	check(bird.mode == "ground", "Ground bird starts foraging before being sprayed")
	game._water_hit(bird.node.global_position + Vector3.UP * 0.2, 0.02)
	check(bird.mode == "flee", "Spraying near a foraging bird immediately startles it into flight")

	# --- 3. Race Track Spectator Cheer & Duck Spray Reactions ---
	var travel: PlayMatTravel = game.travel
	travel.start_world(1)
	travel.finish()
	await frames(3)
	var spectator: Node3D = travel.race.spectators[0]
	var cheer_before: int = int(game.sounds.counts.get("giggle", 0)) + int(game.sounds.counts.get("cheer", 0))
	place(spectator.position + Vector3(0, 0.85, 6.0))
	game._water_hit(spectator.global_position + Vector3.UP * 1.2, 0.02)
	await frames(10)
	var cheer_after: int = int(game.sounds.counts.get("giggle", 0)) + int(game.sounds.counts.get("cheer", 0))
	check(spectator.get_meta("spray_reacting", false) and cheer_after > cheer_before and spectator.get_node("ArmRight").rotation.x > 1.0,
		"Spraying a race grandstand spectator makes them cheer, raise both arms and hop happily")
	var duck: Node3D = travel.race.ducks[0]
	var quack_before: int = int(game.sounds.counts.get("quack", 0))
	game._water_hit(duck.global_position + Vector3.UP * 0.1, 0.02)
	check(int(game.sounds.counts.get("quack", 0)) > quack_before,
		"Spraying a pond duck makes it quack and paddle away")

	# Return to Maple Bay first, then drive east into Frostpine Hollow!
	travel.start_world(0)
	travel.finish()
	await frames(3)

	# --- 4. Maple Bay East Exit -> Frostpine Hollow Travel ---
	travel.exit_armed = true
	place(Vector3(78, 0.85, 0), -PI * 0.5)
	game.truck.linear_velocity = Vector3(18, 0, 0)
	await frames(30)
	check(travel.active and travel.destination_world == 2 and travel.title.custom_title == TownTitle.WINTER_NAME,
		"Driving east out of Maple Bay triggers the Frostpine Hollow carpet transition")
	travel.finish()
	await frames(4)
	var winter: ToyWinterVillage = travel.winter
	check(travel.in_winter and winter.active and winter.visible and not game.town.visible,
		"Frostpine Hollow activates with Maple Bay hidden and suspended")
	check(game.truck.global_position.x > ToyWinterVillage.ORIGIN.x - 76 and absf(game.truck.heading + PI * 0.5) < 0.15,
		"Truck arrives at Frostpine Hollow's west entrance facing east")
	check(winter.people.size() == 4 and winter.skaters.size() == 3 and winter.walkers.size() == 4,
		"Frostpine Hollow spawns all 4 named winter NPCs, 3 rink skaters and 4 village walkers")

	# --- 5. Spray-to-Ice Slippery Driving Physics ---
	place(Vector3(-4, 0.85, 0), -PI * 0.5)
	await frames(3)
	check(game.truck.surface_slip < 0.05, "Dry snow starts with normal traction")
	# Measure coasting distance on dry snow.
	game.truck.linear_velocity = Vector3(10, 0, 0)
	await frames(45)
	var dry_distance: float = (game.truck.global_position.x - ToyWinterVillage.ORIGIN.x) - (-4.0)
	# Spray water ahead along z = 0 to freeze an icy strip!
	var freeze_before: int = int(game.sounds.counts.get("ice_freeze", 0))
	for ix in range(-4, 16, 2):
		game._water_hit(ToyWinterVillage.ORIGIN + Vector3(ix, 0.06, 0), 0.18)
	await frames(3)
	check(winter.ice_field.patch_count() >= 8 and int(game.sounds.counts.get("ice_freeze", 0)) > freeze_before,
		"Spraying water on snow creates glossy ice patches with crystalline freeze audio")
	place(Vector3(-4, 0.85, 0), -PI * 0.5)
	await frames(2)
	check(game.truck.surface_slip > 0.45, "Driving onto sprayed ice registers high surface slip on FireEngine")
	game.truck.linear_velocity = Vector3(10, 0, 0)
	await frames(45)
	var ice_distance: float = (game.truck.global_position.x - ToyWinterVillage.ORIGIN.x) - (-4.0)
	check(ice_distance > dry_distance + 1.5,
		"Truck glides noticeably farther on player-sprayed ice (%.2fm vs %.2fm dry)" % [ice_distance, dry_distance])

	# --- 6. Winter Mission 1: Freeze the Village Skating Rink (Elsa) ---
	check(game._talk_to_npc(0, true) and game.dialogue_actor == winter.people[0] and game.hud.speaker_key == "ELSA",
		"Talking to Elsa opens her winter rink briefing with portrait")
	game.end_dialogue()
	for tile in winter.rink_tiles:
		for _step in 6:
			game._water_hit(ToyWinterVillage.ORIGIN + tile.local, 0.12)
	await frames(4)
	check(winter.rink_done and winter.rink_progress >= 0.99,
		"Spraying water across the skating rink freezes all tiles and completes Elsa's job")
	# Dismiss reward celebration cleanly.
	await frames(120)
	game.end_dialogue()
	var skater_before: Vector3 = winter.skaters[0].position
	await frames(20)
	check(winter.skaters[0].position.distance_to(skater_before) > 0.25,
		"Skaters glide out onto the newly frozen village rink")

	# --- 7. Winter Mission 2: Runaway Bonfire (Bram) ---
	for _step in 40:
		if winter.bonfire_done: break
		game._water_hit(ToyWinterVillage.ORIGIN + ToyWinterVillage.BONFIRE_POS + Vector3.UP * 1.5, 0.12)
	await frames(4)
	check(winter.bonfire_done, "Spraying the cocoa-lodge bonfire extinguishes it and completes Bram's job")
	await frames(120)
	game.end_dialogue()

	# --- 8. Winter Mission 3: Snowy Owl Ladder Rescue (Astrid) ---
	place(ToyWinterVillage.OWL_PERCH + Vector3(0, 0.85, -4.5), PI)
	game.truck.extend_ladder(winter.owl.global_position)
	await frames(95)
	check(winter.owl_rescue_running or winter.owl_rescued,
		"Extending the telescopic ladder near Snowball activates the snowy-owl rescue")
	await frames(210)
	check(winter.owl_rescued and winter.owl.get_parent() == winter.people[2] and not winter.owl_tree_prop.locked,
		"Snowball lands safely on Astrid's arm and unlocks the pine tree")
	await frames(120)
	game.end_dialogue()

	# --- 9. Winter Mission 4: Ice Lane + Supply Sled Delivery (Torsten) ---
	check(not winter.sled_done, "Supply sled starts stuck at SLED_START")
	for x in range(-26, 14, 2):
		game._water_hit(ToyWinterVillage.ORIGIN + Vector3(x, 0.06, 34), 0.25)
	await frames(3)
	check(winter.ice_field.slip_at(winter.sled.position + Vector3(2, 0, 0)) > 0.45,
		"Spraying ahead of the supply sled freezes a slick ice lane")
	place(winter.sled.position + Vector3(-4.2, 0.72, 0), -PI * 0.5)
	game.truck.automated_drive = Vector2(1, 0)
	for _tick in 220:
		if winter.sled_done: break
		# Keep truck nudging behind sled along +X.
		game.truck.linear_velocity.x = maxf(game.truck.linear_velocity.x, 11.5)
		await frames(1)
	game.truck.automated_drive = Vector2.ZERO
	check(winter.sled_done, "Pushing the supply sled across the frozen ice lane delivers it to the golden pad")

	# --- 10. Return West to Maple Bay East Entrance ---
	await frames(120)
	game.end_dialogue()
	travel.start_world(0)
	travel.finish()
	await frames(4)
	check(not travel.in_winter and not travel.in_race and game.town.visible and game.truck.global_position.x > 65.0,
		"Returning from Frostpine Hollow restores Maple Bay with the truck entering from the east road")

	game.queue_free()
	await process_frame
	await process_frame
	print("WINTER & REACTIONS CHECKS: ", "ALL PASS" if failures == 0 else str(failures) + " failed")
	quit(0 if failures == 0 else 1)
