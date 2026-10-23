extends SceneTree
## Stage-0 baseline probe for BUG-01..BUG-05 on the current build.
##   godot --headless --path . --fixed-fps 60 -s res://tools/audit_baseline.gd

func _initialize() -> void:
	_run.call_deferred()


func _load(seed: int) -> GameSession:
	GameParams.set_current(GameParams.new())
	GameParams.current().rng_seed = seed
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	await physics_frame
	await physics_frame
	return current_scene


func _house_rect() -> Rect2:
	return Rect2(Vector2(2, 2) * 32, Vector2(8, 6) * 32)


func _run() -> void:
	# BUG-01: survivor hides in the locker for 3 minutes of hunt.
	for seed in [1, 2, 3]:
		var s := await _load(seed)
		var sv := s.survivor
		var locker: Node = get_nodes_in_group(&"locker")[0]
		sv.global_position = locker.get_exit_position()
		locker.interact(sv)
		s.prepare_left = 0.1
		var inside_frames := 0
		var frames := 180 * 60
		for i in frames:
			await physics_frame
			if s.killer != null and _house_rect().has_point(s.killer.global_position):
				inside_frames += 1
			if s.is_finished():
				break
		print("BUG-01 seed=%d: killer frames inside house=%d / %d, result=%s" % [seed, inside_frames, frames, GameSession.Phase.keys()[s.phase]])
		paused = false
		unload_current_scene()
		await physics_frame
	# BUG-02: survivor flees in a straight line from a chasing killer.
	var s2 := await _load(4)
	s2.spawn_killer()
	s2.survivor.global_position = Vector2(14, 13) * 32
	s2.killer.global_position = Vector2(12, 13) * 32
	s2.killer.facing = Vector2.RIGHT
	var attacks := 0
	var t := 0.0
	var last_state := ""
	for i in 20 * 60:
		var dir := Vector2.RIGHT if (i / 120) % 2 == 0 else Vector2.DOWN
		s2.survivor.scripted_input = {"move": dir, "aim": s2.survivor.global_position + dir}
		await physics_frame
		t += 1.0 / 60.0
		var st: String = s2.killer.brain.state_name()
		if st == "ATTACK" and last_state != "ATTACK":
			attacks += 1
		last_state = st
		if s2.is_finished():
			break
	print("BUG-02: attacks started=%d, result=%s after %.1fs (one hit kills, no wound/down/finish cycle)" % [attacks, GameSession.Phase.keys()[s2.phase], t])
	paused = false
	unload_current_scene()
	await physics_frame
	# BUG-03: run into the exit zone.
	var s3 := await _load(5)
	s3.spawn_killer()
	s3.killer.global_position = Vector2(1, 23) * 32
	s3.survivor.global_position = s3.exit_zone.global_position
	await physics_frame
	await physics_frame
	print("BUG-03: entering exit zone -> %s instantly" % GameSession.Phase.keys()[s3.phase])
	paused = false
	unload_current_scene()
	await physics_frame
	# BUG-04: throw a stone, try to pick it up again.
	var s4 := await _load(6)
	var sv4 := s4.survivor
	sv4.global_position = Vector2(15, 13) * 32
	var stone: Throwable = get_nodes_in_group(&"dynamic_object")[0]
	stone.interact(sv4)
	sv4.try_throw(Vector2(17, 13) * 32)
	for i in 60:
		await physics_frame
	print("BUG-04: thrown stone state=%s, can_interact=%s" % [Throwable.State.keys()[stone.state], stone.can_interact(sv4)])
	unload_current_scene()
	await physics_frame
	# BUG-05: killer walking behind a wall at various distances.
	var s5 := await _load(7)
	s5.spawn_killer()
	s5.killer.brain.set_physics_process(false)
	s5.survivor.global_position = Vector2(3, 5) * 32
	s5.survivor.scripted_input = {"move": Vector2.ZERO, "aim": Vector2(3, 2) * 32}
	for d in [2.0, 3.5, 5.0]:
		s5.killer.global_position = Vector2(3 - d, 4) * 32 if 3 - d > 0.5 else Vector2(1.0, 4) * 32
		s5.killer.global_position = Vector2(2.0 - 0.6, 4) * 32 + Vector2(0, 0)
		s5.killer.global_position = s5.survivor.global_position + Vector2(-d, 0) * 32
		s5.killer.global_position.x = maxf(s5.killer.global_position.x, 16)
		s5.killer.move_to(s5.killer.global_position + Vector2(0, 160))
		var shown := 0
		for i in 60:
			await physics_frame
			if s5.hud.is_footsteps_visible():
				shown += 1
		print("BUG-05: killer walking %.1f gu away behind wall: indicator frames=%d/60 (hearing radius %.1f gu, label is small text at top)" % [s5.killer.global_position.distance_to(s5.survivor.global_position) / 32.0, shown, GameParams.current().footstep_radius_killer])
		s5.killer.stop()
		for i in 60:
			await physics_frame
	quit()
