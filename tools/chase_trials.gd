extends SceneTree
## CHASE-01 / T35: ten reproducible escape attempts after being spotted.
## The killer AI is the real one (unchanged speeds 4.6 / 5.2); the survivor is a
## scripted bot following navigation paths and doing valid manoeuvres only
## (sprint, doors, window, bushes, trees, locker). Outcome per trial:
##   CAUGHT   - downed or killed;
##   ESCAPED  - alive and the killer has had no sight of the survivor for 10 s
##              and is no longer chasing / attacking;
##   UNRESOLVED - neither within the time limit.
##   godot --headless --path . --fixed-fps 60 -s res://tools/chase_trials.gd

const LIMIT := 45.0

var s: GameSession
var sv: SurvivorController
var log_lines: Array[String] = []
var verbose := false
var only := -1


func _initialize() -> void:
	_run.call_deferred()


func g(v: Vector2) -> Vector2:
	return v * GameParams.PX_PER_GU


func scenarios() -> Array:
	var W := Vector2(3.6, 5.0)
	return [
		{"name": "01 open: sprint straight east", "sv": Vector2(15, 13), "k": Vector2(12, 13),
			"steps": [{"go": Vector2(28, 13), "sprint": true}, {"go": Vector2(28, 3), "sprint": true}]},
		{"name": "02 open: zigzag on the clearing", "sv": Vector2(15, 13), "k": Vector2(12, 13),
			"steps": [{"go": Vector2(18, 10.5), "sprint": true}, {"go": Vector2(17, 15.5), "sprint": true}, {"go": Vector2(20, 11)}, {"go": Vector2(18, 15)}]},
		{"name": "03 trees: loop the east tree group, then sneak north", "sv": Vector2(19.5, 13.8), "k": Vector2(16.5, 13.8),
			"steps": [{"go": Vector2(24.0, 13.0), "sprint": true}, {"go": Vector2(26.8, 12.0), "sprint": true}, {"go": Vector2(26.6, 9.0), "sprint": true},
				{"go": Vector2(24.5, 5.8), "careful": true}, {"go": Vector2(20.0, 3.0), "careful": true}]},
		{"name": "04 trees then bush: break LOS behind trunks, freeze in a bush", "sv": Vector2(18.0, 16.0), "k": Vector2(15.0, 15.0),
			"steps": [{"go": Vector2(20.6, 17.6), "sprint": true}, {"go": Vector2(23.0, 18.4), "sprint": true}, {"go": Vector2(24.5, 19.0), "careful": true}, {"wait": 30.0}]},
		{"name": "05 bush: run into a bush and stand still", "sv": Vector2(17.0, 12.5), "k": Vector2(14.0, 12.5),
			"steps": [{"go": Vector2(19.5, 12.5), "sprint": true}, {"wait": 40.0}]},
		{"name": "06 bush: run through a bush without stopping", "sv": Vector2(17.0, 12.5), "k": Vector2(14.0, 12.5),
			"steps": [{"go": Vector2(19.5, 12.5), "sprint": true}, {"go": Vector2(22.0, 8.5), "sprint": true}, {"go": Vector2(26.0, 5.0)}]},
		{"name": "07 house: door, close it behind, window, sprint to a far bush", "sv": Vector2(9.2, 10.4), "k": Vector2(13.2, 11.2), "open": ["InnerDoor"],
			"steps": [{"go": Vector2(9.2, 8.9), "sprint": true}, {"press": "FrontDoor"}, {"go": Vector2(9.2, 6.6), "sprint": true}, {"press": "FrontDoor"},
				{"go": Vector2(7.6, 5.0), "sprint": true}, {"go": W, "sprint": true}, {"vault": true}, {"go": Vector2(2.4, 10.0), "sprint": true},
				{"go": Vector2(6.5, 15.0), "sprint": true}, {"wait": 30.0}]},
		{"name": "08 house: door, hide in the locker", "sv": Vector2(9.2, 10.4), "k": Vector2(13.2, 11.2), "open": ["InnerDoor"],
			"steps": [{"go": Vector2(9.2, 8.9), "sprint": true}, {"press": "FrontDoor"}, {"go": Vector2(9.2, 6.6), "sprint": true}, {"press": "FrontDoor"},
				{"go": Vector2(7.6, 5.0), "sprint": true}, {"go": Vector2(4.2, 3.6), "sprint": true}, {"locker": true}, {"wait": 40.0}]},
		{"name": "09 window first: vault out, sprint through the west woods", "sv": Vector2(6.0, 5.0), "k": Vector2(9.0, 6.4), "open": ["InnerDoor", "FrontDoor"],
			"steps": [{"go": W, "sprint": true}, {"vault": true}, {"go": Vector2(2.0, 11.0), "sprint": true}, {"go": Vector2(3.6, 19.5), "sprint": true},
				{"go": Vector2(8.0, 22.6)}, {"go": Vector2(12.0, 19.5), "careful": true}]},
		{"name": "10 house corners: circle the house outside", "sv": Vector2(11.8, 9.0), "k": Vector2(14.5, 10.5),
			"steps": [{"go": Vector2(11.8, 1.2), "sprint": true}, {"go": Vector2(2.2, 1.2), "sprint": true}, {"go": Vector2(2.2, 9.0), "sprint": true}, {"go": Vector2(6.5, 15.0)}, {"wait": 30.0}]},
	]


