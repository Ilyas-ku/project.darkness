class_name KillerBrain
extends Node
## Killer decision making (FSM). Data flow:
##   PhysicalWorld -> VisionSensor/HearingSensor -> sanitized observations -> AIMemory -> KillerBrain -> KillerMotor
## The brain never references the survivor node, a list of true victim positions
## or a locker's `occupied` flag. Static map knowledge it uses: areas of interest
## (with the house), patrol markers and hiding-spot places.
##
## Patrol = a plan over AreaOfInterest steps (move / sweep / hide_check). The house
## is forced at least once per random interval house_visit_interval. Hiding spots
## are opened with a probability that depends only on time since the last check.

signal state_changed(from: int, to: int, reason: String)

const S := KillerStates.State

var state: int = S.PREPARE
var state_time := 0.0
var memory: AIMemory
var params: GameParams
var motor: Node
var vision: VisionSensor
var rng := RandomNumberGenerator.new()
var transition_log: Array[String] = []
## Print every log line to the console (debug presets).
var verbose_log := false

var search_center := Vector2.ZERO
var search_radius_px := 0.0
var investigate_region: Variant = null
var investigate_point := Vector2.ZERO

## Plan over an area: {area: AreaOfInterest, steps: Array, index: int}
var plan := {}
var hunt_start := 0.0
var house_deadline := INF
var house_stats := {"visits": 0, "entries": 0, "rooms_swept": 0, "hiding_checks": 0, "hiding_skipped": 0, "hiding_found": 0}
var combat_stats := {"attacks_started": 0, "attacks_hit": 0, "attacks_whiffed": 0, "whiff_reasons": {}, "finishes": 0, "finish_interrupted": 0}

var _areas: Array = []
var _last_area_id: StringName = &""
var _inside_house := false
var _wait_left := 0.0
var _look_base := Vector2.DOWN
var _look_t := 0.0
var _search_info_time := 0.0
var _search_point := Vector2.ZERO
var _search_point_valid := false
var _search_bias := Vector2.ZERO
var _search_locker: Node = null
var _hiding_target: Node = null
var _hiding_opened := false
var _footsteps_check_time := -INF
var _attack_phase := &""
var _attack_left := 0.0
var _attack_last_reason := ""
var _attack_ready_time := 0.0
var _finish_left := 0.0
var _victim_done := false


func _ready() -> void:
	params = GameParams.current()
	memory = AIMemory.new(params)
	motor = get_parent()
	vision = motor.get_node(^"VisionSensor")
	motor.get_node(^"HearingSensor").heard.connect(_on_heard)
	motor.locker_checked.connect(_on_locker_checked)


## Called by GameSession when the killer has been spawned into the world.
func activate() -> void:
	if state != S.PREPARE:
		return
	_collect_areas()
	hunt_start = GameClock.now()
	for a in _areas:
		memory.area_last_visit[a.area_id] = hunt_start
	for l in get_tree().get_nodes_in_group(&"locker"):
		memory.hiding_last_check[l.get_instance_id()] = hunt_start
	_schedule_house(hunt_start)
	_change(S.PATROL, "spawned after preparation")


func _collect_areas() -> void:
	_areas = get_tree().get_nodes_in_group(&"area_of_interest")
	if not _areas.is_empty():
		return
	# Fallback (test arenas): every patrol marker is a one-point area.
	var markers := get_tree().get_nodes_in_group(&"patrol_point")
	markers.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for m in markers:
		var a := AreaOfInterest.new()
		a.area_id = StringName(m.name)
		var mk := Marker2D.new()
		mk.name = "a_sweep"
		a.add_child(mk)
		m.add_child(a)
		_areas.append(a)


func _house() -> AreaOfInterest:
	for a in _areas:
		if a.is_house:
			return a
	return null


func _schedule_house(from_time: float) -> void:
	if _house() == null:
		house_deadline = INF
		return
	house_deadline = from_time + rng.randf_range(params.house_visit_interval.x, params.house_visit_interval.y)


func state_name() -> String:
	return KillerStates.name_of(state)


## Debug label: motor actions are shown as their own pseudo-states.
func display_state() -> String:
	match motor.current_action():
		&"door":
			return "OPEN_DOOR"
		&"window":
			return "VAULT_WINDOW"
	return state_name()


func _log(line: String) -> void:
	transition_log.append("%6.1fs %s" % [GameClock.now(), line])
	if verbose_log:
		print("[killer] ", transition_log[-1])
	if transition_log.size() > 10:
		transition_log.pop_front()


