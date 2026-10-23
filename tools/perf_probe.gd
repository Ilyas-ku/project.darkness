extends SceneTree
## Dev probe: real-time run of the main scene with an active killer; prints FPS and
## per-frame process/physics times. Use with a real renderer for meaningful FPS.
var samples: Array[float] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameParams.current().rng_seed = 9
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	await create_timer(1.0).timeout
	var s: GameSession = current_scene
	s.prepare_left = 0.05
	var sv := s.survivor
	var worst_proc := 0.0
	var worst_phys := 0.0
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t0 < 15000:
		var dir := Vector2.from_angle(frames * 0.01)
		sv.scripted_input = {"move": dir, "aim": sv.global_position + dir * 50}
		if frames % 200 == 0:
			sv.try_throw(sv.global_position + dir * 120)
		await process_frame
		frames += 1
		worst_proc = maxf(worst_proc, Performance.get_monitor(Performance.TIME_PROCESS))
		worst_phys = maxf(worst_phys, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		if s.is_finished():
			s.restart()
			await process_frame
			s = current_scene
			sv = s.survivor
			s.prepare_left = 0.05
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("PERF frames=%d in %.1fs avg_fps=%.1f worst_process_ms=%.2f worst_physics_ms=%.2f renderer=%s" % [frames, secs, frames / secs, worst_proc * 1000.0, worst_phys * 1000.0, RenderingServer.get_video_adapter_name()])
	quit()
