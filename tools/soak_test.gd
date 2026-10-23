extends SceneTree
## Dev tool: 10 simulated minutes of a random-walking bot (throws stones, uses
## doors/lockers when focused), restarting after every result. Any script error
## shows up in the output.
##   godot --headless --path . --fixed-fps 60 -s res://tools/soak_test.gd

const MINUTES := 10.0

var rng := RandomNumberGenerator.new()
var results := {"ESCAPED": 0, "CAUGHT": 0}
var states := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 99
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	await physics_frame
	await physics_frame
	var frames := int(MINUTES * 60.0 * 60.0)
	var dir := Vector2.RIGHT
	var f := 0
	while f < frames:
		var s: GameSession = current_scene
		if s == null:
			await physics_frame
			f += 1
			continue
		if s.is_finished():
			results[GameSession.Phase.keys()[s.phase]] += 1
			s.restart()
			await physics_frame
			await physics_frame
			f += 2
			continue
		if s.phase == GameSession.Phase.PREPARE and s.prepare_left > 3.0:
			s.prepare_left = 3.0
		var sv: SurvivorController = s.survivor
		if f % 90 == 0:
			dir = Vector2.from_angle(rng.randf() * TAU)
		var mode := rng.randi_range(0, 2)
		sv.scripted_input = {"move": dir, "aim": sv.global_position + dir * 100.0, "sprint": mode == 1, "careful": mode == 2, "peek": rng.randf() < 0.5}
		if f % 45 == 0:
			sv.try_interact()
		if f % 200 == 0:
			sv.try_throw(sv.global_position + dir * 150.0)
		if s.killer != null:
			var st: String = s.killer.brain.state_name()
			states[st] = states.get(st, 0) + 1
		await physics_frame
		f += 1
	print("soak done: results=", results, " fsm_frames=", states)
	quit()
