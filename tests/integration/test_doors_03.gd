extends TestCase
## Prototype 0.3 doors: T15-T17 (0.2 s, no hold, no stop, AI uses the same logic).

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession
var door: Node


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	GameParams.current().rng_seed = 61
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene
	await wait_navigation(s.nav_region)
	door = tree.get_first_node_in_group(&"cabin").get_node("FrontDoor")


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func test_t15_press_e_while_running_door_opens_without_stopping() -> void:
	var sv := s.survivor
	sv.global_position = door.global_position + g(0, 2.2)
	var opened_at := -1
	var positions: Array[Vector2] = []
	for i in 90:
		sv.scripted_input = {"move": Vector2(0, -1), "aim": door.global_position + g(0, -2), "sprint": true}
		await tree.physics_frame
		positions.append(sv.global_position)
		if opened_at < 0 and sv.focus == door and sv.global_position.distance_to(door.global_position) < GameParams.gu(1.1):
			check(sv.try_interact(), "E pressed while running")
			opened_at = i
	check(opened_at >= 0, "door was focused while running")
	check(door.is_open(), "T15: door opened")
	check_eq(sv.get_channel_progress(), -1.0, "T15: no hold/channel for a normal door")
	# the survivor kept moving through the frames right after the press
	var moved := positions[mini(opened_at + 12, positions.size() - 1)].distance_to(positions[opened_at])
	check(moved > GameParams.gu(0.6), "T15: kept running during the 0.2 s opening (%.1f px)" % moved)
	check(sv.global_position.y < door.global_position.y - GameParams.gu(0.3), "T15: ran through the doorway")


func test_t16_double_press_does_not_flicker() -> void:
	var sv := s.survivor
	sv.global_position = door.global_position + g(0, 0.9)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": door.global_position}
	await physics_frames(2)
	var toggles: Array = []
	door.toggled.connect(func(o): toggles.append(o))
	sv.try_interact()
	await physics_frames(3)
	sv.try_interact()   # auto-repeat / double tap within the debounce window
	await physics_frames(3)
	check_eq(toggles.size(), 1, "T16: one toggle for a double press")
	check(door.is_open(), "T16: stays open")
	await physics_frames(2)
	var shape: CollisionShape2D = door.get_child(0) as CollisionShape2D
	for c in door.get_children():
		if c is CollisionShape2D:
			shape = c
	check_eq(shape.disabled, true, "T16: collision matches the open state")
	await seconds(0.4)
	sv.try_interact()
	await physics_frames(3)
	check(not door.is_open(), "T16: a later press closes it")
	check_eq(shape.disabled, false, "T16: collision matches the closed state")


func test_t17_killer_opens_door_with_same_fast_logic() -> void:
	s.spawn_killer_at(g(9.2, 10.5), Vector2.UP)
	s.killer.brain.set_physics_process(false)
	s.survivor.global_position = g(25, 3)
	s.survivor.input_enabled = false
	check(not door.is_open(), "door closed")
	s.killer.move_to(g(9.2, 5.0))
	var still := 0.0
	var max_still := 0.0
	var prev: Vector2 = s.killer.global_position
	var inside := false
	for i in 4 * 60:
		await tree.physics_frame
		var d: float = prev.distance_to(s.killer.global_position)
		prev = s.killer.global_position
		still = still + 1.0 / 60.0 if d < 0.5 else 0.0
		max_still = maxf(max_still, still)
		if s.killer.global_position.y < g(0, 6.0).y:
			inside = true
			break
	check(door.is_open() and s.killer.door_opens >= 1, "T17: the killer opened the door itself")
	check(inside, "T17: and walked inside")
	check(max_still < 0.15, "T17: no long stop at the door (%.2f s)" % max_still)