func _load(seed: int) -> void:
	GameParams.set_current(GameParams.new())
	GameParams.current().rng_seed = seed
	change_scene_to_file("res://scenes/main/forest_test_01.tscn")
	for i in 3:
		await physics_frame
	s = current_scene
	sv = s.survivor
	var map: RID = s.nav_region.get_navigation_map()
	for i in 120:
		if NavigationServer2D.map_get_iteration_id(map) > 0:
			break
		await physics_frame
	for i in 5:
		await physics_frame


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--verbose":
			verbose = true
		elif a.begins_with("--only="):
			only = int(a.get_slice("=", 1))
	var results := {"CAUGHT": 0, "ESCAPED": 0, "UNRESOLVED": 0}
	var i := 0
	for sc in scenarios():
		i += 1
		if only > 0 and i != only:
			continue
		await _load(100 + i)
		var r := await _trial(sc)
		results[r.outcome] += 1
		var line := "%s -> %s at %.1fs | %s" % [sc.name, r.outcome, r.t, r.reason]
		log_lines.append(line)
		print(line)
		for l in r.log:
			print("      ", l)
		paused = false
		unload_current_scene()
		await physics_frame
	print("SUMMARY %s" % str(results))
	quit()


func _trial(sc: Dictionary) -> Dictionary:
	var cabin: Node = get_first_node_in_group(&"cabin")
	for d in sc.get("open", []):
		cabin.get_node(d).set_open(true, null)
	sv.global_position = g(sc.sv)
	s.spawn_killer_at(g(sc.k), (g(sc.sv) - g(sc.k)).normalized())
	var brain: KillerBrain = s.killer.brain
	var t := 0.0
	var last_seen_t := 0.0
	var los_breaks := 0
	var prev_state := ""
	var hits: Array[String] = []
	var clock := [0.0]   # captured by reference in the lambda
	sv.health.state_changed.connect(func(_o, n): hits.append("%s@%.1fs" % [HealthComponent.HState.keys()[n], clock[0]]))
	var steps: Array = sc.steps
	var idx := 0
	var path := PackedVector2Array()
	var pi := 0
	var wait_left := -1.0
	var map: RID = s.nav_region.get_navigation_map()
	while t < LIMIT:
		var inp := {"move": Vector2.ZERO, "aim": sv.global_position + sv.facing * 50.0}
		if idx < steps.size() and not sv.health.is_down():
			var st: Dictionary = steps[idx]
			if st.has("go"):
				var goal := g(st.go)
				if path.is_empty():
					path = NavigationServer2D.map_get_path(map, sv.global_position, goal, true)
					pi = 0
				while pi < path.size() and path[pi].distance_to(sv.global_position) < 6.0:
					pi += 1
				if pi >= path.size() or sv.global_position.distance_to(goal) < GameParams.gu(0.3):
					idx += 1
					path = PackedVector2Array()
				else:
					var dir := (path[pi] - sv.global_position).normalized()
					inp = {"move": dir, "aim": sv.global_position + dir * 50.0, "sprint": st.get("sprint", false), "careful": st.get("careful", false)}
			elif st.has("press"):
				var door: Node = cabin.get_node(st.press)
				door.interact(sv)
				idx += 1
			elif st.has("vault"):
				var win: Node2D = cabin.get_node("Window")
				inp = {"move": Vector2.ZERO, "aim": win.global_position, "interact_held": true}
				if sv.get_channel_target() == null:
					if sv.global_position.x < win.global_position.x - GameParams.gu(0.2):
						idx += 1   # outside: vault done
					elif sv.focus == win:
						sv.try_interact()
				# channel in progress: keep holding
			elif st.has("locker"):
				var locker: Node = cabin.get_node("Locker")
				if sv.current_locker != null:
					idx += 1
				elif sv.get_channel_target() == null:
					inp = {"move": Vector2.ZERO, "aim": locker.global_position, "interact_held": true}
					if sv.focus == locker:
						sv.try_interact()
			elif st.has("wait"):
				if wait_left < 0.0:
					wait_left = st.wait
				wait_left -= 1.0 / 60.0
				if wait_left <= 0.0:
					wait_left = -1.0
					idx += 1
		sv.scripted_input = inp
		await physics_frame
		t += 1.0 / 60.0
		clock[0] = t
		if verbose and int(t * 60) % 60 == 0:
			print("        t=%.0f step=%d sv=%s k=%s state=%s vis=%s ch=%s" % [t, idx, str((sv.global_position / 32).snapped(Vector2(0.1, 0.1))), str((s.killer.global_position / 32).snapped(Vector2(0.1, 0.1))), brain.display_state(), brain.memory.has_visual, sv.get_channel_target()])
		var bs: String = brain.state_name()
		if brain.memory.has_visual:
			last_seen_t = t
		if prev_state == "CHASE" and bs != "CHASE" and bs != "ATTACK" and bs != "FINISH":
			los_breaks += 1
		prev_state = bs
		if sv.health.is_down() or s.is_finished():
			return {"outcome": "CAUGHT", "t": t, "reason": "hits %s, LOS breaks %d, combat %s" % [hits, los_breaks, brain.combat_stats], "log": brain.transition_log.slice(-5)}
		if t - last_seen_t >= 10.0 and bs != "CHASE" and bs != "ATTACK" and bs != "FINISH":
			return {"outcome": "ESCAPED", "t": t, "reason": "no sight for 10 s, killer state %s, hits %s, LOS breaks %d" % [bs, hits, los_breaks], "log": brain.transition_log.slice(-5)}
	return {"outcome": "UNRESOLVED", "t": t, "reason": "killer state %s, hits %s, LOS breaks %d" % [brain.state_name(), hits, los_breaks], "log": brain.transition_log.slice(-5)}