func _change(to: int, reason: String) -> void:
	var from := state
	state = to
	state_time = 0.0
	_wait_left = 0.0
	_log("%s -> %s: %s" % [KillerStates.name_of(from), KillerStates.name_of(to), reason])
	state_changed.emit(from, to, reason)


func _on_heard(obs: Observation.HeardObservation) -> void:
	if state == S.PREPARE:
		return
	memory.ingest_heard(obs, GameClock.now())


func _on_locker_checked(locker: Node, found: bool) -> void:
	memory.hiding_last_check[locker.get_instance_id()] = GameClock.now()
	house_stats.hiding_checks += 1
	if found:
		house_stats.hiding_found += 1
		_search_info_time = GameClock.now()
	_log("opened hiding spot %s: %s" % [locker.name, "someone inside" if found else "empty"])


# --- Tick -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == S.PREPARE or _victim_done:
		return
	state_time += delta
	var now := GameClock.now()
	memory.ingest_vision(vision.scan_group(&"survivor_perceivable", delta), now)
	_track_house_entry()

	if state == S.ATTACK:
		_tick_attack(delta, now)
		return
	if state == S.FINISH:
		_tick_finish(delta)
		return

	# 1. A visible victim outranks every sound and plan.
	if memory.has_visual:
		memory.take_pending_sound()
		if state != S.CHASE:
			_change(S.CHASE, "victim visible")
		_tick_chase(now)
		return
	if state == S.CHASE:
		_change(S.GO_TO_LAST_SEEN, "LOS lost")

	# 2. Fresh blood actually seen.
	var ev := vision.scan_evidence(memory.last_seen_time, params.evidence_fresh_time, memory.seen_evidence)
	if ev != null:
		_begin_search(ev.observed_at, params.search_radius, "noticed blood trace", false)

	# 3. A fresh localizable sound outranks patrol / plans / last seen / search.
	if memory.has_pending_sound():
		var s := memory.take_pending_sound()
		if now - s.timestamp <= params.sound_fresh_window:
			_begin_investigate(s)

	# 4. Footsteps (approximate region, handled as a sound above) also keep a search alive.
	if state == S.LOCAL_SEARCH and memory.footsteps_fresh(now, params.footsteps_fresh_window) \
			and now - _footsteps_check_time >= params.sound_recheck_cooldown:
		_footsteps_check_time = now
		_search_info_time = now

	match state:
		S.PATROL:
			_select_area(now)
		S.TRAVEL_TO_POI:
			_tick_travel()
		S.SWEEP_INTERIOR:
			_tick_sweep(delta)
		S.CHECK_HIDING_SPOT:
			_tick_hiding_check()
		S.GO_TO_LAST_SEEN:
			_tick_last_seen()
		S.INVESTIGATE_SOUND:
			_tick_investigate(delta)
		S.LOCAL_SEARCH:
			_tick_search(delta, now)
		S.RETURN_TO_PATROL:
			_tick_return()


func _track_house_entry() -> void:
	var h := _house()
	if h == null:
		return
	var inside: bool = h.contains(motor.global_position)
	if inside and not _inside_house:
		house_stats.entries += 1
		_log("entered house")
	_inside_house = inside


# --- Patrol plans ---------------------------------------------------------------

func _select_area(now: float) -> void:
	if _areas.is_empty():
		return
	var chosen: AreaOfInterest = null
	var reason := ""
	var house := _house()
	if house != null and now >= house_deadline:
		chosen = house
		reason = "house visit due (%.0fs since last)" % (now - memory.area_last_visit.get(house.area_id, hunt_start))
	else:
		var best := -INF
		for a in _areas:
			if a.area_id == _last_area_id and _areas.size() > 1:
				continue
			var score: float = (now - memory.area_last_visit.get(a.area_id, hunt_start)) * a.weight + rng.randf() * params.poi_jitter
			if score > best:
				best = score
				chosen = a
		reason = "least recently visited (%s)" % chosen.area_id
	plan = {"area": chosen, "steps": chosen.get_steps(), "index": 0}
	_change(S.TRAVEL_TO_POI, reason)


func _current_step() -> Dictionary:
	if plan.is_empty() or plan.index >= plan.steps.size():
		return {}
	return plan.steps[plan.index]


func _advance_step() -> void:
	plan.index += 1
	if plan.index >= plan.steps.size():
		_complete_plan()


