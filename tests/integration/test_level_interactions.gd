extends TestCase
## T13, T14 (footsteps), T15 (window), T16 (furniture, doors), radio, bottle.

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	GameParams.current().rng_seed = 21
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene


func after_each() -> void:
	DebugPresets.active = &""
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func _cabin() -> Node:
	return tree.get_first_node_in_group(&"cabin")


func test_t13_t14_footsteps_presence_only_and_rules() -> void:
	s.spawn_killer_at(g(2.5, 1.0), Vector2.RIGHT)
	s.killer.brain.set_physics_process(false)
	var sv := s.survivor
	sv.global_position = g(5.0, 3.2)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(5.0, 1.0)}
	var heard: Array = []
	sv.hearing.heard.connect(func(o): if o.kind == &"footsteps": heard.append(o))
	s.killer.move_to(g(8.0, 1.0))
	await seconds(0.7)
	check(s.hud.is_footsteps_visible(), "T13: indicator for movement behind the wall")
	check(heard.size() > 0, "T13: footsteps observation delivered")
	for o in heard:
		check(o.approximate_region == null and o.is_nearby_presence, "T13: presence only, no region")
		check_eq(o.to_dict().keys().size(), 4, "T13: no position/direction/role/count keys")
	s.killer.stop()
	await seconds(0.8)
	check(not s.hud.is_footsteps_visible(), "T14: gone after the killer stops (<= 0.75 s)")
	# far away
	s.killer.global_position = g(16, 1.0)
	s.killer.move_to(g(20, 1.0))
	await seconds(0.8)
	check(not s.hud.is_footsteps_visible(), "T14: no indicator when out of range")
	check_eq(sv.hearing.last_footsteps_diag.get("reason", ""), "out of hearing range", "T14: diagnostic reason out of range")
	# visible: same distance, in the open, in front of the survivor
	sv.global_position = g(15, 13)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(18, 13)}
	s.killer.global_position = g(17, 12)
	s.killer.move_to(g(17, 15))
	await seconds(0.8)
	check(s.perception.killer_perceived, "killer visible")
	check(not s.hud.is_footsteps_visible(), "T14: no indicator while the source is visible")
	check_eq(sv.hearing.last_footsteps_diag.get("reason", ""), "source in direct LOS", "T14: diagnostic reason LOS")


func test_t15_window_vault_and_killer_route() -> void:
	var win: Node2D = _cabin().get_node("Window")
	var sv := s.survivor
	sv.global_position = win.global_position + g(0.7, 0)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": win.global_position, "interact_held": true}
	await physics_frames(2)
	check(sv.focus == win, "window focused")
	check(sv.try_interact(), "T15: vault started")
	var max_step := 0.0
	var prev := sv.global_position
	await physics_frames(1)
	for i in 80:
		await tree.physics_frame
		max_step = maxf(max_step, prev.distance_to(sv.global_position))
		prev = sv.global_position
	check(sv.global_position.x < win.global_position.x - GameParams.gu(0.3), "T15: survivor ended outside")
	check(max_step < GameParams.gu(0.2), "T15: smooth move, no teleport (%.1f px/frame)" % max_step)
	# killer starts in the bedroom and must get out after the survivor
	s.spawn_killer_at(g(5.5, 5.0), Vector2.LEFT)
	sv.scripted_input = {"move": Vector2(-1, 0.3), "aim": g(0, 6)}
	var killer_out := false
	for i in 12 * 60:
		await tree.physics_frame
		if s.killer.global_position.x < GameParams.gu(3.0) or s.killer.global_position.y > GameParams.gu(8.0):
			killer_out = true
			break
	check(killer_out, "T15: killer left the house by a valid route (window or door)")


