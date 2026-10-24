extends TestCase
## Prototype 0.3 bushes: T08-T14 on the real scene.
## Bush used: centre (6.5, 15) r 1.2 gu. Open comparison: the clearing.

const MAIN := "res://scenes/main/forest_test_01.tscn"
const BUSH := Vector2(6.5, 15.0)

var s: GameSession


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	GameParams.current().rng_seed = 51
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene
	await wait_navigation(s.nav_region)


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func _watcher(at: Vector2, facing: Vector2) -> void:
	s.spawn_killer_at(at, facing)
	s.killer.brain.set_physics_process(false)


## Seconds until the killer's vision reports the survivor (or -1 within limit).
func _time_to_detect(limit: float) -> float:
	var t := 0.0
	while t < limit:
		await tree.physics_frame
		t += 1.0 / 60.0
		if s.killer.vision.scan_group(&"survivor_perceivable", 1.0 / 60.0) != null:
			return t
	return -1.0


func test_t08_stationary_in_bush_much_harder_than_open() -> void:
	var sv := s.survivor
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(15, 10)}
	# open ground, 3 gu in front of the killer
	sv.global_position = g(15, 13)
	_watcher(g(12, 13), Vector2.RIGHT)
	await physics_frames(2)
	var t_open := await _time_to_detect(2.0)
	check(t_open >= 0.0 and t_open < 0.1, "T08: open ground at 3 gu -> seen at once (%.2f s)" % t_open)
	# same distance, stationary in the bush
	sv.global_position = g(BUSH.x, BUSH.y)
	s.killer.global_position = g(BUSH.x, BUSH.y - 3.0)
	s.killer.facing = Vector2.DOWN
	await physics_frames(3)
	check(sv.is_concealed(), "survivor is inside the bush")
	var t_bush := await _time_to_detect(4.0)
	check(t_bush < 0.0, "T08: stationary in the bush at 3 gu -> not seen in 4 s")
	# at touching distance the bush does not save you, after a short recognition
	s.killer.global_position = g(BUSH.x, BUSH.y - 1.0)
	await physics_frames(2)
	var t_close := await _time_to_detect(2.0)
	check(t_close >= 0.3, "T08: at 1 gu seen only after recognition time (%.2f s)" % t_close)


func test_t09_entered_bush_goes_last_seen_without_tracking() -> void:
	var sv := s.survivor
	s.spawn_killer_at(g(BUSH.x + 4.0, BUSH.y - 1.5), Vector2.LEFT)
	sv.global_position = g(BUSH.x + 2.2, BUSH.y)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(BUSH.x - 3, BUSH.y)}
	await physics_frames(3)
	check_eq(s.killer.brain.state_name(), "CHASE", "killer sees the survivor outside the bush")
	sv.scripted_input = {"move": Vector2(-1, 0), "aim": g(BUSH.x - 3, BUSH.y)}
	while not sv.is_concealed():
		await tree.physics_frame
	await physics_frames(10)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(BUSH.x - 3, BUSH.y)}
	var last_seen: Vector2 = s.killer.brain.memory.last_seen_position
	# while the survivor stands still deep in the bush the killer must not track it
	var lost := false
	for i in 120:
		await tree.physics_frame
		var st: String = s.killer.brain.state_name()
		if st == "GO_TO_LAST_SEEN" or st == "LOCAL_SEARCH" or st == "INVESTIGATE_SOUND":
			lost = true
			break
		if st == "ATTACK" or st == "FINISH":
			break
	if lost:
		check(s.killer.brain.memory.last_seen_position.distance_to(last_seen) < GameParams.gu(2.5), "T09: goes to the last really seen point")
	else:
		# killer reached touching distance before losing sight: allowed (contact detection)
		check(s.killer.global_position.distance_to(sv.global_position) < GameParams.gu(2.0), "T09: kept sight only at close range")


