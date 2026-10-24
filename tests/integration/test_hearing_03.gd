extends TestCase
## Prototype 0.3 hearing: T01-T05, T20 on the real scene (killer brain disabled,
## the killer body is driven along fixed paths).

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession
var heard: Array = []
var voices: Array = []


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	GameParams.current().rng_seed = 41
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene
	await wait_navigation(s.nav_region)
	heard.clear()
	voices.clear()
	s.survivor.hearing.heard.connect(func(o): heard.append(o))
	s.audio.voice_played.connect(func(k, p, b): voices.append({"key": k, "pos": p, "bus": b}))


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func _killer_at(p: Vector2) -> void:
	s.spawn_killer_at(p, Vector2.RIGHT)
	s.killer.brain.set_physics_process(false)


func _steps() -> Array:
	return heard.filter(func(o): return o.kind == &"footsteps")


func _walk(to: Vector2, t: float) -> void:
	s.killer.move_to(to)
	await seconds(t)


func test_t01_t02_closet_hears_real_steps_and_stays_hidden() -> void:
	var locker: Node = tree.get_first_node_in_group(&"cabin").get_node("Locker")
	var sv := s.survivor
	sv.global_position = locker.get_exit_position()
	locker.interact(sv)
	await physics_frames(2)
	_killer_at(g(7.5, 5.2))
	await _walk(g(4.0, 4.6), 1.6)
	var steps := _steps()
	check(steps.size() >= 2, "T01: steps of the killer walking past the closet are heard (%d)" % steps.size())
	check(steps.all(func(o): return o.muffled), "T01: heard muffled from inside the closet")
	check(voices.any(func(v): return String(v.bus) == "FootstepsMuffled"), "T01: real positional voices on the muffled footsteps bus")
	check(s.sound_markers.spawned > 0, "T01: approximate marker spawned")
	check(s.killer.vision.scan_group(&"survivor_perceivable", 0.016) == null, "T01: closet still hides the survivor from sight")
	# T02: the killer stands right next to the closet
	s.killer.stop()
	await seconds(0.3)
	var n_after_stop := _steps().size()
	var v_after_stop := voices.size()
	await seconds(1.5)
	check_eq(_steps().size(), n_after_stop, "T02: no new steps while the killer stands still")
	check_eq(voices.size(), v_after_stop, "T02: no phantom step voices")
	check_eq(s.sound_markers.active_count(&"footsteps"), 0, "T02: marker faded out")


func test_t03_steps_behind_wall_heard_muffled_killer_unseen() -> void:
	var sv := s.survivor
	sv.global_position = g(5.0, 3.2)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(5.0, 1.0)}
	_killer_at(g(3.5, 1.0))
	await _walk(g(9.5, 1.0), 1.5)
	var steps := _steps()
	check(steps.size() >= 2, "T03: steps behind the wall heard (%d)" % steps.size())
	check(steps.all(func(o): return o.muffled), "T03: muffled by the wall")
	check(not s.perception.killer_perceived and not s.killer.visual.visible, "T03: killer stays invisible")
	check(s.sound_markers.spawned > 0, "T03: approximate area shown")
	for o in steps:
		check(o.region_center().distance_to(s.killer.global_position) < GameParams.gu(6.0), "region roughly where the steps are")


func test_t04_left_then_right_pan_and_marker_follow() -> void:
	var sv := s.survivor
	sv.global_position = g(15, 13)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(15, 10)}   # looking north: left/right are out of view
	_killer_at(g(11.0, 15.5))
	await _walk(g(11.0, 11.0), 1.2)
	var left_v := voices.filter(func(v): return v.key.begins_with("step"))
	var left_m: Array = s.sound_markers.get_markers().duplicate()
	check(left_v.size() > 0 and left_v.all(func(v): return v.pos.x < sv.global_position.x), "T04: voices placed on the left")
	check(left_m.size() > 0 and left_m.all(func(m): return m.center.x < sv.global_position.x), "T04: marker on the left")
	voices.clear()
	s.killer.global_position = g(19.0, 15.5)
	await _walk(g(19.0, 11.0), 1.2)
	var right_v := voices.filter(func(v): return v.key.begins_with("step"))
	check(right_v.size() > 0 and right_v.all(func(v): return v.pos.x > sv.global_position.x), "T04: voices move to the right")
	var newest: Array = s.sound_markers.get_markers().filter(func(m): return m.center.x > sv.global_position.x)
	check(newest.size() > 0, "T04: marker on the right")
	for o in _steps():
		check(not o.region_center().is_equal_approx(s.killer.global_position), "T04: no exact pin")


func test_t05_range_and_door() -> void:
	var sv := s.survivor
	var door: Node = tree.get_first_node_in_group(&"cabin").get_node("FrontDoor")
	# inside the living room, the killer walks just outside the closed front door
	sv.global_position = g(9.2, 6.7)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(9.2, 3.0)}
	_killer_at(g(7.8, 9.0))
	await _walk(g(10.6, 9.0), 1.0)
	var closed := _steps()
	check(closed.size() > 0, "T05: closed door does not mute steps within range")
	check(closed.all(func(o): return o.muffled), "T05: closed door muffles")
	heard.clear()
	door.set_open(true, null)
	await physics_frames(2)
	await _walk(g(7.8, 9.0), 1.0)
	var opened := _steps()
	check(opened.size() > 0 and opened.any(func(o): return not o.muffled), "T05: open doorway lets steps through unmuffled")
	var vol_closed: float = closed.map(func(o): return o.volume).max() if closed.size() > 0 else 0.0
	var vol_open: float = opened.map(func(o): return o.volume).max() if opened.size() > 0 else 0.0
	check(vol_open > vol_closed, "T05: louder through the open door (%.2f > %.2f)" % [vol_open, vol_closed])
	# far away: out of range, nothing heard, reason recorded
	heard.clear()
	s.killer.global_position = g(25, 22)
	var before: int = s.killer.get_node("FootstepEmitter").steps_emitted
	await _walk(g(27.5, 22), 1.5)
	check(s.killer.get_node("FootstepEmitter").steps_emitted > before, "far killer really stepped")
	check_eq(_steps().size(), 0, "T05: out of range -> nothing")
	check(String(sv.hearing.last_footsteps_diag.get("reason", "")).begins_with("out of range"), "T05: fade reason recorded")


func test_t20_debug_chain_event_audible_voice_marker() -> void:
	var sv := s.survivor
	sv.global_position = g(15, 13)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(15, 10)}
	_killer_at(g(12.5, 14.5))
	await _walk(g(12.5, 11.0), 1.0)
	s.killer.global_position = g(24, 22)
	await _walk(g(26, 22), 0.8)
	var audible := sv.hearing.debug_log.filter(func(e): return e.audible and e.event_type == &"footsteps")
	var silent := sv.hearing.debug_log.filter(func(e): return not e.audible and e.event_type == &"footsteps")
	check(audible.size() > 0 or _steps().size() > 0, "chain has audible entries")
	for e in audible:
		check(e.audio_play_called and e.marker_spawned, "T20: audible -> play called and marker spawned")
	check(silent.size() > 0, "T20: inaudible entries recorded")
	for e in silent:
		check(not e.audio_play_called and not e.marker_spawned, "T20: inaudible -> no sound and no marker")
		check(String(e.reason).begins_with("out of range"), "T20: stage where it stopped is named")
