extends TestCase
## Unit: FOV angle function includes targets inside the sector and excludes others.


func test_inside_sector() -> void:
	var r := GameParams.gu(5.0)
	check(VisionSensor.is_in_sector(Vector2.ZERO, Vector2.RIGHT, 110.0, r, Vector2(100, 0)), "straight ahead")
	check(VisionSensor.is_in_sector(Vector2.ZERO, Vector2.RIGHT, 110.0, r, Vector2.from_angle(deg_to_rad(54.0)) * 100.0), "54 deg inside 110 sector")
	check(VisionSensor.is_in_sector(Vector2.ZERO, Vector2.RIGHT, 110.0, r, Vector2.from_angle(deg_to_rad(-54.0)) * 100.0), "-54 deg inside")


func test_outside_sector() -> void:
	var r := GameParams.gu(5.0)
	check(not VisionSensor.is_in_sector(Vector2.ZERO, Vector2.RIGHT, 110.0, r, Vector2.from_angle(deg_to_rad(56.0)) * 100.0), "56 deg outside")
	check(not VisionSensor.is_in_sector(Vector2.ZERO, Vector2.RIGHT, 110.0, r, Vector2(-100, 0)), "behind")
	check(not VisionSensor.is_in_sector(Vector2.ZERO, Vector2.RIGHT, 110.0, r, Vector2(r + 1.0, 0)), "beyond range")


func test_range_modifier() -> void:
	var s := VisionSensor.new()
	s.base_range_gu = 5.0
	s.add_range_modifier(&"police", 1.1)
	check(is_equal_approx(s.effective_range_px(), GameParams.gu(5.5)), "+10% modifier")
	s.remove_range_modifier(&"police")
	check(is_equal_approx(s.effective_range_px(), GameParams.gu(5.0)), "modifier removed")
	s.free()
