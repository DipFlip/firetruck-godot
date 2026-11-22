class_name SprayReactions
extends Node

# Unified NPC & animal water-spray reactions across Maple Bay, Motorway Race
# Club and Frostpine Hollow. Grandstand spectators and winter skaters cheer and
# hop happily; residents and walkers raise their arms and jump/lean back with a
# playful "whoa"; pets, ducks, birds and the winter owl each react uniquely.

const CHEER_DURATION := 1.15
const STARTLE_DURATION := 0.95
const ANIMAL_DURATION := 0.72
const SOUND_COOLDOWN := 1.15

var game: Node3D
var active: Dictionary = {}
var cooldowns: Dictionary = {}
var reaction_counts: Dictionary = {"cheer": 0, "startle": 0, "animal": 0, "bird": 0, "duck": 0}
var clock := 0.0

func _ready() -> void:
	name = "SprayReactions"

func clear() -> void:
	for actor in active.keys():
		_finish_actor(actor, active[actor])
	active.clear()
	cooldowns.clear()

func water_hit(point: Vector3, _amount: float) -> bool:
	if not game or game.paused or (game.travel and game.travel.active): return false
	var hit_any := false
	if game.travel and game.travel.in_race:
		var race: ToyRaceTrack = game.travel.race
		for spectator in race.spectators:
			if _hit_person(spectator, point, "cheer", true): hit_any = true
		for person in race.people:
			if _hit_person(person, point, "startle", true): hit_any = true
		if is_instance_valid(race.camera_operator):
			if _hit_person(race.camera_operator, point, "startle", true): hit_any = true
		for walker in race.walkers:
			if _hit_person(walker.actor, point, "startle", false): hit_any = true
		for i in race.ducks.size():
			var duck := race.ducks[i]
			if is_instance_valid(duck) and duck.is_visible_in_tree() and duck.global_position.distance_squared_to(point) < 2.25:
				if _ready_for_sound(duck):
					race.startle_duck(i, game.truck.global_position)
					reaction_counts.duck += 1
				hit_any = true
		return hit_any

	if game.travel and game.travel.in_winter:
		var winter = game.travel.winter
		if winter:
			for skater in winter.skaters:
				if skater.visible and _hit_person(skater, point, "cheer", false): hit_any = true
			for person in winter.people:
				if _hit_person(person, point, "startle", true): hit_any = true
			for walker in winter.walkers:
				if _hit_person(walker.actor, point, "startle", false): hit_any = true
			if is_instance_valid(winter.owl) and not winter.owl_rescue_running and winter.owl.is_visible_in_tree():
				if _hit_animal(winter.owl, point, "owl", 1.35): hit_any = true
			for bird in winter.ground_birds:
				var node: Node3D = bird.node
				if bird.mode != "flee" and is_instance_valid(node) and node.global_position.distance_squared_to(point) < 2.6:
					winter.startle_bird(bird, game.truck.global_position)
					reaction_counts.bird += 1
					hit_any = true
		return hit_any

	# Maple Bay residents, Rowan, walkers, Biscuit, Pippin and ground birds.
	for i in game.town.people.size():
		var person: Node3D = game.town.people[i]
		# If Maya is holding Pippin, keep her gentle without throwing arms up.
		var gentle: bool = i == 0 and bool(game.town.cat_cuddling)
		if _hit_person(person, point, "startle", true, gentle): hit_any = true
	if game.railway and not game.railway.boarded and game.railway.boarding_time <= 0 and is_instance_valid(game.railway.driver):
		if _hit_person(game.railway.driver, point, "startle", true): hit_any = true
	if game.life:
		for walker in game.life.walkers:
			if _hit_person(walker.node, point, "startle", false): hit_any = true
		for bird in game.life.ground_birds:
			var node: Node3D = bird.node
			if bird.mode != "flee" and is_instance_valid(node) and node.global_position.distance_squared_to(point) < 2.6:
				game.life.startle_bird(bird, game.truck.global_position)
				reaction_counts.bird += 1
				hit_any = true
	if is_instance_valid(game.town.dog) and game.town.dog.is_visible_in_tree():
		if _hit_animal(game.town.dog, point, "dog", 1.45): hit_any = true
	if is_instance_valid(game.town.cat) and not game.rescue_running and not game.town.cat_cuddling and game.town.cat.is_visible_in_tree():
		if _hit_animal(game.town.cat, point, "cat", 1.2): hit_any = true
	return hit_any

func _ready_for_sound(actor: Node3D) -> bool:
	var last := float(cooldowns.get(actor, -100.0))
	if clock - last < SOUND_COOLDOWN: return false
	cooldowns[actor] = clock
	return true

