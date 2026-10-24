extends TestCase
## Acceptance checks on the real ForestTest_01 scene (AC-08, AC-09, AC-11..AC-14, AC-18).

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	GameParams.current().rng_seed = 5
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func _still(pos: Vector2, aim: Vector2) -> void:
	s.survivor.global_position = pos
	s.survivor.scripted_input = {"move": Vector2.ZERO, "aim": aim}


func _freeze_killer_brain() -> void:
	s.killer.brain.set_physics_process(false)


func test_locker_hides_and_peek_exposes() -> void:
	s.spawn_killer()
	_freeze_killer_brain()
	var locker: Node = tree.get_nodes_in_group(&"locker")[0]
	var sv := s.survivor
	_still(locker.get_interact_position() + Vector2(0, 10), locker.global_position)
	await physics_frames(2)
	check(sv.try_interact(), "can start entering the locker")
	await seconds(0.8)
	check(sv.current_locker == locker, "survivor inside the locker")
	var k := s.killer
	k.global_position = locker.global_position + Vector2(0, GameParams.gu(2.5))
	k.facing = Vector2.UP
	await physics_frames(2)
	check(k.vision.scan_group(&"survivor_perceivable", 0.016) == null, "closed locker: VisionSensor does not see the survivor (AC-11)")
	sv.scripted_input = {"move": Vector2.ZERO, "peek": true}
	await seconds(0.4)
	check(locker.is_peeking(), "peeking after 0.25 s")
	check(k.vision.scan_group(&"survivor_perceivable", 0.016) != null, "peeking survivor is detectable by LOS (AC-12)")


func test_door_change_unseen_is_not_shown() -> void:
	var door: Node = tree.get_first_node_in_group(&"cabin").get_node("FrontDoor")
	_still(g(20, 18), g(25, 18))   # far away, looking away
	await physics_frames(3)
	check(not door.is_open() and not door.displayed_open, "door closed initially")
	door.set_open(true, null)
	await physics_frames(5)
	check(door.is_open(), "door physically open")
	check(not door.displayed_open, "unseen door still drawn closed (AC-14)")
	_still(door.global_position + g(0, 2.0), door.global_position)
	await physics_frames(3)
	check(door.displayed_open, "door drawn open once seen")


func test_stone_out_of_view_not_revealed() -> void:
	var sv := s.survivor
	_still(g(15, 13), g(18, 13))
	await physics_frames(3)
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[0]
	stone.interact(sv)
	check(sv.inventory.count() == 1, "stone picked up")
	sv.try_throw(g(9, 13))   # behind the survivor, outside the view sector
	await seconds(1.6)
	check(stone.state == Throwable.State.RESTING_PICKABLE, "stone came to rest")
	check(not stone.visible, "landing point outside view is not revealed (AC-08)")


func test_explored_area_hides_dynamic_objects() -> void:
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[1]   # (15.5, 12)
	_still(g(13.5, 12), g(15.5, 12))
	await physics_frames(6)
	check(stone.visible, "stone visible in view")
	_still(g(13.5, 12), g(10, 12))   # turn away: area becomes EXPLORED
	await physics_frames(6)
	check_eq(s.fog.memory.get_state_at(stone.global_position), ExplorationMemory.CellState.EXPLORED, "area explored")
	check(not stone.visible, "dynamic object hidden in EXPLORED (AC-13)")


func test_debug_toggle() -> void:
	check(not s.debug_overlay.visible, "debug hidden by default")
	s.set_debug(true)
	check(s.debug_overlay.visible, "F3 shows debug (AC-18)")
	s.set_debug(false)
	check(not s.debug_overlay.visible, "F3 hides debug")


func test_tree_and_stone_decoy() -> void:
	# Success-criterion scenario: seen -> hide behind a trunk -> throw a stone -> killer investigates the stone.
	s.spawn_killer()
	var sv := s.survivor
	var k := s.killer
	k.global_position = g(19, 12)
	k.facing = Vector2.RIGHT
	_still(g(21, 12), g(25, 12))
	await physics_frames(3)
	check_eq(k.brain.state_name(), "CHASE", "killer sees the survivor")
	_still(g(24.2, 12), g(24.2, 17))   # trunk at (22.5, 12) breaks LOS
	await physics_frames(2)
	check(k.brain.state_name() == "GO_TO_LAST_SEEN" or k.brain.state_name() == "LOCAL_SEARCH", "LOS broken by the trunk (AC-05)")
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[0]
	stone.interact(sv)
	sv.try_throw(g(24.2, 17))
	var investigated := false
	for i in 60:
		await physics_frames(1)
		if stone.state != Throwable.State.FLYING and stone.state != Throwable.State.HELD:
			await physics_frames(1)
			investigated = k.brain.state_name() == "INVESTIGATE_SOUND"
			break
	check(investigated, "impact pulls the killer to INVESTIGATE_SOUND (AC-07), got %s" % k.brain.state_name())
	var reg: Variant = k.brain.investigate_region
	check(reg != null and reg.center.distance_to(g(24.2, 17)) <= reg.radius, "region around the stone")
	check(reg != null and reg.center.distance_to(sv.global_position) > GameParams.gu(3.0), "region not at the hidden survivor")


func test_stone_into_shed_impacts_at_contact() -> void:
	var sv := s.survivor
	_still(g(15, 7.5), g(19, 7.5))   # shed occupies x 17..21, y 6..9
	await physics_frames(2)
	var events: Array = []
	s.get_node("SoundEventBus").sound_emitted.connect(func(ev): if ev.kind == &"impact": events.append(ev))
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[0]
	stone.interact(sv)
	sv.try_throw(g(19, 7.5))
	await seconds(0.6)
	check_eq(events.size(), 1, "one impact event")
	if events.size() == 1:
		var p: Vector2 = events[0].source_world_position
		check(absf(p.x - GameParams.gu(17)) < 2.0, "impact at the shed wall contact point (AC-07), x=%.1f" % (p.x / GameParams.PX_PER_GU))
