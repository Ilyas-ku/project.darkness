extends SceneTree
## Dev tool: scripted walk through the main scene that saves screenshots.
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/screenshot_tour.gd -- --out=/tmp/shots

var out_dir := "user://shots"


func _initialize() -> void:
	_run.call_deferred()


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _walk(sv: Node, dir: Vector2, t: float, aim_dir: Vector2 = Vector2.ZERO) -> void:
	var frames := int(t * 60)
	for i in frames:
		var a := aim_dir if aim_dir != Vector2.ZERO else dir
		sv.scripted_input = {"move": dir, "aim": sv.global_position + a * 100.0}
		await physics_frame
	sv.scripted_input = {"move": Vector2.ZERO, "aim": sv.global_position + (aim_dir if aim_dir != Vector2.ZERO else dir) * 100.0}


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameParams.current().rng_seed = 3
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	await physics_frame
	await physics_frame
	var s: GameSession = current_scene
	var sv: SurvivorController = s.survivor
	sv.global_position = Vector2(7.2, 10.0) * 32
	await _walk(sv, Vector2.UP, 0.5)
	await _snap("01_start_prepare")
	await _walk(sv, Vector2.UP, 0.4)
	await _walk(sv, Vector2.LEFT, 0.01)
	sv.global_position = Vector2(8.2, 9.0) * 32
	await _walk(sv, Vector2.UP, 0.2)
	await _snap("02_facing_door")
	sv.try_interact()
	await _walk(sv, Vector2.ZERO, 0.5, Vector2.UP)
	await _walk(sv, Vector2.UP, 1.2)
	await _walk(sv, Vector2.LEFT, 1.3)
	await _snap("03_inside_house")
	await _walk(sv, Vector2.DOWN, 0.6, Vector2.DOWN)
	await _walk(sv, Vector2.RIGHT, 2.0)
	await _walk(sv, Vector2.DOWN, 1.5)
	await _walk(sv, Vector2.RIGHT, 2.5)
	await _snap("04_explored_memory")
	s.prepare_left = 0.05
	await _walk(sv, Vector2.ZERO, 0.2, Vector2.RIGHT)
	sv.global_position = Vector2(14.0, 13.0) * 32
	s.killer.global_position = Vector2(17.5, 13.3) * 32
	s.killer.facing = Vector2.UP
	await _walk(sv, Vector2.ZERO, 0.1, Vector2.RIGHT)
	await _snap("05_killer_visible")
	s.set_debug(true)
	await _walk(sv, Vector2.ZERO, 0.05, Vector2.RIGHT)
	await _snap("06_debug_overlay")
	s.set_debug(false)
	await _walk(sv, Vector2.ZERO, 0.05, Vector2.LEFT)
	await _snap("07_killer_behind_not_drawn")
	sv.global_position = Vector2(3.4, 3.8) * 32
	s.killer.global_position = Vector2(25, 20) * 32
	await _walk(sv, Vector2.ZERO, 0.1, Vector2.UP)
	sv.try_interact()
	await _walk(sv, Vector2.ZERO, 0.8, Vector2.UP)
	print("in locker: ", sv.current_locker != null)
	await _snap("08_in_locker")
	sv.scripted_input = {"move": Vector2.ZERO, "peek": true}
	for i in 30:
		await physics_frame
	print("peeking: ", sv.current_locker.is_peeking())
	await _snap("09_peek")
	quit()