func _complete_plan() -> void:
	var a: AreaOfInterest = plan.area
	var now := GameClock.now()
	memory.area_last_visit[a.area_id] = now
	_last_area_id = a.area_id
	if a.is_house:
		house_stats.visits += 1
		_schedule_house(now)
	_log("finished area %s" % a.area_id)
	plan = {}
	_change(S.PATROL, "area done")


func _tick_travel() -> void:
	var step := _current_step()
	if step.is_empty():
		_change(S.PATROL, "no plan")
		return
	match step.kind:
		&"move":
			motor.move_to(step.pos)
			if motor.has_arrived():
				_advance_step()
			elif motor.stuck:
				_log("stuck: %s; skipping step %s" % [motor.stuck_reason, step.name])
				motor.stop()
				_advance_step()
		&"sweep":
			_start_wait(params.sweep_look_time)
			state = S.SWEEP_INTERIOR
			state_time = 0.0
		&"hide_check":
			_decide_hiding_checks()


func _tick_sweep(delta: float) -> void:
	_wait_left -= delta
	_sweep_look(delta)
	if _wait_left <= 0.0:
		var step := _current_step()
		if plan.area != null and plan.area.is_house:
			house_stats.rooms_swept += 1
		_log("swept %s" % step.get("name", "?"))
		state = S.TRAVEL_TO_POI
		state_time = 0.0
		_advance_step()


## Chance to open each hiding spot of the area. Depends only on elapsed time and
## on where the victim was last actually seen — never on occupancy.
func hiding_check_chance(locker: Node, now: float) -> float:
	var since: float = now - memory.hiding_last_check.get(locker.get_instance_id(), hunt_start)
	var p := clampf(params.hiding_check_base + since / params.hiding_check_ramp, params.hiding_check_base, params.hiding_check_max)
	if memory.has_last_seen and now - memory.last_seen_time < 30.0:
		for c in get_tree().get_nodes_in_group(&"cabin"):
			for room in c.get_room_rects():
				if room.has_point(memory.last_seen_position) and room.has_point(locker.global_position):
					p = maxf(p, params.hiding_check_after_sighting)
	return p


func _decide_hiding_checks() -> void:
	var now := GameClock.now()
	var spots: Array = plan.area.hiding_spots()
	for l in spots:
		var p := hiding_check_chance(l, now)
		if rng.randf() < p:
			_hiding_target = l
			_hiding_opened = false
			_change(S.CHECK_HIDING_SPOT, "check %s (p=%.2f)" % [l.name, p])
			return
		house_stats.hiding_skipped += 1
		_log("skipped hiding spot %s (p=%.2f)" % [l.name, p])
	_advance_step()


func _tick_hiding_check() -> void:
	if motor.is_busy():
		return
	if _hiding_target == null or not is_instance_valid(_hiding_target):
		_change(S.TRAVEL_TO_POI, "hiding spot gone")
		_advance_step()
		return
	if _hiding_opened:
		_hiding_target = null
		_hiding_opened = false
		state = S.TRAVEL_TO_POI
		state_time = 0.0
		_advance_step()
		return
	var sp: Vector2 = _hiding_target.get_search_position()
	motor.move_to(sp)
	if motor.global_position.distance_to(sp) <= GameParams.gu(0.35):
		motor.start_open_locker(_hiding_target)
		_hiding_opened = true
	elif motor.stuck or state_time > 15.0:
		_log("could not reach hiding spot (%s)" % (motor.stuck_reason if motor.stuck else "timeout"))
		_hiding_target = null
		state = S.TRAVEL_TO_POI
		_advance_step()


func _tick_return() -> void:
	if not plan.is_empty() and plan.index < plan.steps.size():
		_change(S.TRAVEL_TO_POI, "resume interrupted plan (%s)" % plan.area.area_id)
	else:
		plan = {}
		_change(S.PATROL, "pick next area")


# --- Pursuit and combat -------------------------------------------------------------

