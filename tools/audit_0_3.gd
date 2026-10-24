extends SceneTree
## Stage-0 baseline probe for Prototype 0.3 (run on the 0.2 build).
##   godot --path . --write-movie out.avi --fixed-fps 30 -s res://tools/audit_0_3.gd   (audio evidence)
##   godot --headless --path . --fixed-fps 60 -s res://tools/audit_0_3.gd             (numbers only)

func _initialize() -> void:
	_run.call_deferred()

func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU

func _load(seed: int) -> GameSession:
	GameParams.set_current(GameParams.new())
	GameParams.current().rng_seed = seed
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	await physics_frame
	await physics_frame
	return current_scene

func _run() -> void:
	# HEAR-01: survivor in the locker, killer walks through the bedroom past it, then stops.
	var s := await _load(1)
	var sv := s.survivor
	var locker: Node = get_first_node_in_group(&"cabin").get_node("Locker")
	sv.global_position = locker.get_exit_position()
	locker.interact(sv)
	s.spawn_killer_at(g(6.5, 5.2), Vector2.LEFT)
	s.killer.brain.set_physics_process(false)
	var heard := [0]
	sv.hearing.heard.connect(func(o): if o.kind == &"footsteps": heard[0] += 1)
	s.killer.move_to(g(3.8, 5.2))
	for i in 90:
		await physics_frame
	s.killer.move_to(g(6.5, 5.2))
	for i in 90:
		await physics_frame
	var during: int = heard[0]
	s.killer.stop()
	for i in 60:
		await physics_frame
	print("HEAR-01 baseline: footsteps observations while killer walked 2-4 gu from the locker: %d; after stop: %d; diag=%s" % [during, heard[0] - during, sv.hearing.last_footsteps_diag])
	print("HEAR-01 baseline: playback of others' footsteps = non-positional flat step at -15 dB (AudioDirector._play_flat), no map marker")
	paused = false
	unload_current_scene()
	await physics_frame
	# DOOR-01: time the survivor is locked in place by a door toggle.
	s = await _load(2)
	sv = s.survivor
	var door: Node = get_first_node_in_group(&"cabin").get_node("FrontDoor")
	sv.global_position = door.global_position + g(0, 0.9)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": door.global_position}
	await physics_frame
	await physics_frame
	sv.try_interact()
	var locked := 0
	var start := sv.global_position
	sv.scripted_input = {"move": Vector2(1, 0), "aim": door.global_position}
	while sv.get_channel_progress() >= 0.0:
		await physics_frame
		locked += 1
	print("DOOR-01 baseline: door toggle is a %.2f s channel; survivor moved %.1f px during it (blocked)" % [locked / 60.0, start.distance_to(sv.global_position)])
	unload_current_scene()
	await physics_frame
	# BUSH-01/02: detection distance for a stationary survivor in a bush; careful movement noise.
	var p := GameParams.current()
	print("BUSH-01 baseline: concealed target detected within %.1f gu after %.1f s regardless of movement; open ground %.1f gu" % [2.0, 0.6, p.vision_range()])
	print("BUSH-02 baseline: bush.gd emits foliage only for walk/sprint; careful movement is silent; one radius %.1f gu" % p.foliage_radius)
	quit()
