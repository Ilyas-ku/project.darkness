extends SceneTree
## Dev probe: killer vs stationary / fleeing victim in the open.
func _initialize() -> void:
	_run.call_deferred()

func _case(seed: int, flee: bool) -> void:
	GameParams.set_current(GameParams.new())
	GameParams.current().rng_seed = seed
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	await physics_frame
	await physics_frame
	var s: GameSession = current_scene
	s.spawn_killer()
	var sv := s.survivor
	sv.global_position = Vector2(15, 13) * 32
	s.killer.global_position = Vector2(12, 13) * 32
	s.killer.facing = Vector2.RIGHT
	var t := 0.0
	var events: Array[String] = []
	sv.health.state_changed.connect(func(o, n): events.append("%.2fs %s" % [t, HealthComponent.HState.keys()[n]]))
	for i in 40 * 60:
		var dir := Vector2.ZERO
		if flee:
			var away: Vector2 = (sv.global_position - s.killer.global_position).normalized()
			dir = away.rotated(0.6 * sin(t))
		sv.scripted_input = {"move": dir, "aim": sv.global_position + Vector2.RIGHT, "sprint": flee}
		await physics_frame
		t += 1.0 / 60.0
		if s.is_finished():
			break
	print("seed=%d flee=%s result=%s t=%.1f health=%s combat=%s" % [seed, flee, GameSession.Phase.keys()[s.phase], t, events, s.killer.brain.combat_stats])
	paused = false
	unload_current_scene()
	await physics_frame

func _run() -> void:
	for seed in [1, 2, 3]:
		await _case(seed, false)
	for seed in [1, 2, 3]:
		await _case(seed, true)
	quit()