func _tick_chase(now: float) -> void:
	var target := memory.visible_position
	var dist: float = motor.global_position.distance_to(target)
	if motor.is_busy():
		return
	if memory.visible_downed:
		if dist <= GameParams.gu(params.finish_range):
			motor.stop()
			_finish_left = params.finish_time
			_change(S.FINISH, "victim downed and reachable")
			motor.visual.telegraph = true
		else:
			motor.move_to(target)
		return
	var locker := _locker_at(target, 0.4) if memory.visible_peeking else null
	if locker != null:
		# Victim seen peeking out of a locker: go and open it.
		motor.move_to(locker.get_search_position())
		if motor.global_position.distance_to(locker.get_search_position()) <= GameParams.gu(0.35):
			motor.start_open_locker(locker)
		return
	motor.move_to(target)
	if dist <= GameParams.gu(params.attack_start_range) and now >= _attack_ready_time:
		combat_stats.attacks_started += 1
		SoundEventBus.emit(&"swing", motor.global_position, 4.0, motor.get_instance_id())
		_attack_phase = &"windup"
		_attack_left = params.attack_windup
		_attack_last_reason = ""
		motor.visual.telegraph = true
		_change(S.ATTACK, "victim in attack range (%.2f gu)" % (dist / GameParams.PX_PER_GU))


func _tick_attack(delta: float, now: float) -> void:
	# Keep closing in during windup/active; small target motion does not cancel the attack.
	if memory.has_visual:
		motor.move_to(memory.visible_position)
		motor.look_towards(memory.visible_position - motor.global_position)
	_attack_left -= delta
	match _attack_phase:
		&"windup":
			if _attack_left <= 0.0:
				_attack_phase = &"active"
				_attack_left = params.attack_active
		&"active":
			var r: Dictionary = motor.try_hit()
			if r.hit:
				combat_stats.attacks_hit += 1
				_log("attack hit")
				_end_attack(now, "hit")
				return
			_attack_last_reason = r.reason
			if _attack_left <= 0.0:
				combat_stats.attacks_whiffed += 1
				var wr: Dictionary = combat_stats.whiff_reasons
				wr[_attack_last_reason] = wr.get(_attack_last_reason, 0) + 1
				_end_attack(now, "whiff: %s" % _attack_last_reason)


func _end_attack(now: float, reason: String) -> void:
	motor.visual.telegraph = false
	_attack_phase = &""
	_attack_ready_time = now + params.attack_recovery
	if memory.has_visual:
		_change(S.CHASE, "attack %s, recovery" % reason)
	else:
		_change(S.GO_TO_LAST_SEEN, "attack %s, LOS lost" % reason)


func _tick_finish(delta: float) -> void:
	motor.stop()
	var ok: bool = memory.has_visual and memory.visible_downed \
		and motor.global_position.distance_to(memory.visible_position) <= GameParams.gu(params.finish_range + 0.25)
	if not ok:
		combat_stats.finish_interrupted += 1
		motor.visual.telegraph = false
		_change(S.CHASE if memory.has_visual else S.GO_TO_LAST_SEEN, "finisher interrupted")
		return
	motor.look_towards(memory.visible_position - motor.global_position)
	_finish_left -= delta
	if _finish_left <= 0.0:
		motor.visual.telegraph = false
		if motor.perform_finish():
			combat_stats.finishes += 1
			_victim_done = true
			_log("finisher completed")
		else:
			_change(S.CHASE, "finisher failed")


func get_finish_progress() -> float:
	return 1.0 - _finish_left / params.finish_time if state == S.FINISH else -1.0


func _tick_last_seen() -> void:
	motor.move_to(memory.last_seen_position)
	if motor.has_arrived() or motor.stuck or state_time > params.last_seen_timeout:
		_search_bias = memory.last_seen_velocity
		_begin_search(memory.last_seen_position, params.search_radius, "reached last seen position", true)


func _tick_investigate(delta: float) -> void:
	if motor.is_busy():
		return
	if _wait_left > 0.0:
		var radio := _radio_to_silence()
		if radio != null:
			motor.start_use(radio, 0.5)
			_log("switching off the radio")
			return
		_wait_left -= delta
		_sweep_look(delta)
		if _wait_left <= 0.0:
			investigate_region = null
			_change(S.RETURN_TO_PATROL, "no evidence at sound area")
		return
	if state_time > params.investigate_timeout:
		investigate_region = null
		_change(S.RETURN_TO_PATROL, "investigate timeout")
		return
	motor.move_to(investigate_point)
	if motor.has_arrived() or motor.stuck:
		_start_wait(params.investigate_look_time)