func _hit_person(actor: Node3D, point: Vector3, kind: String, stationary: bool, gentle: bool = false) -> bool:
	if not is_instance_valid(actor) or not actor.is_visible_in_tree(): return false
	if actor.get_meta("mission_celebrating", false): return false
	var center := actor.global_position + Vector3.UP * 1.25
	if center.distance_squared_to(point) > 2.4: return false
	var local := point - actor.global_position
	if absf(local.x) > 1.15 or absf(local.z) > 1.15 or local.y < -0.2 or local.y > 2.8: return false
	_trigger_person(actor, kind, stationary, gentle)
	return true

func _trigger_person(actor: Node3D, kind: String, stationary: bool, gentle: bool = false) -> void:
	var fresh := not active.has(actor)
	if fresh:
		var away: Vector3 = actor.global_position - game.truck.global_position
		away.y = 0
		if away.length_squared() < 0.01: away = Vector3(0, 0, 1)
		else: away = away.normalized()
		# Convert world dodge offset into parent-local space.
		var local_away: Vector3 = away
		if actor.get_parent() is Node3D:
			local_away = (actor.get_parent() as Node3D).global_basis.inverse() * away
			local_away.y = 0
			if local_away.length_squared() > 0.001: local_away = local_away.normalized()
		var left: Node3D = actor.get_node_or_null("ArmLeft")
		var right: Node3D = actor.get_node_or_null("ArmRight")
		var head: Node3D = actor.get_node_or_null("HeadPivot")
		active[actor] = {
			"kind": kind,
			"stationary": stationary,
			"gentle": gentle,
			"age": 0.0,
			"duration": CHEER_DURATION if kind == "cheer" else STARTLE_DURATION,
			"home_pos": actor.position,
			"home_yaw": actor.rotation.y,
			"dodge": local_away * (0.0 if kind == "cheer" or gentle else (0.62 if stationary else 0.95)),
			"left": left.rotation if left else Vector3.ZERO,
			"right": right.rotation if right else Vector3.ZERO,
			"head": head.rotation if head else Vector3.ZERO,
			"phase": randf() * TAU,
		}
		actor.set_meta("spray_reacting", true)
		ToyModels.set_face_reaction(actor, true, kind == "cheer")
	else:
		# Extend slightly while continuously sprayed without snapping the hop.
		var state: Dictionary = active[actor]
		state.age = minf(state.age, state.duration * 0.45)

	if _ready_for_sound(actor):
		if kind == "cheer":
			var sfx := "giggle" if randf() < 0.6 else "cheer"
			game.sounds.play(sfx, actor.global_position + Vector3.UP * 1.8, 0.85, 0.25, randf_range(0.95, 1.12))
			reaction_counts.cheer += 1
		else:
			game.sounds.play("whoa", actor.global_position + Vector3.UP * 1.8, 0.88, 0.22, randf_range(0.92, 1.14))
			reaction_counts.startle += 1

func _hit_animal(animal: Node3D, point: Vector3, kind: String, radius: float) -> bool:
	var center := animal.global_position + Vector3.UP * 0.6
	if center.distance_squared_to(point) > radius * radius: return false
	var fresh := not active.has(animal)
	if fresh:
		active[animal] = {
			"kind": kind,
			"age": 0.0,
			"duration": ANIMAL_DURATION,
			"home_pos": animal.position,
			"home_yaw": animal.rotation.y,
		}
		animal.set_meta("spray_reacting", true)
	else:
		active[animal].age = minf(active[animal].age, ANIMAL_DURATION * 0.4)
	if _ready_for_sound(animal):
		if kind == "dog":
			game.sounds.play("dog_jump" if randf() < 0.5 else "woof", animal.global_position, 0.82, 0.4)
		elif kind == "cat":
			game.sounds.play("meow", animal.global_position, 0.85, 0.45)
		elif kind == "owl":
			game.sounds.play("owl", animal.global_position, 0.88, 0.5)
		reaction_counts.animal += 1
	return true

func _process(dt: float) -> void:
	if not game or game.paused or game.loading: return
	clock += dt
	var finished: Array[Node3D] = []
	for actor: Node3D in active.keys():
		if not is_instance_valid(actor) or actor.get_meta("mission_celebrating", false):
			finished.append(actor)
			continue
		var state: Dictionary = active[actor]
		state.age += dt
		var t: float = clampf(state.age / state.duration, 0.0, 1.0)
		var kind: String = state.kind
		if kind == "cheer":
			_pose_cheer(actor, state, t)
		elif kind == "startle":
			_pose_startle(actor, state, t)
		else:
			_pose_animal(actor, state, t)
		if t >= 1.0:
			finished.append(actor)
	for actor in finished:
		if active.has(actor):
			_finish_actor(actor, active[actor])
			active.erase(actor)

