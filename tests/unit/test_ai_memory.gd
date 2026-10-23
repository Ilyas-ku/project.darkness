extends TestCase
## Unit: after LOS loss, AIMemory does not update last_seen_position from the
## player's actual movement; sound anti-exploit cooldown.


func test_last_seen_not_updated_without_observation() -> void:
	var m := AIMemory.new()
	m.ingest_vision(Observation.ObservedVictim.new(Vector2(100, 100), 1.0), 1.0)
	check(m.has_visual, "visible after observation")
	# The victim keeps moving behind a wall: the sensor delivers no observation.
	for i in 30:
		var true_player_pos := Vector2(100 + i * 10, 100)
		m.ingest_vision(null, 1.0 + i * 0.05)
		check(m.last_seen_position != true_player_pos or i == 0, "memory does not track hidden movement")
	check(not m.has_visual, "no visual after LOS loss")
	check_eq(m.last_seen_position, Vector2(100, 100), "last seen stays at last observation")
	check_eq(m.last_seen_time, 1.0, "timestamp stays")


func test_sound_cooldown_same_area() -> void:
	var m := AIMemory.new()
	var a := Observation.HeardObservation.new()
	a.kind = &"impact"
	a.timestamp = 1.0
	a.approximate_region = {"center": Vector2(200, 200), "radius": 64.0}
	check(m.ingest_heard(a, 1.0), "first impact accepted")
	m.take_pending_sound()
	var b := Observation.HeardObservation.new()
	b.kind = &"impact"
	b.timestamp = 2.0
	b.approximate_region = {"center": Vector2(230, 210), "radius": 64.0}
	check(not m.ingest_heard(b, 2.0), "repeat in same area within 4 s ignored")
	check(not m.has_pending_sound(), "nothing pending")
	check(m.ingest_heard(b, 5.5), "accepted after cooldown")


func test_footsteps_do_not_create_target() -> void:
	var m := AIMemory.new()
	var f := Observation.HeardObservation.new()
	f.kind = &"footsteps"
	f.is_nearby_presence = true
	m.ingest_heard(f, 3.0)
	check(not m.has_pending_sound(), "footsteps never become a navigation target")
	check(m.footsteps_fresh(3.2, 0.5), "presence remembered")
	check(not m.has_last_seen, "no position from footsteps")
