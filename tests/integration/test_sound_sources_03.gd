extends TestCase
## Prototype 0.3: T06, T07 (independent footstep sources) and T18 (situational SFX).

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession
var voices: Array = []
var emitted: Array = []
var heard_steps := 0


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func _load(preset: StringName) -> void:
	DebugPresets.active = preset
	GameParams.current().rng_seed = 42
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene
	await wait_navigation(s.nav_region)
	voices.clear()
	emitted.clear()
	heard_steps = 0
	s.survivor.hearing.heard.connect(func(o): if o.kind == &"footsteps": heard_steps += 1)
	s.audio.voice_played.connect(func(k, p, b): voices.append({"key": k, "pos": p, "bus": b, "t": GameClock.now()}))
	s.get_node("SoundEventBus").sound_emitted.connect(func(ev): emitted.append(ev))


func after_each() -> void:
	DebugPresets.active = &""
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func test_t06_t07_two_independent_rhythms_then_one() -> void:
	await _load(&"TEST_STEPS_TWO_RUNNERS")
	var sv := s.survivor
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(15, 17)}   # facing south, runners behind
	await seconds(6.0)
	var steps := emitted.filter(func(e): return e.kind == &"footsteps")
	var ids := {}
	for e in steps:
		ids[e.emitter_id] = ids.get(e.emitter_id, 0) + 1
	check_eq(ids.size(), 2, "T06: two independent step sources")
	# interleaving: the sequence of sources switches many times (two overlapping rhythms)
	var switches := 0
	for i in range(1, steps.size()):
		if steps[i].emitter_id != steps[i - 1].emitter_id:
			switches += 1
	check(switches >= 6, "T06: rhythms interleave (%d switches)" % switches)
	var step_voices := voices.filter(func(v): return String(v.key).begins_with("step"))
	check(heard_steps > 0 and step_voices.size() == heard_steps, "T06: every audible step got its own voice (%d voices / %d heard)" % [step_voices.size(), heard_steps])
	var overlaps := 0
	for i in range(1, step_voices.size()):
		if step_voices[i].t - step_voices[i - 1].t < 0.15:
			overlaps += 1
	check(overlaps >= 1, "T06: voices overlap instead of cutting each other (%d)" % overlaps)
	check(not voices.any(func(v): return String(v.key) == "count"), "T06: no source count anywhere")
	# T07: the walker stops at 8 s; afterwards only the runner keeps stepping
	await seconds(3.0)
	var mark := emitted.size()
	await seconds(3.0)
	var later := emitted.slice(mark).filter(func(e): return e.kind == &"footsteps")
	var later_ids := {}
	for e in later:
		later_ids[e.emitter_id] = true
	check_eq(later_ids.size(), 1, "T07: only the stopped source went silent")
	check(later.size() > 0, "T07: the runner is still heard")


func test_t18_situational_events_really_play() -> void:
	for key in AudioDirector.STREAMS:
		for f in AudioDirector.STREAMS[key]:
			check(ResourceLoader.exists("res://assets/" + f), "audio file exists: %s" % f)
	await _load(&"TEST_SOUND_EVENTS")
	s.survivor.scripted_input = {"move": Vector2.ZERO, "aim": g(5.4, 7.0)}
	await seconds(13.0)
	var keys := {}
	for v in voices:
		keys[String(v.key)] = true
	for k in ["door", "door_close", "locker", "window", "throw", "impact", "glass", "hit", "wound", "gate"]:
		check(keys.has(k), "T18: '%s' played (%s)" % [k, str(keys.keys())])
	# heard events are placed at their (approximate) side: the window is west of the survivor
	var win_v := voices.filter(func(v): return String(v.key) == "window")
	check(win_v.size() > 0 and win_v[0].pos.x < s.survivor.global_position.x, "T18: window sound comes from the west")
