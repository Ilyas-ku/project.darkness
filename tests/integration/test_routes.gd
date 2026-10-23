extends TestCase
## T20: every base route is walkable without invisible walls or getting stuck;
## spec 3.1: at least three geometrically different house -> exit trajectories.
## T17: what happens in an explored but unseen room is not shown.

const MAIN := "res://scenes/main/forest_test_01.tscn"

var s: GameSession


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	GameParams.current().rng_seed = 31
	tree.change_scene_to_file(MAIN)
	await physics_frames(3)
	s = tree.current_scene
	for d in tree.get_nodes_in_group(&"door"):
		d.set_open(true, null)
	# navigation maps sync asynchronously: wait until the baked region is in the map
	var map: RID = s.nav_region.get_navigation_map()
	for i in 120:
		if NavigationServer2D.map_get_iteration_id(map) > 0:
			break
		await tree.physics_frame
	await physics_frames(10)


func after_each() -> void:
	tree.paused = false
	tree.unload_current_scene()
	await physics_frames(2)


## Walks the survivor through waypoints along navigation paths. Returns "" or a failure reason.
func _walk(points: Array) -> String:
	var sv := s.survivor
	var map: RID = s.nav_region.get_navigation_map()
	sv.global_position = points[0] * GameParams.PX_PER_GU
	for i in range(1, points.size()):
		var goal: Vector2 = points[i] * GameParams.PX_PER_GU
		var path := NavigationServer2D.map_get_path(map, sv.global_position, goal, true)
		for retry in 30:
			if not path.is_empty():
				break
			await tree.physics_frame
			path = NavigationServer2D.map_get_path(map, sv.global_position, goal, true)
		if path.is_empty():
			return "no path to %s" % str(points[i])
		var idx := 0
		var still := 0.0
		var t := 0.0
		while idx < path.size():
			var to := path[idx] - sv.global_position
			if to.length() < 6.0:
				idx += 1
				continue
			var before := sv.global_position
			sv.scripted_input = {"move": to.normalized(), "aim": path[idx]}
			await tree.physics_frame
			t += 1.0 / 60.0
			still = still + 1.0 / 60.0 if before.distance_to(sv.global_position) < 0.6 else 0.0
			if still > 1.0:
				return "stuck near %s on the way to %s" % [str((sv.global_position / GameParams.PX_PER_GU).snapped(Vector2(0.1, 0.1))), str(points[i])]
			if t > 30.0:
				return "timeout to %s" % str(points[i])
	sv.scripted_input = {"move": Vector2.ZERO}
	return ""


func test_t20_three_trajectories_house_to_exit() -> void:
	var gate: Vector2 = s.exit_gate.get_interact_position() / GameParams.PX_PER_GU + Vector2(-0.4, 0)
	var routes := {
		"north": [Vector2(9.2, 6.5), Vector2(9.2, 9.0), Vector2(13.5, 5.0), Vector2(23.0, 5.5), Vector2(27.0, 11.5), gate],
		"centre": [Vector2(9.2, 6.5), Vector2(9.2, 9.0), Vector2(15.0, 13.0), Vector2(22.0, 16.0), gate],
		"south": [Vector2(9.2, 6.5), Vector2(9.2, 9.0), Vector2(8.0, 18.0), Vector2(14.0, 22.5), Vector2(22.0, 23.0), gate],
	}
	for name in routes:
		var r := await _walk(routes[name])
		check(r == "", "T20/3.1: route %s walkable (%s)" % [name, r])


func test_t20_house_rooms_shed_and_window_side() -> void:
	var routes := {
		"living->bedroom": [Vector2(9.2, 6.5), Vector2(9.0, 5.4), Vector2(5.0, 5.0), Vector2(4.4, 3.8)],
		"bedroom->back (around)": [Vector2(5.0, 5.0), Vector2(9.2, 6.8), Vector2(9.2, 9.0), Vector2(2.0, 9.6), Vector2(1.5, 3.5)],
		"shed loop": [Vector2(15.0, 13.0), Vector2(16.2, 7.5), Vector2(19.0, 4.5), Vector2(22.5, 7.5), Vector2(19.0, 10.2)],
		"west woods": [Vector2(1.5, 3.5), Vector2(2.0, 12.0), Vector2(4.0, 22.0), Vector2(12.0, 19.0)],
	}
	for name in routes:
		var r := await _walk(routes[name])
		check(r == "", "T20: route %s walkable (%s)" % [name, r])


func test_t17_unseen_room_is_not_updated() -> void:
	var sv := s.survivor
	# explore the bedroom from the doorway, then leave the house
	sv.global_position = g(7.8, 5.0)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(4, 5)}
	await physics_frames(8)
	var bed_spot := g(4.6, 5.2)
	check_eq(s.fog.memory.get_state_at(bed_spot), ExplorationMemory.CellState.VISIBLE, "bedroom seen")
	sv.global_position = g(15, 13)
	sv.scripted_input = {"move": Vector2.ZERO, "aim": g(20, 13)}
	await physics_frames(8)
	check_eq(s.fog.memory.get_state_at(bed_spot), ExplorationMemory.CellState.EXPLORED, "bedroom now remembered")
	s.spawn_killer_at(bed_spot, Vector2.UP)
	s.killer.brain.set_physics_process(false)
	var stone: Throwable = tree.get_nodes_in_group(&"stone")[0]
	stone.global_position = bed_spot + g(0.5, 0)
	await physics_frames(5)
	check(not s.killer.visual.visible, "T17: killer in the remembered room is not drawn")
	check(not stone.visible, "T17: moved item in the remembered room is not drawn")
