extends SceneTree
## Captures the four required screenshots of the running game (spec 12.4):
##   1 forest + clearing with characters, 2 house interior, 3 current view +
##   darkened memory, 4 exit opening with progress during a chase.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 1152x648 -s res://tools/screenshot_tour.gd -- --out=docs/screenshots --label=after

var out_dir := "user://shots"
var label := "shot"
var s: GameSession
var sv: SurvivorController


func _initialize() -> void:
	_run.call_deferred()


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func _snap(name: String) -> void:
	for i in 3:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("%s_%s.png" % [label, name]))
	print("saved ", name)


func _walk(dir: Vector2, t: float, aim_dir: Vector2 = Vector2.ZERO, sprint := false) -> void:
	for i in int(t * 60):
		var a := aim_dir if aim_dir != Vector2.ZERO else dir
		sv.scripted_input = {"move": dir, "aim": sv.global_position + a * 100.0, "sprint": sprint, "interact_held": true}
		await physics_frame
	sv.scripted_input = {"move": Vector2.ZERO, "aim": sv.global_position + (aim_dir if aim_dir != Vector2.ZERO else dir) * 100.0, "interact_held": true}


func _look(aim: Vector2, frames: int = 4) -> void:
	sv.scripted_input = {"move": Vector2.ZERO, "aim": aim, "interact_held": true}
	for i in frames:
		await physics_frame


func _load() -> void:
	GameParams.set_current(GameParams.new())
	GameParams.current().rng_seed = 3
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	await physics_frame
	await physics_frame
	s = current_scene
	sv = s.survivor


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--label="):
			label = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _load()
	var house := g(3, 2)
	var cabin: Node = get_first_node_in_group(&"cabin")
	var inner: Node = cabin.get_node_or_null("InnerDoor")
	var front: Node = cabin.get_node_or_null("FrontDoor")
	if front == null:
		front = get_nodes_in_group(&"door")[0]
	# 2: house interior (explore the living room first, then look into the bedroom)
	front.set_open(true, sv)
	if inner != null:
		inner.set_open(true, sv)
	sv.global_position = house + g(6.2, 4.6)
	for aim in [g(10, 3), g(10.5, 6.5), g(8, 2.5), g(5, 5)]:
		await _look(aim, 6)
	sv.global_position = house + g(4.7, 2.9)
	await _look(house + g(0.5, 2.9), 6)
	await _look(house + g(1, 0.5), 6)
	await _look(house + g(1.5, 3.2), 8)
	await _snap("2_house_interior")
	# 3: current view + darkened memory: walk out and around the house, look away
	sv.global_position = g(9.2, 9.4)
	await _walk(Vector2.LEFT, 1.4)
	await _walk(Vector2.DOWN, 1.0)
	await _walk(Vector2.RIGHT, 1.6, Vector2(1, 0.4))
	await _snap("3_view_and_memory")
	# 1: forest + clearing with both characters
	s.prepare_left = 0.05
	await _walk(Vector2.ZERO, 0.1, Vector2.RIGHT)
	sv.global_position = g(13.6, 13.2)
	s.killer.brain.set_physics_process(false)
	s.killer.global_position = g(17.6, 12.6)
	s.killer.facing = Vector2.LEFT
	await _look(g(18, 13), 2)
	await _walk(Vector2(1, 0.2), 0.25, Vector2(1, -0.1))
	await _snap("1_forest_clearing")
	# 4: exit opening during a chase
	var gate: Node2D = s.get_node_or_null("World/ExitGate")
	if gate == null:
		print("no exit gate in this build; skipping shot 4")
		quit()
		return
	sv.global_position = gate.get_interact_position() + g(-0.3, 0)
	s.killer.global_position = g(24.0, 17.6)
	s.killer.facing = Vector2(1, 0.4).normalized()
	await _look(gate.global_position, 2)
	sv.try_interact()
	for i in 170:
		await physics_frame
	# keep holding E while looking back at the approaching killer
	s.killer.global_position = g(26.6, 18.2)
	s.killer.facing = Vector2(1, 0.35).normalized()
	s.killer.visual.telegraph = false
	sv.scripted_input = {"move": Vector2.ZERO, "aim": s.killer.global_position, "interact_held": true}
	for i in 4:
		await physics_frame
	await _snap("4_exit_progress_chase")
	quit()
