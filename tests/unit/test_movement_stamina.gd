extends TestCase
## Unit: normalized diagonal speed and stamina rules.


func test_diagonal_not_faster() -> void:
	var p := GameParams.current()
	var straight := SurvivorController.compute_velocity(Vector2(1, 0), &"walk", p)
	var diag := SurvivorController.compute_velocity(Vector2(1, 1), &"walk", p)
	check(is_equal_approx(straight.length(), GameParams.gu(4.0)), "walk 4 gu/s")
	check(is_equal_approx(diag.length(), straight.length()), "diagonal same speed")
	check(is_equal_approx(SurvivorController.compute_velocity(Vector2(1, 1), &"sprint", p).length(), GameParams.gu(5.2)), "sprint 5.2")
	check(is_equal_approx(SurvivorController.compute_velocity(Vector2(0, -1), &"careful", p).length(), GameParams.gu(2.2)), "careful 2.2")


func test_stamina_drain_and_regen() -> void:
	var s := Stamina.new()
	for i in 250:   # 5 s of sprint at 50 Hz
		s.update(0.02, true)
	check(s.value <= 0.0001, "empty after 5 s sprint")
	check(not s.can_sprint(), "sprint locked at zero")
	for i in 100:   # 2 s delay
		s.update(0.02, false)
	check(s.value < 0.01, "no regen during 2 s delay")
	for i in 50:    # 1 s -> 10%
		s.update(0.02, false)
	check(absf(s.value - 0.1) < 0.02, "10%%/s regen (got %.3f)" % s.value)
	check(not s.can_sprint(), "still locked below 20%")
	for i in 55:
		s.update(0.02, false)
	check(s.can_sprint(), "sprint available again at 20%")