func test_t10_t13_rustle_by_gait() -> void:
	var sv := s.survivor
	var em: FootstepEmitter = sv.get_node("FootstepEmitter")
	var rustles: Array = []
	s.get_node("SoundEventBus").sound_emitted.connect(func(ev): if ev.kind == &"foliage": rustles.append(ev))
	# T10 standing still in the bush
	sv.global_position = g(BUSH.x, BUSH.y)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(BUSH.x, BUSH.y - 3)}
	await seconds(3.0)
	check_eq(rustles.size(), 0, "T10: no rustle while standing still")
	var results := {}
	for gait in ["careful", "walk", "sprint"]:
		rustles.clear()
		sv.global_position = g(BUSH.x - 1.0, BUSH.y)
		await physics_frames(2)
		var dir := Vector2(1, 0)
		var t := 0.0
		while t < 2.0:
			var back := sv.global_position.x > g(BUSH.x + 0.9, 0).x
			if back:
				dir = Vector2(-1, 0)
			elif sv.global_position.x < g(BUSH.x - 0.9, 0).x:
				dir = Vector2(1, 0)
			sv.scripted_input = {"move": dir, "aim": g(BUSH.x, BUSH.y - 3), "careful": gait == "careful", "sprint": gait == "sprint"}
			await tree.physics_frame
			t += 1.0 / 60.0
		sv.scripted_input = {"move": Vector2.ZERO}
		results[gait] = {"n": rustles.size(), "r": rustles[0].radius_px / GameParams.PX_PER_GU if rustles.size() > 0 else 0.0}
	check(results.careful.n > 0, "T11: careful movement rustles (%s)" % results)
	check(is_equal_approx(results.careful.r, 2.0), "T11: quiet rustle ~2 gu")
	check(is_equal_approx(results.walk.r, 3.5), "T12: walking rustle ~3.5 gu, louder than careful")
	check(is_equal_approx(results.sprint.r, 5.0), "T13: running rustle ~5 gu")
	check(results.sprint.n >= results.careful.n, "T13: running rustles at least as often (%s)" % results)
	check(results.sprint.n <= 2.0 / GameParams.current().rustle_cadence_min + 1, "T13: no per-frame spam")
	# masking: detection range multipliers keep the order
	var p := GameParams.current()
	check(VisionSensor.bush_visibility(&"idle", p) < VisionSensor.bush_visibility(&"careful", p), "careful less hidden than still")
	check(VisionSensor.bush_visibility(&"careful", p) < VisionSensor.bush_visibility(&"walk", p) and VisionSensor.bush_visibility(&"walk", p) < VisionSensor.bush_visibility(&"sprint", p), "T11-T13: masking weakens with speed")


func test_t14_killer_hears_rustle_only_as_region() -> void:
	var sv := s.survivor
	s.spawn_killer_at(g(BUSH.x + 3.2, BUSH.y + 1.6), Vector2.RIGHT)   # facing away
	await physics_frames(5)
	sv.global_position = g(BUSH.x - 0.6, BUSH.y)
	var t := 0.0
	while t < 1.5 and s.killer.brain.state_name() != "INVESTIGATE_SOUND":
		sv.scripted_input = {"move": Vector2(1 if fmod(t, 1.0) < 0.5 else -1, 0), "aim": g(BUSH.x, BUSH.y - 3)}
		await tree.physics_frame
		t += 1.0 / 60.0
	check_eq(s.killer.brain.state_name(), "INVESTIGATE_SOUND", "T14: rustle heard -> investigate")
	var reg: Variant = s.killer.brain.investigate_region
	check(reg != null and not reg.center.is_equal_approx(sv.global_position), "T14: only an approximate region, not the true position")
	check(reg != null and reg.center.distance_to(sv.global_position) <= reg.radius + GameParams.gu(0.5), "T14: region covers the rustling bush")
	check(not s.killer.brain.memory.has_visual, "T14: no visual contact needed or given")
