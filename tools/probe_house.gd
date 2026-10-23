extends SceneTree
## Dev probe: survivor hides in the locker; report killer house behaviour per seed.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var occupied := not OS.get_cmdline_user_args().has("--empty")
	for seed in [1, 2, 3, 4, 5]:
		GameParams.set_current(GameParams.new())
		GameParams.current().rng_seed = seed
		change_scene_to_file("res://scenes/main/forest_test_01.tscn")
		await physics_frame
		await physics_frame
		var s: GameSession = current_scene
		var sv := s.survivor
		var locker: Node = get_nodes_in_group(&"locker")[0]
		if occupied:
			sv.global_position = locker.get_exit_position()
			locker.interact(sv)
		else:
			sv.global_position = Vector2(28, 2) * 32
			sv.input_enabled = false
		s.prepare_left = 0.05
		var first_entry := -1.0
		var first_check := -1.0
		var t := 0.0
		for i in 200 * 60:
			await physics_frame
			t += 1.0 / 60.0
			if s.killer == null:
				continue
			var h: Dictionary = s.killer.brain.house_stats
			if first_entry < 0 and h.entries > 0:
				first_entry = t
			if first_check < 0 and h.hiding_checks + h.hiding_found > 0:
				first_check = t
			if s.is_finished():
				break
		var h2: Dictionary = s.killer.brain.house_stats
		print("seed=%d occupied=%s first_entry=%.0fs first_check=%.0fs stats=%s result=%s" % [seed, occupied, first_entry, first_check, h2, GameSession.Phase.keys()[s.phase]])
		for l in s.killer.brain.transition_log:
			print("    ", l)
		paused = false
		unload_current_scene()
		await physics_frame
	quit()
