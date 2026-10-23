extends TestCase
## Smoke: main scene loads, 30 s preparation without a killer, exit, caught, restart.

const MAIN := "res://scenes/main/forest_test_01.tscn"


func _session() -> GameSession:
	return tree.current_scene as GameSession


func before_each() -> void:
	GameParams.current().rng_seed = 7
	check_eq(tree.change_scene_to_file(MAIN), OK, "main scene loads (AC-01)")
	await physics_frames(3)


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


func test_prepare_timer_and_spawn() -> void:
	var s := _session()
	check(s != null, "session root present")
	check_eq(s.phase, GameSession.Phase.PREPARE, "starts in PREPARE")
	check(tree.get_nodes_in_group(&"killer").is_empty(), "killer absent at start (AC-15)")
	await seconds(29.0)
	check(tree.get_nodes_in_group(&"killer").is_empty(), "killer still absent at 29 s")
	check(not s.exit_zone.active, "exit inactive during preparation")
	await seconds(1.5)
	check_eq(tree.get_nodes_in_group(&"killer").size(), 1, "killer spawned after 30 s")
	check_eq(s.phase, GameSession.Phase.ACTIVE, "ACTIVE")
	var k: Node2D = s.killer
	check(k.global_position.distance_to(s.survivor.global_position) >= GameParams.gu(10.0) - 0.1, "spawn >= 10 gu from survivor")


func test_exit_escaped_and_restart() -> void:
	var s := _session()
	s.spawn_killer()
	s.killer.global_position = Vector2(GameParams.gu(1), GameParams.gu(23))
	await physics_frames(2)
	s.survivor.global_position = s.exit_zone.global_position
	await physics_frames(3)
	check_eq(s.phase, GameSession.Phase.ESCAPED, "ESCAPED on exit (AC-16)")
	check(tree.paused, "game paused on result")
	check_eq(s.hud.get_result_title(), "ESCAPED", "result screen shows ESCAPED")
	s.restart()
	await physics_frames(3)
	var s2 := _session()
	check(s2 != null and s2 != s, "scene reloaded")
	check_eq(s2.phase, GameSession.Phase.PREPARE, "restart resets to PREPARE")
	check(tree.get_nodes_in_group(&"killer").is_empty(), "restart removes killer")


func test_caught() -> void:
	var s := _session()
	s.spawn_killer()
	var sv := s.survivor
	s.killer.global_position = sv.global_position + Vector2(GameParams.gu(0.5), 0)
	s.killer.facing = Vector2.LEFT
	sv.scripted_input = {"move": Vector2.ZERO, "aim": sv.global_position + Vector2.RIGHT}
	await seconds(1.0)
	check_eq(s.phase, GameSession.Phase.CAUGHT, "CAUGHT after MVP attack (AC-17)")
	check_eq(s.hud.get_result_title(), "CAUGHT", "result screen shows CAUGHT")


func test_exit_inactive_before_killer() -> void:
	var s := _session()
	s.survivor.global_position = s.exit_zone.global_position
	await physics_frames(5)
	check_eq(s.phase, GameSession.Phase.PREPARE, "no win during preparation")
