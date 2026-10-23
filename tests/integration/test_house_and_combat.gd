extends TestCase
## T02, T03, T04, T07, T08 on the real ForestTest_01 scene.

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func _load(seed: int) -> void:
	GameParams.current().rng_seed = seed
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func _locker() -> Node:
	return tree.get_first_node_in_group(&"cabin").get_node("Locker")


func test_t02_t04_killer_searches_house_and_finds_locker() -> void:
	await _load(3)
	var sv := s.survivor
	var locker := _locker()
	sv.global_position = locker.get_exit_position()
	locker.interact(sv)
	s.prepare_left = 0.05
	var door: Node = tree.get_first_node_in_group(&"cabin").get_node("FrontDoor")
	var door_opened_by_killer := false
	var max_step := 0.0
	var prev := Vector2.INF
	for i in 160 * 60:
		await tree.physics_frame
		if s.killer == null:
			continue
		if prev != Vector2.INF:
			max_step = maxf(max_step, prev.distance_to(s.killer.global_position))
		prev = s.killer.global_position
		if door.is_open():
			door_opened_by_killer = true
		if s.killer.brain.house_stats.hiding_found > 0:
			break
	var h: Dictionary = s.killer.brain.house_stats
	check(h.entries >= 1, "T02: killer entered the house (%s)" % h)
	check(h.rooms_swept >= 2, "T02: both rooms swept (%s)" % h)
	check(h.hiding_found >= 1, "T02: occupied locker opened during a real check (%s)" % h)
	check(door_opened_by_killer, "T04: closed front door opened by the killer's action")
	check(max_step <= GameParams.gu(GameParams.current().killer_speed) / 60.0 * 1.6, "T04: no teleport (max step %.1f px)" % max_step)


func test_t03_empty_locker_is_checked_and_decision_ignores_occupancy() -> void:
	await _load(2)
	s.survivor.global_position = g(28, 2)
	s.survivor.input_enabled = false
	s.prepare_left = 0.05
	for i in 150 * 60:
		await tree.physics_frame
		if s.killer != null and s.killer.brain.house_stats.hiding_checks > 0:
			break
	check(s.killer.brain.house_stats.hiding_checks >= 1, "T03: empty locker checked (%s)" % s.killer.brain.house_stats)
	# Same moment, same memory: chance is identical whether the locker is occupied or not.
	var locker := _locker()
	var now := GameClock.now()
	var p_empty: float = s.killer.brain.hiding_check_chance(locker, now)
	locker.occupant = s.survivor
	var p_occ: float = s.killer.brain.hiding_check_chance(locker, now)
	locker.occupant = null
	check(is_equal_approx(p_empty, p_occ), "T03: check chance independent of occupancy (%.2f vs %.2f)" % [p_empty, p_occ])


func test_t07_two_hits_then_finisher() -> void:
	await _load(1)
	s.spawn_killer()
	var sv := s.survivor
	sv.global_position = g(15, 13)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(16, 13)}
	s.killer.global_position = g(13, 13)
	s.killer.facing = Vector2.RIGHT
	var t := 0.0
	while t < 10.0 and not s.is_finished():
		await tree.physics_frame
		t += 1.0 / 60.0
	var c: Dictionary = s.killer.brain.combat_stats
	check_eq(sv.health.hits, 2, "T07: two confirmed hits")
	check_eq(sv.health.state, HealthComponent.HState.DEAD, "T07: finisher kills")
	check_eq(s.phase, GameSession.Phase.CAUGHT, "T07: CAUGHT screen")
	check_eq(c.attacks_whiffed, 0, "T07: no whiffs on a stationary target (%s)" % c)
	check(t < 7.0, "T07: done within a few seconds (%.1fs)" % t)


func test_t08_no_hit_through_wall_or_locker() -> void:
	await _load(1)
	s.spawn_killer()
	s.killer.brain.set_physics_process(false)
	var sv := s.survivor
	# Survivor inside the bedroom against the north wall; killer just outside.
	sv.global_position = g(5.0, 2.65)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(5, 4)}
	s.killer.global_position = g(5.0, 1.55)
	s.killer.facing = Vector2.DOWN
	await physics_frames(2)
	var r: Dictionary = s.killer.try_hit()
	check(not r.hit, "T08: no hit through the wall")
	check_eq(r.reason, "no_los", "T08: whiff reason is no_los")
	check_eq(sv.health.state, HealthComponent.HState.HEALTHY, "T08: health unchanged")
	var locker := _locker()
	sv.global_position = locker.get_exit_position()
	locker.interact(sv)
	await physics_frames(2)
	s.killer.global_position = locker.get_search_position()
	s.killer.facing = Vector2.UP
	await physics_frames(2)
	r = s.killer.try_hit()
	check(not r.hit, "T08: no hit into a closed locker (%s)" % r.reason)
	check_eq(sv.health.state, HealthComponent.HState.HEALTHY, "T08: hidden survivor unharmed")