func _pose_cheer(actor: Node3D, state: Dictionary, t: float) -> void:
	var blend := smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.76, 1.0, t))
	# Two joyful little hops with both arms raised and waving!
	var hop1 := maxf(0.0, sin(clampf(t / 0.48, 0.0, 1.0) * PI))
	var hop2 := maxf(0.0, sin(clampf((t - 0.44) / 0.48, 0.0, 1.0) * PI)) * 0.78
	actor.position = state.home_pos + Vector3.UP * (hop1 + hop2) * 0.46
	var wave := sin(state.age * 15.0 + state.phase) * 0.28
	var left: Node3D = actor.get_node_or_null("ArmLeft")
	var right: Node3D = actor.get_node_or_null("ArmRight")
	if left: left.rotation = (state.left as Vector3).lerp(Vector3(0.20, 0.0, -2.55 + wave), blend)
	if right: right.rotation = (state.right as Vector3).lerp(Vector3(0.20, 0.0, 2.55 - wave), blend)
	var head: Node3D = actor.get_node_or_null("HeadPivot")
	if head: head.rotation = (state.head as Vector3).lerp(Vector3(-0.14, sin(state.age * 8.0) * 0.18, 0.0), blend)

func _pose_startle(actor: Node3D, state: Dictionary, t: float) -> void:
	var blend := smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.72, 1.0, t))
	var hop := sin(clampf(t / 0.55, 0.0, 1.0) * PI)
	# Stationary residents hop back then step back to their mark; walkers hop back.
	var back_curve := sin(t * PI) if state.stationary else smoothstep(0.0, 0.55, t)
	actor.position = state.home_pos + (state.dodge as Vector3) * back_curve + Vector3.UP * hop * (0.14 if state.gentle else 0.42)
	if not state.gentle:
		var left: Node3D = actor.get_node_or_null("ArmLeft")
		var right: Node3D = actor.get_node_or_null("ArmRight")
		var shake := sin(state.age * 20.0 + state.phase) * 0.22
		if left: left.rotation = (state.left as Vector3).lerp(Vector3(0.65, 0.0, -2.15 + shake), blend)
		if right: right.rotation = (state.right as Vector3).lerp(Vector3(0.65, 0.0, 2.15 - shake), blend)
	var head: Node3D = actor.get_node_or_null("HeadPivot")
	if head: head.rotation = (state.head as Vector3).lerp(Vector3(0.10, sin(state.age * 16.0) * 0.28, 0.0), blend)

func _pose_animal(animal: Node3D, state: Dictionary, t: float) -> void:
	var hop := sin(clampf(t / 0.52, 0.0, 1.0) * PI)
	var hop2 := sin(clampf((t - 0.45) / 0.50, 0.0, 1.0) * PI) * 0.65
	animal.position = state.home_pos + Vector3.UP * (hop + hop2) * (0.36 if state.kind == "dog" else 0.30)
	if state.kind == "dog":
		animal.rotation.y = state.home_yaw + sin(state.age * 22.0) * 0.32 * (1.0 - t)
	elif state.kind == "owl":
		var flap := sin(state.age * 26.0) * 0.75 * (1.0 - t)
		var wl: Node3D = animal.get_node_or_null("WingLeft")
		var wr: Node3D = animal.get_node_or_null("WingRight")
		if wl: wl.rotation.z = -absf(flap) - 0.35 * (1.0 - t)
		if wr: wr.rotation.z = absf(flap) + 0.35 * (1.0 - t)

func _finish_actor(actor: Node3D, state: Dictionary) -> void:
	if not is_instance_valid(actor): return
	actor.remove_meta("spray_reacting")
	if state.kind in ["cheer", "startle"]:
		ToyModels.set_face_reaction(actor, false)
		if state.stationary:
			actor.position = state.home_pos
		else:
			actor.position = state.home_pos + (state.dodge as Vector3)
			actor.position.y = state.home_pos.y
		if not actor.get_meta("mission_celebrating", false):
			var left: Node3D = actor.get_node_or_null("ArmLeft")
			var right: Node3D = actor.get_node_or_null("ArmRight")
			var head: Node3D = actor.get_node_or_null("HeadPivot")
			if left: left.rotation = state.left
			if right: right.rotation = state.right
			if head: head.rotation = state.head
	else:
		actor.position = state.home_pos
		if state.kind == "owl":
			var wl: Node3D = actor.get_node_or_null("WingLeft")
			var wr: Node3D = actor.get_node_or_null("WingRight")
			if wl: wl.rotation.z = 0.0
			if wr: wr.rotation.z = 0.0
