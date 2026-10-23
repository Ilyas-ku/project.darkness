extends TestCase
## Unit: fog memory never renders dynamic objects in EXPLORED cells; state transitions.


func test_dynamic_not_renderable_when_explored() -> void:
	var E := ExplorationMemory.CellState
	check(not ExplorationMemory.is_renderable(true, E.EXPLORED), "dynamic hidden in EXPLORED")
	check(not ExplorationMemory.is_renderable(true, E.UNEXPLORED), "dynamic hidden in UNEXPLORED")
	check(ExplorationMemory.is_renderable(true, E.VISIBLE), "dynamic shown in VISIBLE")
	check(ExplorationMemory.is_renderable(false, E.EXPLORED), "static shown in EXPLORED")
	check(not ExplorationMemory.is_renderable(false, E.UNEXPLORED), "static hidden in UNEXPLORED")


func test_visible_becomes_explored() -> void:
	var m := ExplorationMemory.new(Vector2(320, 320), 16.0)
	var poly := PackedVector2Array([Vector2(10, 10), Vector2(100, 10), Vector2(100, 100), Vector2(10, 100)])
	check(m.update_from_polygon(poly), "first update applied")
	check_eq(m.get_state_at(Vector2(50, 50)), ExplorationMemory.CellState.VISIBLE, "inside view visible")
	check_eq(m.get_state_at(Vector2(200, 200)), ExplorationMemory.CellState.UNEXPLORED, "outside unexplored")
	check(not m.update_from_polygon(poly), "unchanged geometry -> no update")
	var poly2 := PackedVector2Array([Vector2(150, 150), Vector2(250, 150), Vector2(250, 250), Vector2(150, 250)])
	m.update_from_polygon(poly2)
	check_eq(m.get_state_at(Vector2(50, 50)), ExplorationMemory.CellState.EXPLORED, "old view explored")
	check_eq(m.get_state_at(Vector2(200, 200)), ExplorationMemory.CellState.VISIBLE, "new view visible")