func _tick_search(delta: float, now: float) -> void:
	if now - _search_info_time >= params.search_duration:
		_change(S.RETURN_TO_PATROL, "search: %.0fs without new info" % params.search_duration)
		return
	if motor.is_busy():
		return
	if _search_locker != null:
		var sp: Vector2 = _search_locker.get_search_position()
		motor.move_to(sp)
		if motor.global_position.distance_to(sp) <= GameParams.gu(0.35):
			motor.start_open_locker(_search_locker)
			_search_locker = null
		elif motor.stuck or motor.has_arrived(0.2):
			_search_locker = null
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		_sweep_look(delta)
		return
	if not _search_point_valid:
		_search_point = _pick_search_point()
		_search_point_valid = true
	motor.move_to(_search_point)
	if motor.has_arrived() or motor.stuck:
		_search_point_valid = false
		_start_wait(params.search_look_time)


# --- Helpers ----------------------------------------------------------------------

func _begin_investigate(s: Observation.HeardObservation) -> void:
	investigate_region = {"center": s.region_center(), "radius": s.region_radius()}
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, s.region_radius())
	investigate_point = _closest_nav_point(s.region_center() + off)
	_change(S.INVESTIGATE_SOUND, "heard %s" % s.kind)


func _begin_search(center: Vector2, radius_gu: float, reason: String, from_last_seen: bool) -> void:
	search_center = center
	search_radius_px = GameParams.gu(radius_gu)
	_search_info_time = GameClock.now()
	_search_point_valid = false
	if not from_last_seen:
		_search_bias = Vector2.ZERO
	_search_locker = null
	var best := INF
	for l in get_tree().get_nodes_in_group(&"locker"):
		var d: float = l.get_peek_origin().distance_to(center)
		if d > search_radius_px + GameParams.gu(1.0):
			continue
		var forced := from_last_seen and d <= GameParams.gu(0.6)
		if (forced or rng.randf() < params.locker_check_chance) and d < best:
			best = d
			_search_locker = l
	_change(S.LOCAL_SEARCH, reason)


func _pick_search_point() -> Vector2:
	var me: Vector2 = motor.global_position
	for attempt in 10:
		var off: Vector2
		if attempt == 0 and _search_bias.length() > 1.0:
			off = _search_bias.normalized() * search_radius_px * 0.8
			_search_bias = Vector2.ZERO
		else:
			off = Vector2.from_angle(rng.randf() * TAU) * search_radius_px * sqrt(rng.randf())
		var p := _closest_nav_point(search_center + off)
		if p.distance_to(search_center) <= search_radius_px * 1.4 and p.distance_to(me) > GameParams.gu(0.8):
			return p
	return _closest_nav_point(search_center)


func _closest_nav_point(p: Vector2) -> Vector2:
	var map: RID = motor.agent.get_navigation_map()
	if not map.is_valid():
		return p
	return NavigationServer2D.map_get_closest_point(map, p)


## A playing radio the killer can actually see within reach.
func _radio_to_silence() -> Node:
	for r in get_tree().get_nodes_in_group(&"radio"):
		if r.is_on and r.global_position.distance_to(motor.global_position) <= GameParams.gu(2.5) \
				and vision.can_see_point(r.global_position):
			return r
	return null


func _locker_at(p: Vector2, tol_gu: float) -> Node:
	for l in get_tree().get_nodes_in_group(&"locker"):
		if l.get_peek_origin().distance_to(p) <= GameParams.gu(tol_gu):
			return l
	return null


func _start_wait(t: float) -> void:
	_wait_left = t
	_look_base = motor.facing
	_look_t = 0.0
	motor.stop()


func _sweep_look(delta: float) -> void:
	_look_t += delta
	motor.look_towards(_look_base.rotated(sin(_look_t * 2.6) * 1.4))


func get_debug_info() -> Dictionary:
	var step := _current_step()
	return {
		"state": display_state(),
		"state_time": state_time,
		"has_visual": memory.has_visual,
		"has_last_seen": memory.has_last_seen,
		"last_seen": memory.last_seen_position,
		"last_seen_time": memory.last_seen_time,
		"investigate_region": investigate_region,
		"search_center": search_center if state == S.LOCAL_SEARCH else null,
		"search_radius": search_radius_px,
		"observations": memory.observations_count,
		"heard": memory.heard_count,
		"ignored_sounds": memory.ignored_sounds_count,
		"plan": "%s step %d/%d (%s)" % [plan.area.area_id, plan.index + 1, plan.steps.size(), step.get("name", "")] if not plan.is_empty() else "-",
		"plan_target": step.get("pos", null),
		"house_due_in": house_deadline - GameClock.now(),
		"house": house_stats,
		"combat": combat_stats,
		"log": transition_log,
	}