func test_t16_push_crate_changes_navigation_and_makes_noise() -> void:
	var crate: Node2D = _cabin().get_node("Crate")
	var sv := s.survivor
	sv.global_position = crate.global_position + g(0, 0.85)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": crate.global_position, "interact_held": true}
	await physics_frames(2)
	var events: Array = []
	s.get_node("SoundEventBus").sound_emitted.connect(func(ev): if ev.kind == &"furniture": events.append(ev))
	var nav_map: RID = s.nav_region.get_navigation_map()
	var probe := crate.global_position + g(0, -1.0)
	var before := NavigationServer2D.map_get_closest_point(nav_map, probe)
	var old_pos := crate.global_position
	check(sv.focus == crate, "crate focused")
	check(sv.try_interact(), "T16: push started")
	await seconds(1.7)
	check(crate.global_position.distance_to(old_pos + g(0, -1.0)) < 1.0, "T16: crate moved 1 gu")
	check_eq(events.size(), 1, "T16: push makes a sound")
	await physics_frames(3)
	var after := NavigationServer2D.map_get_closest_point(nav_map, probe)
	check(after.distance_to(probe) > before.distance_to(probe) + 4.0, "T16: navigation rebuilt around the crate")


func test_t16_doors_change_los_and_passage() -> void:
	var door: Node = _cabin().get_node("FrontDoor")
	var sv := s.survivor
	var outside: Vector2 = door.global_position + g(0, 1.5)
	var inside: Vector2 = door.global_position + g(0, -1.5)
	sv.global_position = outside
	sv.scripted_input = {"move": Vector2.ZERO, "aim": inside}
	await physics_frames(2)
	check(not sv.vision.can_see_point(inside), "closed door blocks LOS")
	door.set_open(true, sv)
	await physics_frames(2)
	check(sv.vision.can_see_point(inside), "open door lets LOS through")
	sv.scripted_input = {"move": Vector2(0, -1), "aim": inside}
	await seconds(1.0)
	check(sv.global_position.y < door.global_position.y, "open doorway is passable")


func test_radio_distracts_and_killer_switches_it_off() -> void:
	var radio: Node2D = _cabin().get_node("Radio")
	radio.set_on(true)
	s.survivor.global_position = g(25, 3)
	s.survivor.input_enabled = false
	s.spawn_killer_at(g(10.5, 10.5), Vector2.UP)
	var investigated := false
	for i in 25 * 60:
		await tree.physics_frame
		if s.killer.brain.state_name() == "INVESTIGATE_SOUND":
			investigated = true
		if not radio.is_on:
			break
	check(investigated, "radio sound investigated")
	check(not radio.is_on, "killer switched the radio off")


func test_bottle_breaks_with_loud_sound() -> void:
	var bottle: Throwable = _cabin().get_node("Bottle")
	var sv := s.survivor
	sv.global_position = bottle.global_position + g(0.5, 0)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": bottle.global_position}
	await physics_frames(2)
	bottle.interact(sv)
	var events: Array = []
	s.get_node("SoundEventBus").sound_emitted.connect(func(ev): if ev.kind == &"glass": events.append(ev))
	sv.try_throw(sv.global_position + g(0, -3))
	await seconds(0.8)
	check_eq(events.size(), 1, "bottle: one glass event")
	check(events.size() == 1 and is_equal_approx(events[0].radius_px, GameParams.gu(11.0)), "bottle louder than stone")
	check(not is_instance_valid(bottle), "bottle broken (single use, unlike stone)")


func test_t19_restart_resets_state() -> void:
	var sv := s.survivor
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[0]
	stone.interact(sv)
	s.spawn_killer()
	_cabin().get_node("FrontDoor").set_open(true, sv)
	s.restart()
	await physics_frames(3)
	var s2: GameSession = tree.current_scene
	check(s2 != s, "new session")
	check_eq(s2.survivor.inventory.count(), 0, "T19: inventory reset")
	check_eq(s2.phase, GameSession.Phase.PREPARE, "T19: preparation again")
	check(s2.killer == null, "T19: killer reset")
	check(not tree.get_first_node_in_group(&"cabin").get_node("FrontDoor").is_open(), "T19: doors reset")
	for st in tree.get_nodes_in_group(&"stone"):
		check(st.state == Throwable.State.WORLD_PICKABLE, "T19: stones reset")
	check_eq(s2.survivor.health.state, HealthComponent.HState.HEALTHY, "T19: health reset")
