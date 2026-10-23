extends TestCase
## T10, T11 (exit hold), T12 (stone reuse x10), bottle.

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	GameParams.current().rng_seed = 11
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func _at_gate(held: bool) -> void:
	var sv := s.survivor
	sv.global_position = s.exit_gate.get_interact_position() + Vector2(-GameParams.gu(0.3), 0)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": s.exit_gate.global_position, "interact_held": held}


func test_t10_progress_visible_and_win_only_after_full_hold() -> void:
	_at_gate(true)
	await physics_frames(2)
	check(s.survivor.try_interact(), "hold started")
	await seconds(2.5)
	var pr: float = s.survivor.get_channel_progress()
	check(pr > 0.45 and pr < 0.55, "T10: progress ~50%% at 2.5 s (%.2f)" % pr)
	check(not s.is_finished(), "T10: no win at 2.5 s")
	var before := s.survivor.global_position
	s.survivor.scripted_input = {"move": Vector2(-1, 0), "aim": s.exit_gate.global_position, "interact_held": true}
	await seconds(0.5)
	check(s.survivor.global_position.distance_to(before) < 0.5, "T10: cannot move while opening")
	await seconds(2.3)
	check_eq(s.phase, GameSession.Phase.ESCAPED, "T10: win after the full 5 s")


func test_t11_release_resets_progress() -> void:
	_at_gate(true)
	await physics_frames(2)
	s.survivor.try_interact()
	await seconds(4.0)
	s.survivor.scripted_input.interact_held = false
	await physics_frames(2)
	check_eq(s.survivor.get_channel_progress(), -1.0, "T11: progress reset after release at 4 s")
	await seconds(2.0)
	check(not s.is_finished(), "T11: no win after release")
	s.survivor.scripted_input.interact_held = true
	s.survivor.try_interact()
	await seconds(1.0)
	var pr: float = s.survivor.get_channel_progress()
	check(pr < 0.25, "T11: new attempt starts from zero (%.2f)" % pr)


func test_t11_hit_resets_progress() -> void:
	s.spawn_killer()
	s.killer.brain.set_physics_process(false)
	_at_gate(true)
	await physics_frames(2)
	s.survivor.try_interact()
	await seconds(4.0)
	s.survivor.health.take_hit(s.killer)
	await physics_frames(2)
	check_eq(s.survivor.get_channel_progress(), -1.0, "T11: hit at 4 s cancels the exit")
	await seconds(2.0)
	check(not s.is_finished(), "T11: no win after hit")


func test_t12_stone_thrown_and_picked_10_times() -> void:
	var sv := s.survivor
	sv.global_position = g(15, 13)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(17, 13)}
	var stones_before := tree.get_nodes_in_group(&"stone").size()
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[1]
	stone.global_position = sv.global_position + g(0.5, 0)
	stone.state = Throwable.State.RESTING_PICKABLE
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for i in 10:
		await physics_frames(1)
		check(stone.can_interact(sv), "cycle %d: stone pickable" % i)
		stone.interact(sv)
		check_eq(sv.inventory.count(), 1, "cycle %d: in inventory" % i)
		check(not stone.can_interact(sv) or not sv.inventory.has_space(), "cycle %d: not pickable while held" % i)
		var d: Vector2 = dirs[i % 4]
		check(sv.try_throw(sv.global_position + d * GameParams.gu(3.0)), "cycle %d: thrown" % i)
		check_eq(sv.inventory.count(), 0, "cycle %d: slot freed" % i)
		check(not stone.can_interact(sv), "cycle %d: not pickable in flight" % i)
		await seconds(0.9)
		check_eq(stone.state, Throwable.State.RESTING_PICKABLE, "cycle %d: stone rests" % i)
		sv.global_position = stone.global_position - d * GameParams.gu(0.6)
		await physics_frames(1)
	check_eq(stone.throws, 10, "T12: 10 throws of the same object")
	check_eq(tree.get_nodes_in_group(&"stone").size(), stones_before, "T12: no duplicates or losses")
	check(is_instance_valid(stone), "T12: stone still exists")


func test_stone_hits_wall_once_and_stays_in_bounds() -> void:
	var sv := s.survivor
	sv.global_position = g(28.5, 12)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(30, 12)}
	var events: Array = []
	s.get_node("SoundEventBus").sound_emitted.connect(func(ev): if ev.kind == &"impact": events.append(ev))
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[0]
	stone.interact(sv)
	sv.try_throw(g(40, 12))   # towards the map border
	await seconds(1.5)
	check_eq(events.size(), 1, "one impulse per throw")
	var m := GameParams.current().map_size_px()
	check(Rect2(Vector2.ZERO, m).has_point(stone.global_position), "stone stays inside the map")
	check(stone.is_pickable(), "stone pickable after hitting the border")
